#!/bin/bash
set -euo pipefail

# Nova CI/CD Guardrail Validator
# Detects fork-based vs simple deployment model and applies appropriate rules.
# Returns: ALLOW, WARN (with reason), or BLOCK (with reason + alternative)

ACTION=""
TARGET_BRANCH=""
SOURCE_BRANCH=""
SKIP_CI_CHECK=false

usage() {
    echo "Usage: $0 --action <push|pr|merge> --target-branch <branch> [--source-branch <branch>] [--skip-ci-check]"
    echo ""
    echo "Actions:"
    echo "  push    Validate a git push"
    echo "  pr      Validate PR creation"
    echo "  merge   Validate a merge"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --action) ACTION="$2"; shift 2 ;;
        --target-branch) TARGET_BRANCH="$2"; shift 2 ;;
        --source-branch) SOURCE_BRANCH="$2"; shift 2 ;;
        --skip-ci-check) SKIP_CI_CHECK=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

[[ -z "$ACTION" ]] && { echo "ERROR: --action is required"; usage; }
[[ -z "$TARGET_BRANCH" ]] && { echo "ERROR: --target-branch is required"; usage; }

# Detect remotes and deployment model
UPSTREAM_REMOTE=$(git remote -v 2>/dev/null | grep -i upstream | head -1 | awk '{print $1}' || echo "")
ORIGIN_REMOTE="origin"

# Fork-based model if upstream remote exists, simple model otherwise
if [ -n "$UPSTREAM_REMOTE" ]; then
    DEPLOY_MODEL="fork"
else
    DEPLOY_MODEL="simple"
fi

# Detect day of week (1=Monday, 7=Sunday)
DAY_OF_WEEK=$(date +%u)
DAY_NAME=$(date +%A)

result_block() {
    echo "BLOCK"
    echo "REASON: $1"
    echo "ALTERNATIVE: $2"
    exit 0
}

result_warn() {
    echo "WARN"
    echo "REASON: $1"
    echo "SUGGESTION: $2"
    exit 0
}

result_allow() {
    echo "ALLOW"
    [[ -n "${1:-}" ]] && echo "NOTE: $1"
    exit 0
}

check_ci_status() {
    local branch="$1"
    if [[ "$SKIP_CI_CHECK" == "true" ]]; then
        return 0
    fi

    if ! command -v gh &>/dev/null; then
        echo "WARN: gh CLI not found, cannot check CI status" >&2
        return 0
    fi

    local latest_run
    latest_run=$(gh run list --branch "$branch" --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "")

    if [[ "$latest_run" == "failure" ]]; then
        return 1
    fi
    return 0
}

is_upstream_target() {
    local remote_url
    remote_url=$(git remote get-url "$ORIGIN_REMOTE" 2>/dev/null || echo "")

    if [[ "$TARGET_BRANCH" == "main" ]]; then
        return 0
    fi
    return 1
}

# --- PUSH validation ---
if [[ "$ACTION" == "push" ]]; then
    case "$TARGET_BRANCH" in
        staging)
            if [[ "$DEPLOY_MODEL" == "fork" ]]; then
                result_block \
                    "Staging only accepts code through PRs from dev." \
                    "Create a PR from dev to staging: bash scripts/create_pr.sh --base staging --title 'Release: description'"
            else
                result_allow "No staging branch in simple model. Pushing to staging."
            fi
            ;;
        main)
            if [[ "$DEPLOY_MODEL" == "fork" ]]; then
                result_block \
                    "main is the upstream production branch. Direct pushes are never allowed." \
                    "For weekly release: code goes staging → upstream/main via Tuesday's automated PR. For hotfixes: branch off upstream/main and open a PR."
            else
                result_block \
                    "main is the production branch. Direct pushes are not allowed." \
                    "Create a PR from dev to main: gh pr create --base main --title 'description'"
            fi
            ;;
        dev)
            if ! check_ci_status "$TARGET_BRANCH" 2>/dev/null; then
                result_warn \
                    "CI appears to be failing. Your push will trigger a new run." \
                    "Check current failures: gh run list --branch dev --limit 5"
            fi
            result_allow
            ;;
        feature/*|feat/*|fix/*|bugfix/*|hotfix/*|chore/*|refactor/*)
            result_allow
            ;;
        *)
            result_allow "Pushing to branch '$TARGET_BRANCH'. Make sure this is intentional."
            ;;
    esac
fi

# --- PR validation ---
if [[ "$ACTION" == "pr" ]]; then
    case "$TARGET_BRANCH" in
        main)
            if [[ "$DEPLOY_MODEL" == "fork" ]]; then
                if [[ "$SOURCE_BRANCH" == hotfix/* ]]; then
                    if [[ -n "$UPSTREAM_REMOTE" ]]; then
                        result_warn \
                            "Hotfix PR to upstream/main. Ensure this branch is based on upstream/main, not dev." \
                            "Verify: git log --oneline upstream/main..HEAD should show only your hotfix commits."
                    else
                        result_block \
                            "No upstream remote configured." \
                            "Add upstream: git remote add upstream <upstream-repo-url>"
                    fi
                else
                    result_block \
                        "PRs to main go through the weekly release cycle from staging." \
                        "For weekly release: automated Tuesday PR from staging. For hotfix: branch off upstream/main first."
                fi
            else
                # Simple model: PR from dev to main is the correct flow
                if [[ "${SOURCE_BRANCH:-}" == "dev" ]] || [[ -z "${SOURCE_BRANCH:-}" ]]; then
                    result_allow "PR to main requires at least 1 review before merge."
                elif [[ "${SOURCE_BRANCH:-}" == feature/* ]] || [[ "${SOURCE_BRANCH:-}" == fix/* ]] || [[ "${SOURCE_BRANCH:-}" == feat/* ]]; then
                    result_warn \
                        "Feature branches should merge into dev first, then dev merges to main." \
                        "Create a PR to dev instead: gh pr create --base dev"
                else
                    result_allow "PR to main requires at least 1 review before merge."
                fi
            fi
            ;;
        staging)
            if [[ -n "$SOURCE_BRANCH" && "$SOURCE_BRANCH" != "dev" && "$SOURCE_BRANCH" != dev/* ]]; then
                result_warn \
                    "Staging PRs should come from dev. Source branch '$SOURCE_BRANCH' may not have all dev changes." \
                    "Merge your changes into dev first, then create PR from dev to staging."
            fi

            if [[ "$DAY_OF_WEEK" == "1" ]]; then
                result_warn \
                    "Monday is feature freeze. Only bug fixes should go to staging today." \
                    "If this is a bug fix, proceed. If it's a new feature, hold until Thursday."
            fi

            if ! check_ci_status "${SOURCE_BRANCH:-dev}" 2>/dev/null; then
                result_warn \
                    "CI is failing on ${SOURCE_BRANCH:-dev}. Fix failures before creating a staging PR." \
                    "Check failures: gh run list --branch ${SOURCE_BRANCH:-dev} --limit 5"
            fi

            result_allow "Staging PR requires at least 1 approval. CODEOWNERS will auto-assign reviewers."
            ;;
        dev)
            result_allow
            ;;
        *)
            result_allow
            ;;
    esac
fi

# --- MERGE validation ---
if [[ "$ACTION" == "merge" ]]; then
    case "$TARGET_BRANCH" in
        main)
            result_block \
                "Merging to main is handled by the upstream admin after reviewing the weekly release PR." \
                "Check release status: bash scripts/release_status.sh"
            ;;
        staging)
            if [[ "$DAY_OF_WEEK" == "1" ]]; then
                result_warn \
                    "Monday is feature freeze for staging." \
                    "Bug fixes are OK. New features should wait until Thursday."
            fi
            result_allow "Ensure the PR has at least 1 approval and CI is passing."
            ;;
        dev)
            result_allow
            ;;
        *)
            result_allow
            ;;
    esac
fi

# --- .gitignore check (for push/pr actions) ---
if [[ "$ACTION" == "push" ]] || [[ "$ACTION" == "pr" ]]; then
    DANGEROUS_FILES=$(git diff --cached --name-only 2>/dev/null | grep -E '(^\.env|node_modules/|\.pem$)' || true)
    if [ -n "$DANGEROUS_FILES" ]; then
        result_block \
            "Staged files contain secrets or artifacts that must not be committed: ${DANGEROUS_FILES}" \
            "Add these patterns to .gitignore and unstage: git rm --cached <file>"
    fi

    if [ ! -f ".gitignore" ] 2>/dev/null; then
        result_warn \
            "No .gitignore file found in this repo." \
            "Create one from the template in references/gitignore-practices.md"
    fi
fi

result_allow
