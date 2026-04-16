#!/bin/bash
set -euo pipefail

# Nova Project Management — Create Issue
# Three-step process: create issue → set type → add to board with fields.
# NEVER use gh issue create --project (it's fragile and often silently fails).

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Parse arguments ───────────────────────────────────────────────────────────

REPO=""
TITLE=""
BODY=""
ISSUE_TYPE="Task"
PRIORITY="P1"
SIZE="M"
ASSIGNEE="@me"
LABELS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --type) ISSUE_TYPE="$2"; shift 2 ;;
        --priority) PRIORITY="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        --assignee) ASSIGNEE="$2"; shift 2 ;;
        --labels) LABELS="$2"; shift 2 ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
done

if [ -z "$REPO" ] || [ -z "$TITLE" ]; then
    echo -e "${RED}Usage: create_issue.sh --repo OWNER/REPO --title \"Title\" [--body \"Body\"] [--type Feature] [--priority P1] [--size M] [--assignee @me]${NC}"
    exit 1
fi

# Use preflight env vars if available, otherwise need them set
: "${NOVA_PROJECT_ID:?Set NOVA_PROJECT_ID or run preflight.sh first}"
: "${NOVA_STATUS_FIELD_ID:?Set NOVA_STATUS_FIELD_ID or run preflight.sh first}"
: "${NOVA_STATUS_BACKLOG:?Set NOVA_STATUS_BACKLOG or run preflight.sh first}"

echo "=== Creating Issue ==="

# ── Step 1: Create the issue ─────────────────────────────────────────────────

echo "Step 1/3: Creating issue..."

CREATE_ARGS=(--repo "$REPO" --title "$TITLE" --assignee "$ASSIGNEE")
if [ -n "$BODY" ]; then
    CREATE_ARGS+=(--body "$BODY")
fi
if [ -n "$LABELS" ]; then
    CREATE_ARGS+=(--label "$LABELS")
fi

ISSUE_URL=$(gh issue create "${CREATE_ARGS[@]}" 2>/dev/null) || {
    echo -e "${RED}ERROR: Failed to create issue.${NC}"
    exit 1
}

ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
echo -e "${GREEN}✓ Created issue #${ISSUE_NUMBER}: ${ISSUE_URL}${NC}"

# ── Step 2: Set issue type via GraphQL ────────────────────────────────────────

echo "Step 2/3: Setting issue type to '${ISSUE_TYPE}'..."

# Get the issue's node ID
ISSUE_NODE_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" --jq '.node_id' 2>/dev/null) || {
    echo -e "${YELLOW}WARNING: Could not get issue node ID. Skipping type assignment.${NC}"
    ISSUE_NODE_ID=""
}

if [ -n "$ISSUE_NODE_ID" ]; then
    ORG_NAME=$(echo "$REPO" | cut -d'/' -f1)

    # Query available issue types for the org
    ISSUE_TYPES_DATA=$(gh api graphql -f query='
    query($org: String!) {
      organization(login: $org) {
        issueTypes(first: 20) {
          nodes {
            id
            name
          }
        }
      }
    }' -f org="$ORG_NAME" 2>/dev/null) || {
        echo -e "${YELLOW}WARNING: Could not query issue types. Skipping.${NC}"
        ISSUE_TYPES_DATA=""
    }

    if [ -n "$ISSUE_TYPES_DATA" ]; then
        TYPE_ID=$(echo "$ISSUE_TYPES_DATA" | jq -r ".data.organization.issueTypes.nodes[] | select(.name == \"$ISSUE_TYPE\") | .id")

        if [ -n "$TYPE_ID" ] && [ "$TYPE_ID" != "null" ]; then
            gh api graphql -f query='
            mutation($issueId: ID!, $issueTypeId: ID!) {
              updateIssueIssueType(input: {issueId: $issueId, issueTypeId: $issueTypeId}) {
                issue { id }
              }
            }' -f issueId="$ISSUE_NODE_ID" -f issueTypeId="$TYPE_ID" >/dev/null 2>&1 && \
                echo -e "${GREEN}✓ Issue type set to '${ISSUE_TYPE}'${NC}" || \
                echo -e "${YELLOW}WARNING: Failed to set issue type. Set it manually.${NC}"
        else
            echo -e "${YELLOW}WARNING: Issue type '${ISSUE_TYPE}' not found in org. Available types:${NC}"
            echo "$ISSUE_TYPES_DATA" | jq -r '.data.organization.issueTypes.nodes[].name' 2>/dev/null
        fi
    fi
fi

# ── Step 3: Add to board and set fields ───────────────────────────────────────

echo "Step 3/3: Adding to Nova Work Board and setting fields..."

ITEM_ID=$(gh project item-add "$NOVA_BOARD_NUMBER" \
    --owner "Nova-Digital-Solutions" \
    --url "$ISSUE_URL" \
    --format json 2>/dev/null | jq -r '.id') || {
    echo -e "${RED}ERROR: Failed to add issue to board.${NC}"
    exit 1
}

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
    echo -e "${RED}ERROR: Got empty item ID from board. Issue may not have been added.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Added to board (item: ${ITEM_ID})${NC}"

# Set Status → Backlog
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId,
    fieldId: $fieldId, value: {singleSelectOptionId: $optionId}
  }) { projectV2Item { id } }
}' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
   -f fieldId="$NOVA_STATUS_FIELD_ID" -f optionId="$NOVA_STATUS_BACKLOG" >/dev/null 2>&1 && \
    echo -e "${GREEN}✓ Status → Backlog${NC}" || \
    echo -e "${YELLOW}WARNING: Could not set Status.${NC}"

# Set Priority
PRIORITY_VAR="NOVA_PRIORITY_${PRIORITY}"
PRIORITY_OPTION_ID="${!PRIORITY_VAR:-}"
if [ -n "$PRIORITY_OPTION_ID" ] && [ -n "${NOVA_PRIORITY_FIELD_ID:-}" ]; then
    gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId, itemId: $itemId,
        fieldId: $fieldId, value: {singleSelectOptionId: $optionId}
      }) { projectV2Item { id } }
    }' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
       -f fieldId="$NOVA_PRIORITY_FIELD_ID" -f optionId="$PRIORITY_OPTION_ID" >/dev/null 2>&1 && \
        echo -e "${GREEN}✓ Priority → ${PRIORITY}${NC}" || \
        echo -e "${YELLOW}WARNING: Could not set Priority.${NC}"
fi

# Set Size
SIZE_VAR="NOVA_SIZE_${SIZE}"
SIZE_OPTION_ID="${!SIZE_VAR:-}"
if [ -n "$SIZE_OPTION_ID" ] && [ -n "${NOVA_SIZE_FIELD_ID:-}" ]; then
    gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId, itemId: $itemId,
        fieldId: $fieldId, value: {singleSelectOptionId: $optionId}
      }) { projectV2Item { id } }
    }' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
       -f fieldId="$NOVA_SIZE_FIELD_ID" -f optionId="$SIZE_OPTION_ID" >/dev/null 2>&1 && \
        echo -e "${GREEN}✓ Size → ${SIZE}${NC}" || \
        echo -e "${YELLOW}WARNING: Could not set Size.${NC}"
fi

echo ""
echo -e "${GREEN}=== Issue #${ISSUE_NUMBER} created and added to board ===${NC}"
echo "URL: ${ISSUE_URL}"
echo "Board Item ID: ${ITEM_ID}"

# Output for scripting
echo ""
echo "NOVA_ISSUE_NUMBER=${ISSUE_NUMBER}"
echo "NOVA_ISSUE_URL=${ISSUE_URL}"
echo "NOVA_ITEM_ID=${ITEM_ID}"
