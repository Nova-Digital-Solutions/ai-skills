# Troubleshooting

Common issues when working with GitHub Issues, Projects, and the GraphQL API.

## "The repository has disabled issues"

The repo's issue tracker is turned off:

```bash
gh api repos/OWNER/REPO --method PATCH -f has_issues=true
```

## "'Nova Work Board' not found" when creating an issue with `--project`

This is why `create_issue.sh` uses a two-step approach (create issue, then add to board separately). The `--project` flag fails when:

1. The `project` scope is missing (you only have `read:project`). Fix: `gh auth refresh -s project`
2. The project name doesn't match exactly.

Always use the two-step approach instead: create the issue first, then `gh project item-add`.

## "Your token has not been granted the required scopes"

The error message tells you which scope is missing:

```bash
# For project board mutations
gh auth refresh -s project -h github.com

# Verify after refresh
gh auth status
```

## GraphQL "Could not coerce value to Float"

You're passing a number variable using `-f`, which sends it as a string. Use the `--input` JSON pattern:

```bash
cat > /tmp/update-field.json <<'ENDJSON'
{
  "query": "mutation($p: ID!, $i: ID!, $f: ID!, $h: Float!) { updateProjectV2ItemFieldValue(input: { projectId: $p, itemId: $i, fieldId: $f, value: { number: $h } }) { projectV2Item { id } } }",
  "variables": {
    "p": "PROJECT_ID",
    "i": "ITEM_ID",
    "f": "HOURS_FIELD_ID",
    "h": 2.5
  }
}
ENDJSON

gh api graphql --input /tmp/update-field.json
```

The `h` value must be a JSON number (not a string). This is already handled by `close_issue.sh` and `update_field.sh`.

## "Variable $x of type ID! was provided invalid value"

Typically caused by `-F` (capital F) which expects file-like input. Use lowercase `-f` for string/ID variables and `--input` with a JSON file for mixed types.

## Issue added to board but not visible

Check your board **view filters**. GitHub Projects V2 views can filter by Status, repo, assignee, etc. Newly added items default to no Status if the set-status GraphQL call failed. Try:

1. Switch to "All items" view (no filters)
2. Or check if the item has Status set: query its field values via GraphQL

## `project` scope vs `read:project`

`read:project` (read-only) is NOT the same as `project` (read + write). If you can list projects but can't add items or update fields, you need the full `project` scope:

```bash
gh auth refresh -s project -h github.com
```

## Preflight script fails silently

If `preflight.sh` outputs empty environment variables, check:

1. `gh auth status` — are all scopes present?
2. Is the org name correct? It's case-sensitive: `Nova-Digital-Solutions`
3. Does the Nova Work Board exist at project #1?

```bash
gh project list --owner Nova-Digital-Solutions --limit 5
```
