#!/bin/bash
set -euo pipefail

# Nova CI/CD — Guarded PR Creation
# Creates a PR after running guardrail validation.
# Refuses to proceed if validation returns BLOCK.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE=""
TITLE=""
BODY=""
ISSUE_NUMBER=""
DRAFT=false

usage() {
    echo "Usage: $0 --base <target-branch> --title <title> [--body <body>] [--issue-number <N>] [--draft]"
    echo ""
    echo "Options:"
    echo "  --base          Target branch (dev, staging)"
    echo "  --title         PR title (use conventional format: type: description)"
    echo "  --body          PR body/description (optional)"
    echo "  --issue-number  GitHub issue number to link (optional)"
    echo "  --draft         Create as draft PR (optional)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --base) BASE="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --issue-number) ISSUE_NUMBER="$2"; shift 2 ;;
        --draft) DRAFT=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

[[ -z "$BASE" ]] && { echo "ERROR: --base is required"; usage; }
[[ -z "$TITLE" ]] && { echo "ERROR: --title is required"; usage; }

CURRENT_BRANCH=$(git branch --show-current)

if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "ERROR: Not on any branch (detached HEAD). Checkout a branch first."
    exit 1
fi

echo "=== Nova CI/CD — PR Creation ==="
echo "Source: $CURRENT_BRANCH"
echo "Target: $BASE"
echo ""

# --- Run guardrail validation ---
echo "Running guardrail validation..."
VALIDATION=$("$SCRIPT_DIR/validate_action.sh" --action pr --target-branch "$BASE" --source-branch "$CURRENT_BRANCH" 2>&1 || true)
VERDICT=$(echo "$VALIDATION" | head -1)

case "$VERDICT" in
    BLOCK)
        echo ""
        echo "❌ BLOCKED"
        echo "$VALIDATION" | tail -n +2
        echo ""
        echo "PR creation aborted. Follow the alternative above."
        exit 1
        ;;
    WARN)
        echo ""
        echo "⚠️  WARNING"
        echo "$VALIDATION" | tail -n +2
        echo ""
        echo "Proceeding with PR creation. Address the warning if needed."
        echo ""
        ;;
    ALLOW)
        NOTES=$(echo "$VALIDATION" | grep "^NOTE:" || true)
        if [[ -n "$NOTES" ]]; then
            echo "✅ Validated. $NOTES"
        else
            echo "✅ Validated."
        fi
        echo ""
        ;;
esac

# --- Build PR body ---
PR_BODY="$BODY"

if [[ -n "$ISSUE_NUMBER" ]]; then
    CLOSE_LINE="Closes #${ISSUE_NUMBER}"
    if [[ -z "$PR_BODY" ]]; then
        PR_BODY="$CLOSE_LINE"
    else
        PR_BODY="${PR_BODY}

${CLOSE_LINE}"
    fi
fi

# --- Push current branch ---
echo "Pushing branch '$CURRENT_BRANCH' to origin..."
git push -u origin "$CURRENT_BRANCH" 2>&1

if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to push branch. Check your permissions and try again."
    exit 1
fi

echo ""

# --- Create PR ---
echo "Creating PR..."
GH_ARGS=(
    pr create
    --base "$BASE"
    --title "$TITLE"
    --head "$CURRENT_BRANCH"
)

if [[ -n "$PR_BODY" ]]; then
    GH_ARGS+=(--body "$PR_BODY")
else
    GH_ARGS+=(--body "")
fi

if [[ "$DRAFT" == "true" ]]; then
    GH_ARGS+=(--draft)
fi

PR_URL=$(gh "${GH_ARGS[@]}" 2>&1)

if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create PR."
    echo "$PR_URL"
    exit 1
fi

echo ""
echo "✅ PR created: $PR_URL"
echo ""

# --- Post-creation guidance ---
if [[ "$BASE" == "staging" ]]; then
    echo "📋 Staging PR checklist:"
    echo "   • This PR requires at least 1 approval"
    echo "   • CODEOWNERS will auto-assign reviewers"
    echo "   • CI must pass before merging"
    echo ""
fi

echo "💡 Before merging, consider running:"
echo "   • The 'review' skill on this diff for code quality"
echo "   • The 'security-review' skill if this touches auth, API keys, or user data"
echo ""
echo "Done."
