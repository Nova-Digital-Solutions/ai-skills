# Board Field Operations Reference

Complete reference for querying and updating fields on the Nova Work Board.

## Discovering the Project and Field IDs

Run this once per session (or use `scripts/preflight.sh`).

### Get the project ID

```bash
gh api graphql -f query='
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
}' -f org="Nova-Digital-Solutions"
```

### Get all field IDs and their options

```bash
gh api graphql -f query='
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
}' -f projectId="$PROJECT_ID"
```

## Getting the Item ID for an Issue

Every issue on the board has a unique "item ID" (different from the issue ID). You need this to update fields.

### Method 1: From `gh project item-add` output

When you add an issue to the board, capture the item ID:

```bash
ITEM_ID=$(gh project item-add 1 \
  --owner Nova-Digital-Solutions \
  --url "$ISSUE_URL" \
  --format json | jq -r '.id')
```

### Method 2: Query the board for an existing issue

```bash
gh api graphql -f query='
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue {
              number
              title
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
}' -f projectId="$PROJECT_ID"
```

Then filter by issue number in the response.

### Method 3: Paginated search for large boards

If the board has more than 100 items, use cursor-based pagination:

```bash
gh api graphql -f query='
query($projectId: ID!, $cursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          content {
            ... on Issue { number }
          }
        }
      }
    }
  }
}' -f projectId="$PROJECT_ID"
```

## Updating Fields by Type

### Single-Select Fields (Status, Priority, Size)

These fields have predefined options. You must pass the option's ID, not its name.

```bash
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { singleSelectOptionId: $optionId }
  }) {
    projectV2Item { id }
  }
}' \
  -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$STATUS_FIELD_ID" \
  -f optionId="$STATUS_IN_PROGRESS_OPTION_ID"
```

**Field values:**

| Field | Options |
|---|---|
| Status | Backlog, In progress, In Review, Done |
| Priority | P0, P1, P2 |
| Size | XS, S, M, L, XL |

### Number Fields (Hours)

**This is the tricky one.** The GraphQL mutation expects a `Float!` type for the `number` value. But `gh api graphql -f` always passes strings. If you write `-f hours=3.5`, GraphQL receives `"3.5"` (a string) and rejects it with a type error.

**The workaround: use `--input` with a JSON file.**

```bash
# Create a temp file with the full GraphQL request
cat > /tmp/hours_update.json <<'EOF'
{
  "query": "mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $hours: Float!) { updateProjectV2ItemFieldValue(input: { projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: {number: $hours} }) { projectV2Item { id } } }",
  "variables": {
    "projectId": "PVT_xxx",
    "itemId": "PVTI_xxx",
    "fieldId": "PVTF_xxx",
    "hours": 3.5
  }
}
EOF

gh api graphql --input /tmp/hours_update.json
rm /tmp/hours_update.json
```

**Why this matters:** Hours is how Nova bills clients. If this field doesn't get set because of a type error, revenue is lost. Always use the `--input` pattern for number fields.

### Date Fields (Start date, Target date)

Date fields accept ISO 8601 date strings (YYYY-MM-DD).

```bash
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { date: $date }
  }) {
    projectV2Item { id }
  }
}' \
  -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$START_DATE_FIELD_ID" \
  -f date="2025-01-15"
```

### Iteration Fields

Iteration fields require the iteration ID (not the name). Discover iterations from the field query above.

```bash
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { iterationId: $iterationId }
  }) {
    projectV2Item { id }
  }
}' \
  -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$ITERATION_FIELD_ID" \
  -f iterationId="$ITERATION_ID"
```

To find the current iteration, look at the `configuration.iterations` array from the field query and pick the one whose `startDate` falls within the current date range (startDate + duration days).

## Clearing a Field Value

To remove a value from a field:

```bash
gh api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!) {
  clearProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
  }) {
    projectV2Item { id }
  }
}' \
  -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$FIELD_ID"
```

## Reading Current Field Values

To see what fields are already set on an item:

```bash
gh api graphql -f query='
query($projectId: ID!, $itemId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 1) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { name } }
                name
              }
              ... on ProjectV2ItemFieldNumberValue {
                field { ... on ProjectV2Field { name } }
                number
              }
              ... on ProjectV2ItemFieldDateValue {
                field { ... on ProjectV2Field { name } }
                date
              }
              ... on ProjectV2ItemFieldIterationValue {
                field { ... on ProjectV2IterationField { name } }
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
}' -f projectId="$PROJECT_ID"
```
