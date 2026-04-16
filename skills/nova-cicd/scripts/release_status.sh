#!/bin/bash
set -euo pipefail

# Nova CI/CD — Release Status
# Shows what's queued in staging that hasn't reached production (upstream/main).

echo "=== Nova CI/CD — Release Status ==="
echo ""

# --- Fetch latest from upstream ---
UPSTREAM_REMOTE=$(git remote -v 2>/dev/null | grep -i upstream | head -1 | awk '{print $1}' || echo "")

if [[ -z "$UPSTREAM_REMOTE" ]]; then
    echo "ERROR: No 'upstream' remote found."
    echo "Add it: git remote add upstream <upstream-repo-url>"
    exit 1
fi

echo "Fetching from upstream and origin..."
git fetch "$UPSTREAM_REMOTE" --quiet 2>/dev/null || { echo "ERROR: Failed to fetch upstream."; exit 1; }
git fetch origin --quiet 2>/dev/null || { echo "ERROR: Failed to fetch origin."; exit 1; }
echo ""

# --- Compare staging to upstream/main ---
COMMITS=$(git log "${UPSTREAM_REMOTE}/main..origin/staging" --oneline 2>/dev/null || echo "")

if [[ -z "$COMMITS" ]]; then
    echo "📭 Nothing new in staging since the last release."
    echo "   staging and upstream/main are in sync."
    echo ""
else
    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    echo "📦 $COMMIT_COUNT commit(s) queued for next release:"
    echo ""

    # Group by conventional commit type
    declare -A GROUPS
    UNGROUPED=""

    while IFS= read -r line; do
        sha=$(echo "$line" | awk '{print $1}')
        msg=$(echo "$line" | cut -d' ' -f2-)

        type=""
        if echo "$msg" | grep -qE '^feat[:(]'; then
            type="Features"
        elif echo "$msg" | grep -qE '^fix[:(]'; then
            type="Bug Fixes"
        elif echo "$msg" | grep -qE '^chore[:(]'; then
            type="Chores"
        elif echo "$msg" | grep -qE '^docs[:(]'; then
            type="Documentation"
        elif echo "$msg" | grep -qE '^refactor[:(]'; then
            type="Refactors"
        elif echo "$msg" | grep -qE '^test[:(]'; then
            type="Tests"
        else
            type="Other"
        fi

        if [[ -n "${GROUPS[$type]+x}" ]]; then
            GROUPS[$type]="${GROUPS[$type]}
  ${sha} ${msg}"
        else
            GROUPS[$type]="  ${sha} ${msg}"
        fi
    done <<< "$COMMITS"

    # Print grouped output in a sensible order
    for group in "Features" "Bug Fixes" "Refactors" "Chores" "Documentation" "Tests" "Other"; do
        if [[ -n "${GROUPS[$group]+x}" ]]; then
            echo "  ── $group ──"
            echo "${GROUPS[$group]}"
            echo ""
        fi
    done
fi

# --- Next release timing ---
DAY_OF_WEEK=$(date +%u)
DAY_NAME=$(date +%A)

echo "─── Schedule ───"
case $DAY_OF_WEEK in
    1)
        echo "📅 Today is Monday — feature freeze for staging."
        echo "   Next release PR: Tomorrow (Tuesday) at 9 AM WAT."
        ;;
    2)
        echo "📅 Today is Tuesday — release PR should be created/available."
        echo "   Check: gh pr list --repo <upstream-repo> --state open"
        ;;
    3)
        echo "📅 Today is Wednesday — release day."
        echo "   Upstream admin should review and merge the release PR."
        ;;
    4)
        echo "📅 Today is Thursday — normal development."
        echo "   Next release PR: Tuesday at 9 AM WAT."
        ;;
    5)
        echo "📅 Today is Friday — normal development."
        echo "   Next release PR: Tuesday at 9 AM WAT."
        ;;
    6|7)
        echo "📅 Weekend — next release PR: Tuesday at 9 AM WAT."
        ;;
esac
echo ""

# --- CI status on staging ---
if command -v gh &>/dev/null; then
    echo "─── CI Status (staging) ───"
    LATEST_RUN=$(gh run list --branch staging --limit 1 --json status,conclusion,name,updatedAt 2>/dev/null || echo "")
    if [[ -n "$LATEST_RUN" && "$LATEST_RUN" != "[]" ]]; then
        STATUS=$(echo "$LATEST_RUN" | gh api --input - --jq '.[0] | "\(.name): \(.conclusion // .status) (updated \(.updatedAt))"' 2>/dev/null || echo "Unable to parse")
        echo "   $STATUS"
    else
        echo "   No recent CI runs found."
    fi
    echo ""
fi

echo "Done."
