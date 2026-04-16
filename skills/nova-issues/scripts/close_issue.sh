#!/bin/bash
set -euo pipefail

# Nova Project Management — Close Issue
# Closes an issue, records hours (mandatory for billing), sets Status → Done,
# and checks if the parent epic is complete.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Parse arguments ───────────────────────────────────────────────────────────

REPO=""
ISSUE_NUMBER=""
HOURS=""
REASON="completed"

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift 2 ;;
        --issue-number) ISSUE_NUMBER="$2"; shift 2 ;;
        --hours) HOURS="$2"; shift 2 ;;
        --reason) REASON="$2"; shift 2 ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
done

if [ -z "$REPO" ] || [ -z "$ISSUE_NUMBER" ] || [ -z "$HOURS" ]; then
    echo -e "${RED}Usage: close_issue.sh --repo OWNER/REPO --issue-number 42 --hours 3.5 [--reason completed|not-planned]${NC}"
    echo -e "${YELLOW}Hours are mandatory — this is how Nova bills clients.${NC}"
    exit 1
fi

: "${NOVA_PROJECT_ID:?Set NOVA_PROJECT_ID or run preflight.sh first}"
: "${NOVA_HOURS_FIELD_ID:?Set NOVA_HOURS_FIELD_ID or run preflight.sh first}"
: "${NOVA_STATUS_FIELD_ID:?Set NOVA_STATUS_FIELD_ID or run preflight.sh first}"
: "${NOVA_STATUS_DONE:?Set NOVA_STATUS_DONE or run preflight.sh first}"

echo "=== Closing Issue #${ISSUE_NUMBER} ==="

# ── Step 1: Close the issue ──────────────────────────────────────────────────

echo "Step 1/4: Closing issue..."

gh issue close "$ISSUE_NUMBER" --repo "$REPO" --reason "$REASON" 2>/dev/null && \
    echo -e "${GREEN}✓ Issue #${ISSUE_NUMBER} closed (reason: ${REASON})${NC}" || {
    echo -e "${YELLOW}WARNING: Issue may already be closed or close failed.${NC}"
}

# ── Step 2: Get the board item ID for this issue ──────────────────────────────

echo "Step 2/4: Finding board item..."

ISSUE_NODE_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" --jq '.node_id' 2>/dev/null) || {
    echo -e "${RED}ERROR: Could not get issue node ID.${NC}"
    exit 1
}

# Query the project to find the item ID for this issue
# Match by issue node ID (not just number) to avoid cross-repo collisions
ITEM_DATA=$(gh api graphql -f query='
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue {
              id
              number
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
}' -f projectId="$NOVA_PROJECT_ID" 2>/dev/null) || {
    echo -e "${RED}ERROR: Could not query project items.${NC}"
    exit 1
}

ITEM_ID=$(echo "$ITEM_DATA" | jq -r ".data.node.items.nodes[] | select(.content.id == \"$ISSUE_NODE_ID\") | .id" | head -1)

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
    echo -e "${YELLOW}WARNING: Issue #${ISSUE_NUMBER} not found on board. Skipping field updates.${NC}"
    exit 0
fi

echo -e "${GREEN}✓ Board item: ${ITEM_ID}${NC}"

# ── Step 3: Update Hours field ────────────────────────────────────────────────
# Hours is a Number (Float) field. gh api graphql -f passes strings, not numbers.
# We must use --input with a JSON file to pass the Float correctly.

echo "Step 3/4: Recording ${HOURS} hours..."

TMPFILE=$(mktemp)
cat > "$TMPFILE" <<JSONEOF
{
  "query": "mutation(\$projectId: ID!, \$itemId: ID!, \$fieldId: ID!, \$hours: Float!) { updateProjectV2ItemFieldValue(input: { projectId: \$projectId, itemId: \$itemId, fieldId: \$fieldId, value: {number: \$hours} }) { projectV2Item { id } } }",
  "variables": {
    "projectId": "$NOVA_PROJECT_ID",
    "itemId": "$ITEM_ID",
    "fieldId": "$NOVA_HOURS_FIELD_ID",
    "hours": $HOURS
  }
}
JSONEOF

gh api graphql --input "$TMPFILE" >/dev/null 2>&1 && \
    echo -e "${GREEN}✓ Hours → ${HOURS}${NC}" || \
    echo -e "${RED}ERROR: Failed to update Hours field.${NC}"

rm -f "$TMPFILE"

# Set Status → Done
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId,
    fieldId: $fieldId, value: {singleSelectOptionId: $optionId}
  }) { projectV2Item { id } }
}' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
   -f fieldId="$NOVA_STATUS_FIELD_ID" -f optionId="$NOVA_STATUS_DONE" >/dev/null 2>&1 && \
    echo -e "${GREEN}✓ Status → Done${NC}" || \
    echo -e "${YELLOW}WARNING: Could not set Status to Done.${NC}"

# ── Step 4: Check parent epic ─────────────────────────────────────────────────

echo "Step 4/4: Checking parent epic..."

PARENT_DATA=$(gh api graphql -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      parentIssue {
        id
        number
        title
        state
        subIssues(first: 50) {
          nodes {
            state
          }
        }
      }
    }
  }
}' -f issueId="$ISSUE_NODE_ID" 2>/dev/null) || {
    echo -e "${YELLOW}Could not check parent epic (sub-issues API may not be available).${NC}"
    echo -e "${GREEN}=== Issue #${ISSUE_NUMBER} closed with ${HOURS} hours ===${NC}"
    exit 0
}

PARENT_NUMBER=$(echo "$PARENT_DATA" | jq -r '.data.node.parentIssue.number // empty')

if [ -z "$PARENT_NUMBER" ]; then
    echo "No parent epic found."
else
    PARENT_TITLE=$(echo "$PARENT_DATA" | jq -r '.data.node.parentIssue.title')
    TOTAL_SUBS=$(echo "$PARENT_DATA" | jq '.data.node.parentIssue.subIssues.nodes | length')
    OPEN_SUBS=$(echo "$PARENT_DATA" | jq '[.data.node.parentIssue.subIssues.nodes[] | select(.state == "OPEN")] | length')

    if [ "$OPEN_SUBS" -eq 0 ]; then
        echo -e "${GREEN}✓ All sub-issues of epic #${PARENT_NUMBER} (${PARENT_TITLE}) are closed!${NC}"
        echo -e "${YELLOW}→ Epic #${PARENT_NUMBER} may be ready to close. Confirm with the developer.${NC}"
    else
        echo "Epic #${PARENT_NUMBER} (${PARENT_TITLE}): ${OPEN_SUBS}/${TOTAL_SUBS} sub-issues still open."
    fi
fi

echo ""
echo -e "${GREEN}=== Issue #${ISSUE_NUMBER} closed — ${HOURS} hours recorded ===${NC}"
