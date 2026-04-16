#!/bin/bash
set -euo pipefail

# Nova Project Management — Update Board Field
# Generic field updater that handles all field types on the Nova Work Board.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Parse arguments ───────────────────────────────────────────────────────────

ITEM_ID=""
FIELD_NAME=""
VALUE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --item-id) ITEM_ID="$2"; shift 2 ;;
        --field-name) FIELD_NAME="$2"; shift 2 ;;
        --value) VALUE="$2"; shift 2 ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
done

if [ -z "$ITEM_ID" ] || [ -z "$FIELD_NAME" ] || [ -z "$VALUE" ]; then
    echo -e "${RED}Usage: update_field.sh --item-id ITEM_ID --field-name \"Status\" --value \"In progress\"${NC}"
    exit 1
fi

: "${NOVA_PROJECT_ID:?Set NOVA_PROJECT_ID or run preflight.sh first}"

# ── Resolve field ID and type ─────────────────────────────────────────────────

# Map field names to env var prefixes
case "$FIELD_NAME" in
    Status)
        FIELD_ID="${NOVA_STATUS_FIELD_ID:?}"
        FIELD_TYPE="single_select"
        ;;
    Priority)
        FIELD_ID="${NOVA_PRIORITY_FIELD_ID:?}"
        FIELD_TYPE="single_select"
        ;;
    Size)
        FIELD_ID="${NOVA_SIZE_FIELD_ID:?}"
        FIELD_TYPE="single_select"
        ;;
    Hours)
        FIELD_ID="${NOVA_HOURS_FIELD_ID:?}"
        FIELD_TYPE="number"
        ;;
    Iteration)
        FIELD_ID="${NOVA_ITERATION_FIELD_ID:?}"
        FIELD_TYPE="iteration"
        ;;
    "Start date")
        FIELD_ID="${NOVA_START_DATE_FIELD_ID:?}"
        FIELD_TYPE="date"
        ;;
    "Target date")
        FIELD_ID="${NOVA_TARGET_DATE_FIELD_ID:?}"
        FIELD_TYPE="date"
        ;;
    *)
        echo -e "${RED}Unknown field: ${FIELD_NAME}${NC}"
        echo "Supported fields: Status, Priority, Size, Hours, Iteration, Start date, Target date"
        exit 1
        ;;
esac

# ── Update based on field type ────────────────────────────────────────────────

case "$FIELD_TYPE" in
    single_select)
        # Look up the option ID from cached env vars
        # Normalize value for env var lookup: spaces→underscores, uppercase
        NORMALIZED=$(echo "$VALUE" | tr ' ' '_' | tr '[:lower:]' '[:upper:]')

        FIELD_UPPER=$(echo "$FIELD_NAME" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
        ENV_VAR="NOVA_${FIELD_UPPER}_${NORMALIZED}"
        OPTION_ID="${!ENV_VAR:-}"

        # If direct lookup fails, try common mappings
        if [ -z "$OPTION_ID" ]; then
            case "$FIELD_NAME:$VALUE" in
                "Status:Backlog") OPTION_ID="$NOVA_STATUS_BACKLOG" ;;
                "Status:In progress") OPTION_ID="$NOVA_STATUS_IN_PROGRESS" ;;
                "Status:In Review") OPTION_ID="$NOVA_STATUS_IN_REVIEW" ;;
                "Status:Done") OPTION_ID="$NOVA_STATUS_DONE" ;;
                "Priority:P0") OPTION_ID="$NOVA_PRIORITY_P0" ;;
                "Priority:P1") OPTION_ID="$NOVA_PRIORITY_P1" ;;
                "Priority:P2") OPTION_ID="$NOVA_PRIORITY_P2" ;;
                "Size:XS") OPTION_ID="$NOVA_SIZE_XS" ;;
                "Size:S") OPTION_ID="$NOVA_SIZE_S" ;;
                "Size:M") OPTION_ID="$NOVA_SIZE_M" ;;
                "Size:L") OPTION_ID="$NOVA_SIZE_L" ;;
                "Size:XL") OPTION_ID="$NOVA_SIZE_XL" ;;
                *)
                    echo -e "${RED}Could not resolve option ID for ${FIELD_NAME}=${VALUE}${NC}"
                    exit 1
                    ;;
            esac
        fi

        gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId, itemId: $itemId,
            fieldId: $fieldId, value: {singleSelectOptionId: $optionId}
          }) { projectV2Item { id } }
        }' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
           -f fieldId="$FIELD_ID" -f optionId="$OPTION_ID" >/dev/null 2>&1 && \
            echo -e "${GREEN}✓ ${FIELD_NAME} → ${VALUE}${NC}" || {
            echo -e "${RED}ERROR: Failed to update ${FIELD_NAME}.${NC}"
            exit 1
        }
        ;;

    number)
        # Number fields (like Hours) need Float, which -f can't pass.
        # Use --input with a temp JSON file.
        TMPFILE=$(mktemp)
        cat > "$TMPFILE" <<JSONEOF
{
  "query": "mutation(\$projectId: ID!, \$itemId: ID!, \$fieldId: ID!, \$val: Float!) { updateProjectV2ItemFieldValue(input: { projectId: \$projectId, itemId: \$itemId, fieldId: \$fieldId, value: {number: \$val} }) { projectV2Item { id } } }",
  "variables": {
    "projectId": "$NOVA_PROJECT_ID",
    "itemId": "$ITEM_ID",
    "fieldId": "$FIELD_ID",
    "val": $VALUE
  }
}
JSONEOF
        gh api graphql --input "$TMPFILE" >/dev/null 2>&1 && \
            echo -e "${GREEN}✓ ${FIELD_NAME} → ${VALUE}${NC}" || {
            echo -e "${RED}ERROR: Failed to update ${FIELD_NAME}.${NC}"
            rm -f "$TMPFILE"
            exit 1
        }
        rm -f "$TMPFILE"
        ;;

    date)
        # Date fields use ISO 8601 strings
        gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId, itemId: $itemId,
            fieldId: $fieldId, value: {date: $date}
          }) { projectV2Item { id } }
        }' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
           -f fieldId="$FIELD_ID" -f date="$VALUE" >/dev/null 2>&1 && \
            echo -e "${GREEN}✓ ${FIELD_NAME} → ${VALUE}${NC}" || {
            echo -e "${RED}ERROR: Failed to update ${FIELD_NAME}.${NC}"
            exit 1
        }
        ;;

    iteration)
        # Iteration uses iterationId. VALUE should be the iteration ID or "current".
        ITER_ID="$VALUE"
        if [ "$VALUE" = "current" ]; then
            ITER_ID="${NOVA_CURRENT_ITERATION_ID:?No current iteration cached}"
        fi

        gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId, itemId: $itemId,
            fieldId: $fieldId, value: {iterationId: $iterationId}
          }) { projectV2Item { id } }
        }' -f projectId="$NOVA_PROJECT_ID" -f itemId="$ITEM_ID" \
           -f fieldId="$FIELD_ID" -f iterationId="$ITER_ID" >/dev/null 2>&1 && \
            echo -e "${GREEN}✓ ${FIELD_NAME} → ${VALUE}${NC}" || {
            echo -e "${RED}ERROR: Failed to update ${FIELD_NAME}.${NC}"
            exit 1
        }
        ;;
esac
