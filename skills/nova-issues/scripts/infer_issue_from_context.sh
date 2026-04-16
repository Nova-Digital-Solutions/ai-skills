#!/bin/bash
set -euo pipefail

# Nova Project Management — Infer Issue from Context
# Reads git state (branch name, recent commits) to determine what issue
# the developer is working on. No arguments required.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO="${NOVA_REPO:-}"
if [ -z "$REPO" ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
        echo -e "${RED}ERROR: Not in a git repository.${NC}"
        exit 1
    }
    if [[ "$REMOTE_URL" == git@* ]]; then
        REPO=$(echo "$REMOTE_URL" | sed 's/.*://' | sed 's/\.git$//')
    else
        REPO=$(echo "$REMOTE_URL" | sed 's|https://github.com/||' | sed 's/\.git$//')
    fi
fi

echo "=== Inferring Issue from Context ==="

# ── 1. Get current branch ────────────────────────────────────────────────────

BRANCH=$(git branch --show-current 2>/dev/null) || {
    echo -e "${YELLOW}WARNING: Could not determine current branch (detached HEAD?).${NC}"
    BRANCH=""
}

echo "Branch: ${BRANCH:-detached}"

# ── 2. Parse branch name for issue number ─────────────────────────────────────
# Common patterns: 42-feature-name, feature/42-name, issue-42, fix-42-bug

BRANCH_ISSUE=""
if [ -n "$BRANCH" ]; then
    # Try to extract issue number from branch name
    # Pattern: leading number (42-feature), number after slash (feature/42), issue-N, fix-N
    BRANCH_ISSUE=$(echo "$BRANCH" | grep -oE '(^|[/-])([0-9]+)' | grep -oE '[0-9]+' | head -1 || true)
fi

# ── 3. Parse recent commits for issue references ─────────────────────────────

COMMIT_ISSUES=$(git log --oneline -10 2>/dev/null | grep -oE '#[0-9]+' | tr -d '#' | sort -u || true)

echo "Branch issue: ${BRANCH_ISSUE:-none}"
echo "Commit issues: ${COMMIT_ISSUES:-none}"

# ── 4. Determine the most likely issue ────────────────────────────────────────

FOUND_ISSUE=""

# Priority: branch number > most recent commit reference
if [ -n "$BRANCH_ISSUE" ]; then
    FOUND_ISSUE="$BRANCH_ISSUE"
elif [ -n "$COMMIT_ISSUES" ]; then
    # Take the most frequently referenced issue, or the most recent one
    FOUND_ISSUE=$(echo "$COMMIT_ISSUES" | head -1)
fi

# ── 5. Verify the issue exists ────────────────────────────────────────────────

if [ -n "$FOUND_ISSUE" ]; then
    ISSUE_DATA=$(gh issue view "$FOUND_ISSUE" --repo "$REPO" --json number,title,state,labels 2>/dev/null) || {
        echo -e "${YELLOW}WARNING: Issue #${FOUND_ISSUE} not found in ${REPO}. It may be in a different repo.${NC}"
        FOUND_ISSUE=""
    }

    if [ -n "$FOUND_ISSUE" ] && [ -n "${ISSUE_DATA:-}" ]; then
        ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
        ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
        echo ""
        echo -e "${GREEN}=== Found Issue ===${NC}"
        echo "NOVA_INFERRED_ISSUE=${FOUND_ISSUE}"
        echo "NOVA_INFERRED_TITLE=${ISSUE_TITLE}"
        echo "NOVA_INFERRED_STATE=${ISSUE_STATE}"
        exit 0
    fi
fi

# ── 6. No issue found — search by keywords ───────────────────────────────────

echo ""
echo "No issue number found. Searching by keywords..."

# Build search keywords from branch name and recent commit subjects
KEYWORDS=""
if [ -n "$BRANCH" ]; then
    # Convert branch name to search keywords (strip prefixes, split on separators)
    KEYWORDS=$(echo "$BRANCH" | sed 's|.*/||' | tr '-' ' ' | tr '_' ' ' | sed 's/[0-9]//g' | xargs)
fi

if [ -z "$KEYWORDS" ]; then
    # Fall back to recent commit subjects
    KEYWORDS=$(git log --format='%s' -3 2>/dev/null | head -1 | sed 's/^[a-z]*: //' | sed 's/ (#[0-9]*)$//')
fi

if [ -n "$KEYWORDS" ]; then
    echo "Search keywords: ${KEYWORDS}"

    SEARCH_RESULTS=$(gh issue list --repo "$REPO" --state open --search "$KEYWORDS" --limit 5 --json number,title 2>/dev/null) || {
        echo -e "${YELLOW}WARNING: Issue search failed.${NC}"
        SEARCH_RESULTS="[]"
    }

    RESULT_COUNT=$(echo "$SEARCH_RESULTS" | jq 'length')

    if [ "$RESULT_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}=== Possible Matches ===${NC}"
        echo "$SEARCH_RESULTS" | jq -r '.[] | "#\(.number) — \(.title)"'
        echo ""
        echo "NOVA_INFERRED_ISSUE="
        echo "NOVA_SEARCH_MATCHES=$(echo "$SEARCH_RESULTS" | jq -c '.')"
        exit 0
    fi
fi

# ── 7. No match — suggest creating a new issue ───────────────────────────────

echo ""
echo -e "${YELLOW}=== No Matching Issue Found ===${NC}"

# Build a suggested title from branch/commits
SUGGESTED_TITLE=""
if [ -n "$BRANCH" ]; then
    SUGGESTED_TITLE=$(echo "$BRANCH" | sed 's|.*/||' | tr '-' ' ' | tr '_' ' ' | sed 's/[0-9]//g' | xargs)
    # Capitalize first letter
    SUGGESTED_TITLE="$(echo "${SUGGESTED_TITLE:0:1}" | tr '[:lower:]' '[:upper:]')${SUGGESTED_TITLE:1}"
fi

SUGGESTED_BODY=""
RECENT_COMMITS=$(git log --format='- %s' -5 2>/dev/null)
if [ -n "$RECENT_COMMITS" ]; then
    SUGGESTED_BODY="Recent work:\n${RECENT_COMMITS}"
fi

echo "NOVA_INFERRED_ISSUE="
echo "NOVA_SUGGESTED_TITLE=${SUGGESTED_TITLE:-Untitled task}"
echo "NOVA_SUGGESTED_BODY=${SUGGESTED_BODY:-No context available}"
echo ""
echo "Suggest creating a new issue with the above title/body."
