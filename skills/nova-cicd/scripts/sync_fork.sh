#!/bin/bash
set -euo pipefail

# Nova CI/CD — Manual Fork Sync
# Pulls upstream/main → staging → dev, aborting on conflicts.

echo "=== Nova CI/CD — Fork Sync ==="
echo ""

UPSTREAM_REMOTE=$(git remote -v 2>/dev/null | grep -i upstream | head -1 | awk '{print $1}' || echo "")

if [[ -z "$UPSTREAM_REMOTE" ]]; then
    echo "ERROR: No 'upstream' remote found."
    echo "Add it: git remote add upstream <upstream-repo-url>"
    exit 1
fi

ORIGINAL_BRANCH=$(git branch --show-current)
SYNC_OK=true

cleanup() {
    echo ""
    echo "Returning to original branch: $ORIGINAL_BRANCH"
    git checkout "$ORIGINAL_BRANCH" --quiet 2>/dev/null || true
}
trap cleanup EXIT

# --- Stash uncommitted changes ---
STASHED=false
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    echo "Stashing uncommitted changes..."
    git stash push -m "nova-cicd-sync-$(date +%s)" --quiet
    STASHED=true
fi

# --- Fetch upstream ---
echo "Fetching from upstream..."
git fetch "$UPSTREAM_REMOTE" --quiet 2>/dev/null || { echo "ERROR: Failed to fetch upstream."; exit 1; }
echo "✅ Fetched upstream"
echo ""

# --- Sync staging ← upstream/main ---
echo "Syncing staging ← upstream/main..."
git checkout staging --quiet 2>/dev/null || { echo "ERROR: Cannot checkout staging."; exit 1; }
git pull origin staging --quiet 2>/dev/null || true

MERGE_OUTPUT=$(git merge "${UPSTREAM_REMOTE}/main" --no-edit 2>&1) || {
    echo "❌ CONFLICT merging upstream/main into staging"
    echo ""
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U 2>/dev/null || true
    echo ""
    echo "Aborting merge. Resolve conflicts manually:"
    echo "  1. git checkout staging"
    echo "  2. git merge upstream/main"
    echo "  3. Resolve conflicts in each file"
    echo "  4. git add . && git commit"
    echo "  5. git push origin staging"
    echo "  6. Then re-run this script to continue syncing dev"
    git merge --abort 2>/dev/null || true
    SYNC_OK=false
}

if [[ "$SYNC_OK" == "true" ]]; then
    echo "Pushing staging to origin..."
    git push origin staging --quiet 2>/dev/null || { echo "ERROR: Failed to push staging."; exit 1; }
    echo "✅ staging synced with upstream/main"
    echo ""
fi

# --- Sync dev ← staging ---
if [[ "$SYNC_OK" == "true" ]]; then
    echo "Syncing dev ← staging..."
    git checkout dev --quiet 2>/dev/null || { echo "ERROR: Cannot checkout dev."; exit 1; }
    git pull origin dev --quiet 2>/dev/null || true

    MERGE_OUTPUT=$(git merge staging --no-edit 2>&1) || {
        echo "❌ CONFLICT merging staging into dev"
        echo ""
        echo "Conflicting files:"
        git diff --name-only --diff-filter=U 2>/dev/null || true
        echo ""
        echo "Aborting merge. Resolve conflicts manually:"
        echo "  1. git checkout dev"
        echo "  2. git merge staging"
        echo "  3. Resolve conflicts"
        echo "  4. git add . && git commit"
        echo "  5. git push origin dev"
        git merge --abort 2>/dev/null || true
        SYNC_OK=false
    }

    if [[ "$SYNC_OK" == "true" ]]; then
        echo "Pushing dev to origin..."
        git push origin dev --quiet 2>/dev/null || { echo "ERROR: Failed to push dev."; exit 1; }
        echo "✅ dev synced with staging"
        echo ""
    fi
fi

# --- Restore stashed changes ---
if [[ "$STASHED" == "true" ]]; then
    echo "Restoring stashed changes..."
    git stash pop --quiet 2>/dev/null || echo "⚠️  Could not auto-restore stash. Run 'git stash pop' manually."
fi

# --- Summary ---
echo ""
echo "─── Sync Summary ───"
if [[ "$SYNC_OK" == "true" ]]; then
    echo "✅ Full sync complete: upstream/main → staging → dev"
else
    echo "⚠️  Sync completed with conflicts. See messages above."
    echo "   Resolve conflicts promptly — delayed resolution causes painful release PR conflicts."
fi
echo ""
echo "Done."
