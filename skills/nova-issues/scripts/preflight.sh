#!/bin/bash
set -euo pipefail

# Nova Project Management — Preflight Check
# Verifies auth, discovers repo, caches project and field IDs for the session.
# Output: environment variable exports to source or parse.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ORG="Nova-Digital-Solutions"
BOARD_NAME="Nova Work Board"
BOARD_NUMBER=1

echo "=== Nova Project Management — Preflight ==="
echo ""

# ── 1. Check gh auth ──────────────────────────────────────────────────────────

echo "Checking GitHub CLI authentication..."
AUTH_STATUS=$(gh auth status 2>&1) || {
    echo -e "${RED}ERROR: gh auth failed. Run 'gh auth login' first.${NC}"
    exit 1
}

# Check required scopes
REQUIRED_SCOPES=("repo" "project" "read:org")
MISSING_SCOPES=()

for scope in "${REQUIRED_SCOPES[@]}"; do
    if ! echo "$AUTH_STATUS" | grep -qi "$scope"; then
        MISSING_SCOPES+=("$scope")
    fi
done

if [ ${#MISSING_SCOPES[@]} -gt 0 ]; then
    echo -e "${YELLOW}WARNING: Missing scopes: ${MISSING_SCOPES[*]}${NC}"
    if [[ " ${MISSING_SCOPES[*]} " == *" project "* ]]; then
        echo -e "${YELLOW}Run: gh auth refresh -s project -h github.com${NC}"
    fi
    if [[ " ${MISSING_SCOPES[*]} " == *" read:org "* ]]; then
        echo -e "${YELLOW}Run: gh auth refresh -s read:org -h github.com${NC}"
    fi
    echo -e "${RED}Fix missing scopes before proceeding.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Authentication OK — all required scopes present${NC}"

# ── 2. Determine repo ────────────────────────────────────────────────────────

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
    echo -e "${RED}ERROR: Not in a git repository or no 'origin' remote.${NC}"
    exit 1
}

# Parse OWNER/REPO from SSH or HTTPS URL
if [[ "$REMOTE_URL" == git@* ]]; then
    REPO_FULL=$(echo "$REMOTE_URL" | sed 's/.*://' | sed 's/\.git$//')
elif [[ "$REMOTE_URL" == https://* ]]; then
    REPO_FULL=$(echo "$REMOTE_URL" | sed 's|https://github.com/||' | sed 's/\.git$//')
else
    echo -e "${RED}ERROR: Unrecognized remote URL format: $REMOTE_URL${NC}"
    exit 1
fi

REPO_OWNER=$(echo "$REPO_FULL" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_FULL" | cut -d'/' -f2)

echo -e "${GREEN}✓ Repository: ${REPO_OWNER}/${REPO_NAME}${NC}"

# ── 3. Query project ID ──────────────────────────────────────────────────────

echo "Querying Nova Work Board project ID..."

PROJECT_DATA=$(gh api graphql -f query='
query($org: String!) {
  organization(login: $org) {
    projectsV2(first: 10) {
      nodes {
        id
        title
        number
      }
    }
  }
}' -f org="$ORG" 2>/dev/null) || {
    echo -e "${RED}ERROR: Failed to query projects. Check org access and project scope.${NC}"
    exit 1
}

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r ".data.organization.projectsV2.nodes[] | select(.title == \"$BOARD_NAME\") | .id")

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo -e "${RED}ERROR: Could not find project '$BOARD_NAME' in org '$ORG'.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Project ID: ${PROJECT_ID}${NC}"

# ── 4. Query field IDs and option IDs ─────────────────────────────────────────

echo "Querying board fields and options..."

FIELDS_DATA=$(gh api graphql -f query='
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      fields(first: 30) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
          ... on ProjectV2IterationField {
            id
            name
            dataType
            configuration {
              iterations {
                id
                title
                startDate
                duration
              }
            }
          }
        }
      }
    }
  }
}' -f projectId="$PROJECT_ID" 2>/dev/null) || {
    echo -e "${RED}ERROR: Failed to query project fields.${NC}"
    exit 1
}

# Extract field IDs
extract_field_id() {
    echo "$FIELDS_DATA" | jq -r ".data.node.fields.nodes[] | select(.name == \"$1\") | .id"
}

extract_option_id() {
    echo "$FIELDS_DATA" | jq -r ".data.node.fields.nodes[] | select(.name == \"$1\") | .options[]? | select(.name == \"$2\") | .id"
}

STATUS_FIELD_ID=$(extract_field_id "Status")
PRIORITY_FIELD_ID=$(extract_field_id "Priority")
SIZE_FIELD_ID=$(extract_field_id "Size")
HOURS_FIELD_ID=$(extract_field_id "Hours")
ITERATION_FIELD_ID=$(extract_field_id "Iteration")
START_DATE_FIELD_ID=$(extract_field_id "Start date")
TARGET_DATE_FIELD_ID=$(extract_field_id "Target date")

# Status options
STATUS_BACKLOG=$(extract_option_id "Status" "Backlog")
STATUS_IN_PROGRESS=$(extract_option_id "Status" "In progress")
STATUS_IN_REVIEW=$(extract_option_id "Status" "In Review")
STATUS_DONE=$(extract_option_id "Status" "Done")

# Priority options
PRIORITY_P0=$(extract_option_id "Priority" "P0")
PRIORITY_P1=$(extract_option_id "Priority" "P1")
PRIORITY_P2=$(extract_option_id "Priority" "P2")

# Size options
SIZE_XS=$(extract_option_id "Size" "XS")
SIZE_S=$(extract_option_id "Size" "S")
SIZE_M=$(extract_option_id "Size" "M")
SIZE_L=$(extract_option_id "Size" "L")
SIZE_XL=$(extract_option_id "Size" "XL")

# Current iteration (most recent active one)
CURRENT_ITERATION_ID=$(echo "$FIELDS_DATA" | jq -r '
  .data.node.fields.nodes[]
  | select(.name == "Iteration")
  | .configuration.iterations
  | sort_by(.startDate)
  | last
  | .id // empty
')

echo -e "${GREEN}✓ All field IDs discovered${NC}"

# ── 5. Output ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Nova Preflight Results ==="
cat <<EOF
export NOVA_ORG="$ORG"
export NOVA_REPO_OWNER="$REPO_OWNER"
export NOVA_REPO_NAME="$REPO_NAME"
export NOVA_REPO="$REPO_OWNER/$REPO_NAME"
export NOVA_PROJECT_ID="$PROJECT_ID"
export NOVA_BOARD_NUMBER="$BOARD_NUMBER"
export NOVA_STATUS_FIELD_ID="$STATUS_FIELD_ID"
export NOVA_PRIORITY_FIELD_ID="$PRIORITY_FIELD_ID"
export NOVA_SIZE_FIELD_ID="$SIZE_FIELD_ID"
export NOVA_HOURS_FIELD_ID="$HOURS_FIELD_ID"
export NOVA_ITERATION_FIELD_ID="$ITERATION_FIELD_ID"
export NOVA_START_DATE_FIELD_ID="$START_DATE_FIELD_ID"
export NOVA_TARGET_DATE_FIELD_ID="$TARGET_DATE_FIELD_ID"
export NOVA_STATUS_BACKLOG="$STATUS_BACKLOG"
export NOVA_STATUS_IN_PROGRESS="$STATUS_IN_PROGRESS"
export NOVA_STATUS_IN_REVIEW="$STATUS_IN_REVIEW"
export NOVA_STATUS_DONE="$STATUS_DONE"
export NOVA_PRIORITY_P0="$PRIORITY_P0"
export NOVA_PRIORITY_P1="$PRIORITY_P1"
export NOVA_PRIORITY_P2="$PRIORITY_P2"
export NOVA_SIZE_XS="$SIZE_XS"
export NOVA_SIZE_S="$SIZE_S"
export NOVA_SIZE_M="$SIZE_M"
export NOVA_SIZE_L="$SIZE_L"
export NOVA_SIZE_XL="$SIZE_XL"
export NOVA_CURRENT_ITERATION_ID="$CURRENT_ITERATION_ID"
EOF

echo ""
echo -e "${GREEN}=== Preflight complete. Source the exports above to use in other scripts. ===${NC}"
