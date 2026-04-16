# Epics and Sub-Issues Reference

Epics are how Nova organizes larger efforts. An epic is just an issue with issue type "Epic" that has sub-issues attached. Every non-epic issue in a larger effort must be a sub-issue.

## Creating an Epic

An epic is created like any other issue, but with type "Epic":

```bash
bash <skill_path>/scripts/create_issue.sh \
  --repo Nova-Digital-Solutions/project-name \
  --title "User Authentication System" \
  --body "Implement complete auth flow including login, registration, and password reset." \
  --type Epic \
  --priority P1 \
  --size XL
```

Epics typically stay in "In progress" status until all sub-issues are done.

## Adding Sub-Issues

Sub-issues use the GitHub sub-issues API (GraphQL). First, get both the parent (epic) and child issue node IDs:

```bash
# Get issue node IDs
EPIC_NODE_ID=$(gh api repos/OWNER/REPO/issues/EPIC_NUMBER --jq '.node_id')
CHILD_NODE_ID=$(gh api repos/OWNER/REPO/issues/CHILD_NUMBER --jq '.node_id')
```

Then add the sub-issue:

```bash
gh api graphql -f query='
mutation($parentId: ID!, $childId: ID!) {
  addSubIssue(input: {
    issueId: $parentId
    subIssueId: $childId
  }) {
    issue {
      id
      subIssues(first: 10) {
        nodes {
          number
          title
          state
        }
      }
    }
  }
}' -f parentId="$EPIC_NODE_ID" -f childId="$CHILD_NODE_ID"
```

## Removing a Sub-Issue

```bash
gh api graphql -f query='
mutation($parentId: ID!, $childId: ID!) {
  removeSubIssue(input: {
    issueId: $parentId
    subIssueId: $childId
  }) {
    issue { id }
  }
}' -f parentId="$EPIC_NODE_ID" -f childId="$CHILD_NODE_ID"
```

## Listing Sub-Issues of an Epic

```bash
gh api graphql -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      title
      state
      subIssues(first: 50) {
        nodes {
          number
          title
          state
          assignees(first: 5) {
            nodes { login }
          }
        }
      }
    }
  }
}' -f issueId="$EPIC_NODE_ID"
```

## Checking if an Epic is Complete

After closing a sub-issue, check if all siblings are done:

```bash
RESULT=$(gh api graphql -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      title
      subIssues(first: 50) {
        nodes {
          state
        }
      }
    }
  }
}' -f issueId="$EPIC_NODE_ID")

TOTAL=$(echo "$RESULT" | jq '.data.node.subIssues.nodes | length')
OPEN=$(echo "$RESULT" | jq '[.data.node.subIssues.nodes[] | select(.state == "OPEN")] | length')

if [ "$OPEN" -eq 0 ]; then
  echo "All $TOTAL sub-issues are closed. Epic is ready to close."
else
  echo "$OPEN of $TOTAL sub-issues still open."
fi
```

## Finding the Parent Epic of an Issue

```bash
gh api graphql -f query='
query($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      parentIssue {
        number
        title
        state
      }
    }
  }
}' -f issueId="$CHILD_NODE_ID"
```

## Epic Management Rules

1. **Every issue in a larger effort must be a sub-issue.** Don't leave orphan issues floating around when there's an epic they belong to.

2. **Set type to Epic.** This is done via the `updateIssueIssueType` mutation:

    ```bash
    # Get the Epic type ID
    EPIC_TYPE_ID=$(gh api graphql -f query='
    query($org: String!) {
      organization(login: $org) {
        issueTypes(first: 20) {
          nodes { id name }
        }
      }
    }' -f org="Nova-Digital-Solutions" | jq -r '.data.organization.issueTypes.nodes[] | select(.name == "Epic") | .id')

    # Set the issue type
    gh api graphql -f query='
    mutation($issueId: ID!, $typeId: ID!) {
      updateIssueIssueType(input: {
        issueId: $issueId
        issueTypeId: $typeId
      }) {
        issue { id }
      }
    }' -f issueId="$EPIC_NODE_ID" -f typeId="$EPIC_TYPE_ID"
    ```

3. **Don't close epics automatically.** When all sub-issues close, *prompt* the developer — they may want to add more sub-issues or verify the epic is truly complete.

4. **Epic hours = sum of sub-issue hours.** Don't set hours on the epic itself. The total is calculated from sub-issues.

5. **Epic status follows its children:**
   - All sub-issues in Backlog → Epic stays in Backlog
   - Any sub-issue In Progress → Epic is In Progress
   - All sub-issues Done → Prompt to close epic

## Creating a Sub-Issue Directly

When you need to break down work during implementation, create the sub-issue and link it in one flow:

```bash
# 1. Create the sub-issue
SUB_URL=$(gh issue create \
  --repo Nova-Digital-Solutions/project-name \
  --title "Implement password reset email" \
  --body "Send password reset link via email with 1-hour expiry." \
  --assignee @me)

SUB_NUMBER=$(echo "$SUB_URL" | grep -oE '[0-9]+$')
SUB_NODE_ID=$(gh api repos/OWNER/REPO/issues/$SUB_NUMBER --jq '.node_id')

# 2. Set its type to Task
# (use the type-setting pattern from create_issue.sh)

# 3. Add to board
ITEM_ID=$(gh project item-add 1 \
  --owner Nova-Digital-Solutions \
  --url "$SUB_URL" \
  --format json | jq -r '.id')

# 4. Link as sub-issue of the epic
gh api graphql -f query='
mutation($parentId: ID!, $childId: ID!) {
  addSubIssue(input: { issueId: $parentId, subIssueId: $childId }) {
    issue { id }
  }
}' -f parentId="$EPIC_NODE_ID" -f childId="$SUB_NODE_ID"
```
