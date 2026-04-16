---
title: Nova GitHub Workflow Guide
area: engineering
type: guide
onboarding: true
onboarding-order: 1
owner: Nova Digital Solutions
created: 2025-01-01
last-reviewed: 2026-04-15
status: active
---

# Nova GitHub Workflow Guide

How Nova Digital Solutions uses Git and GitHub for project management, issue tracking, and code delivery.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Branching Model](#branching-model)
3. [Project Board](#project-board)
4. [Issue Lifecycle](#issue-lifecycle)
5. [Pull Requests](#pull-requests)
6. [Commit Conventions](#commit-conventions)
7. [Handling Conflicts](#handling-conflicts)
8. [New Repo Setup](#new-repo-setup)
9. [GraphQL Reference](#graphql-reference)
10. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Install the GitHub CLI

```bash
# macOS
brew install gh

# Other platforms: https://cli.github.com/
```

### Authenticate

```bash
gh auth login
```

Choose **GitHub.com**, **HTTPS**, and authenticate via the browser. After login, verify:

```bash
gh auth status
```

### Required Token Scopes

Nova's workflow depends on specific scopes. If any are missing, the CLI will fail silently or with cryptic errors.

| Scope | What it unlocks | How to add |
|-------|----------------|------------|
| `repo` | Issues, PRs, repo settings | Included by default with `gh auth login` |
| `read:org` | Querying org-level data (teams, members) | Included by default |
| `project` | **Reading and writing** to GitHub Projects (Nova Work Board) | `gh auth refresh -s project` |

**Common mistake:** `read:project` (read-only) is *not* the same as `project` (read + write). If you can list projects but can't add items or update fields, you need the full `project` scope.

To add a missing scope without re-authenticating from scratch:

```bash
gh auth refresh -s project -h github.com
```

This opens a browser flow. Complete it, then verify with `gh auth status` — the new scope should appear in the token scopes list.

### Verify Your Setup

Run these checks to confirm everything works:

```bash
# 1. Auth is active
gh auth status

# 2. You can see the org's repos
gh repo list nova-digital-solutions --limit 5

# 3. You can see the project board
gh project list --owner Nova-Digital-Solutions --limit 5
```

If step 3 fails, you're likely missing the `project` scope.

### Determine the Current Repo

Before running repo-specific commands, extract the repo identifier from your local git config:

```bash
git remote get-url origin
# Returns: git@github.com:nova-digital-solutions/acme-web-app.git
# Or:      https://github.com/Nova-Digital-Solutions/acme-web-app.git
# Use:     Nova-Digital-Solutions/acme-web-app
```

---

## Branching Model

```
main ─── production (deployed, protected, requires PR + 1 review)
 │
dev ──── staging (deployed, requires PR, self-merge OK for routine work)
 │
 ├── feature-branch
 ├── fix-login-bug
 └── update-clerk-sdk
```

### Why this model?

- `main` is always production-safe. Nothing lands there without a reviewed PR.
- `dev` is the integration branch. Developers merge their work here first. It maps to a staging environment so the team can test before going live.
- Feature branches are short-lived. They branch off `dev` and merge back into `dev`.

### Branch naming

Keep it short and descriptive. No prefixes, no issue numbers, no conventions to memorize.

Good: `password-reset`, `fix-login-timeout`, `update-clerk-sdk`
Bad: `feature/NDS-123-implement-password-reset-flow`

### Flow

1. Branch off `dev`
2. Do your work
3. PR into `dev` (self-merge OK for routine work)
4. When `dev` is stable, PR into `main` (requires 1 review)

---

## Project Board

### Nova Work Board

All billable work is tracked on a single GitHub Projects board called **Nova Work Board**, owned by the `Nova-Digital-Solutions` org (project #1).

This board is the source of truth for billing. There is no separate spreadsheet.

### Status Columns

The board uses a **Status** field with these values (discover the exact list and IDs via the [GraphQL reference](#get-project-fields)):

| Status | Meaning |
|--------|---------|
| Backlog | Not started, queued for future work |
| In Progress | Actively being worked on |
| In Review | PR is open, awaiting review |
| Done | Merged, closed, hours logged |

> **Note:** Your board may have additional or different statuses. Always query the actual field options via GraphQL rather than assuming a fixed set.

### Project Fields

| Field | Type | When to set | Purpose |
|-------|------|-------------|---------|
| Status | Single-select | Throughout lifecycle | Tracks where work stands |
| Priority | Single-select (P0/P1/P2) | On issue creation | P0 = urgent, P2 = default |
| Size | Single-select (XS/S/M/L/XL) | On issue creation | Rough effort estimate |
| Hours | Number | **On issue close** | Actual hours spent — used for billing |
| Type | Single-select (if present) | On issue creation | Epic, Feature, Bug, Task |

> **Note on Type:** Not all boards have a Type field configured. If the field exists, set it. If it doesn't, skip it — the workflow still works without it.

### How Billing Works

Every closed issue must have its **Hours** field filled in with actual time spent. This is non-negotiable — no hours means unbilled work.

When an issue closes (whether by PR merge or manually), record the hours immediately.

---

## Issue Lifecycle

### Creating an Issue

Every piece of work needs a GitHub issue. If you're about to start something and there's no issue, create one.

```bash
gh issue create \
  --repo OWNER/REPO \
  --title "Clear, action-oriented title" \
  --body "What needs to happen and why." \
  --assignee "@me"
```

Then add it to the board and set project fields as a separate step (see [Adding an Issue to the Board](#adding-an-issue-to-the-board)).

> **Why not use `--project "Nova Work Board"` on create?** The `--project` flag requires the `project` scope and is fragile — it fails if the name doesn't match exactly or the scope is missing, and the entire issue creation fails with it. Creating the issue first, then adding to the board separately, is more reliable.

### Adding an Issue to the Board

```bash
gh project item-add 1 \
  --owner Nova-Digital-Solutions \
  --url https://github.com/Nova-Digital-Solutions/REPO/issues/NUMBER
```

After adding, set project fields (Priority, Size, Status, and optionally Type) using the [GraphQL mutations](#update-a-field-value).

### Inferring Field Values

**Type** (if the field exists):
- **Epic** — large body of work spanning multiple issues
- **Feature** — new functionality for the end user
- **Bug** — something broken
- **Task** — maintenance, config, research, anything else

**Priority:**
- **P0** — developer says "urgent", "ASAP", "blocking", or "client is asking"
- **P1** — important but not on fire
- **P2** — default when unclear

**Size:** Use your best judgment based on scope. XS = a few minutes, XL = multiple days.

### Labels

Labels are for cross-cutting signals that board fields (Type, Priority, Size) don't capture. Keep the set small — don't duplicate what's on the board.

| Label | Color | When to apply | When to remove |
|-------|-------|---------------|----------------|
| `blocked` | `F9D0C4` | Work can't proceed — always add a comment explaining why | Blocker resolved |
| `client-reported` | `C5DEF5` | Issue originated from a client request or complaint | Never (historical record) |
| `needs-design` | `D4C5F9` | Requires design input before implementation can start | Design delivered |

```bash
# Add a label
gh issue edit NUMBER --repo OWNER/REPO --add-label "blocked"
gh issue comment NUMBER --repo OWNER/REPO --body "Blocked: waiting on API credentials from client"

# Remove a label
gh issue edit NUMBER --repo OWNER/REPO --remove-label "blocked"
```

### Closing an Issue

When an issue closes — whether via `Closes #XX` in a PR or manually — two things must happen:

1. **Log hours.** Update the Hours field on the project board with actual time spent.
2. **Set status to Done.** Move the issue to the Done column.

See [Updating Number Fields](#update-a-number-field-hours) for the exact GraphQL pattern.

---

## Pull Requests

### PR into `dev` (routine work)

```bash
git push -u origin BRANCH-NAME

gh pr create \
  --base dev \
  --title "Clear title (#ISSUE_NUMBER)" \
  --body "What changed and why.

Closes #ISSUE_NUMBER"
```

Always include `Closes #ISSUE_NUMBER` so the issue auto-closes on merge. Add screenshots for UI changes.

For routine work, the developer can self-merge:

```bash
gh pr merge --squash
```

For work that needs a second pair of eyes:

```bash
gh pr edit PR_NUMBER --add-reviewer TEAMMATE
```

### PR into `main` (production release)

```bash
gh pr create \
  --base main \
  --head dev \
  --title "Release: Brief summary" \
  --body "Summary of changes going to production.

Includes: #ISSUE1, #ISSUE2"
```

This always requires at least **1 review** before merge. After merge, verify the production deployment.

---

## Commit Conventions

Use the conventional commit format:

```
type: description (#ISSUE)
```

| Type | When |
|------|------|
| `feat` | New functionality |
| `fix` | Bug fix |
| `chore` | Maintenance, config, dependencies |
| `docs` | Documentation only |
| `refactor` | Code change that doesn't fix a bug or add a feature |
| `test` | Adding or updating tests |

Examples:
- `feat: add password reset flow (#12)`
- `fix: resolve login timeout on slow connections (#8)`
- `chore: update Clerk SDK to v5`

---

## Handling Conflicts

If your branch has conflicts with `dev`:

### Option 1: Rebase (preferred — cleaner history)

```bash
git fetch origin
git rebase origin/dev
# Resolve conflicts in each file, then:
git add .
git rebase --continue
git push --force-with-lease
```

### Option 2: Merge (simpler if rebase feels risky)

```bash
git fetch origin
git merge origin/dev
# Resolve conflicts, then:
git add .
git commit
git push
```

**When to use which:**
- Rebase when your branch has a small number of clean commits.
- Merge when your branch has many commits or you're uncomfortable with rebase.
- If the conflict involves someone else's code, check with them before resolving.

---

## New Repo Setup

When the team needs a new client project repo:

```bash
gh repo create nova-digital-solutions/CLIENT-PROJECT \
  --private \
  --clone \
  --gitignore Node \
  --description "DESCRIPTION"

cd CLIENT-PROJECT

git checkout -b dev
git push -u origin dev

# Team access (write for everyone on the nova team)
gh api orgs/nova-digital-solutions/teams/nova/repos/nova-digital-solutions/CLIENT-PROJECT \
  --method PUT \
  --field permission=push

# Labels — remove defaults, keep only what we use
for label in "bug" "documentation" "duplicate" "enhancement" "good first issue" "help wanted" "invalid" "question" "wontfix"; do
  gh label delete "$label" --repo nova-digital-solutions/CLIENT-PROJECT --yes 2>/dev/null
done
gh label create "blocked" --repo nova-digital-solutions/CLIENT-PROJECT \
  --color "F9D0C4" \
  --description "Cannot proceed — see comments" \
  --force

# Repo settings
gh api repos/nova-digital-solutions/CLIENT-PROJECT --method PATCH \
  --field has_wiki=false \
  --field has_issues=true \
  --field has_projects=true \
  --field has_discussions=false \
  --field delete_branch_on_merge=true \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=true \
  --silent

# Branch protection: main (requires PR + 1 review)
gh api repos/nova-digital-solutions/CLIENT-PROJECT/branches/main/protection \
  --method PUT --input - <<'EOF'
{
  "required_status_checks": { "strict": true, "contexts": [] },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_conversation_resolution": true
}
EOF

# Branch protection: dev (requires PR, self-merge OK)
gh api repos/nova-digital-solutions/CLIENT-PROJECT/branches/dev/protection \
  --method PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false
  },
  "restrictions": null
}
EOF
```

### Post-setup checklist

After running the script:

- [ ] Add the repo to **Nova Work Board** (Projects → Settings → Auto-add, or manually)
- [ ] Link to **Vercel** (production from `main`, staging from `dev`)
- [ ] Enable **CodeRabbit** for automated PR reviews
- [ ] Subscribe the Slack channel: `/github subscribe nova-digital-solutions/CLIENT-PROJECT`

---

## GraphQL Reference

GitHub Projects fields (Status, Priority, Size, Hours, etc.) are managed through the GraphQL API. You need three IDs to update any field: the **project ID**, the **item ID** (the issue's entry on the board), and the **field ID**.

### Get Project ID

```bash
gh api graphql -f query='
  query {
    organization(login: "Nova-Digital-Solutions") {
      projectsV2(first: 10) {
        nodes { id title }
      }
    }
  }'
```

The Nova Work Board's ID looks like `PVT_kwDO...`. Cache this — it doesn't change.

### Get Project Fields

This query returns every field on the board, including option IDs for single-select fields:

```bash
gh api graphql -f query='
  query {
    node(id: "PROJECT_ID") {
      ... on ProjectV2 {
        fields(first: 30) {
          nodes {
            ... on ProjectV2Field { id name }
            ... on ProjectV2SingleSelectField { id name options { id name } }
            ... on ProjectV2IterationField { id name }
          }
        }
      }
    }
  }'
```

Cache all field IDs and option IDs. They don't change unless someone reconfigures the board.

### Get the Item ID for an Issue

After adding an issue to the board, find its item ID:

```bash
gh api graphql -f query='
  query {
    node(id: "PROJECT_ID") {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            content {
              ... on Issue {
                number
                repository { nameWithOwner }
              }
            }
          }
        }
      }
    }
  }'
```

Match by issue number and repository to get the item ID (`PVTI_...`).

### Update a Single-Select Field (Status, Priority, Size, Type)

Use `-f` to pass string variables — this works correctly for `ID!` and `String!` types:

```bash
gh api graphql -f query='
  mutation($p: ID!, $i: ID!, $f: ID!, $o: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $p, itemId: $i, fieldId: $f,
      value: { singleSelectOptionId: $o }
    }) { projectV2Item { id } }
  }' \
  -f p="PROJECT_ID" \
  -f i="ITEM_ID" \
  -f f="FIELD_ID" \
  -f o="OPTION_ID"
```

### Update a Number Field (Hours)

**`-f` does not work for `Float!` variables** — it passes strings, and the GraphQL API rejects them. Use `--input` with a JSON file instead:

```bash
cat > /tmp/update-hours.json <<'ENDJSON'
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

gh api graphql --input /tmp/update-hours.json
```

Replace `2.5` with the actual hours. The `h` value must be a JSON number (not a string).

> **Why not inline the number in the query?** Inline values work (`value: { number: 2.5 }`) but using variables is safer and avoids injection issues. The `--input` pattern is the only reliable way to pass typed variables through `gh api graphql`.

---

## Troubleshooting

### "The repository has disabled issues"

The repo's issue tracker is turned off. Enable it:

```bash
gh api repos/OWNER/REPO --method PATCH -f has_issues=true
```

### "'Nova Work Board' not found" when creating an issue with `--project`

This usually means:
1. The `project` scope is missing (you only have `read:project`). Fix: `gh auth refresh -s project`
2. The project name doesn't match exactly. Use the two-step approach instead: create the issue first, then add to board via `gh project item-add`.

### "Your token has not been granted the required scopes"

The error message tells you which scope is missing. Common fixes:

```bash
# For project board mutations
gh auth refresh -s project -h github.com

# Verify after refresh
gh auth status
```

### GraphQL "Could not coerce value to Float"

You're passing a number variable using `-f`, which sends it as a string. Use the `--input` JSON pattern described in [Update a Number Field](#update-a-number-field-hours).

### "Variable $x of type ID! was provided invalid value"

Typically caused by `-F` (capital F) which expects file-like input, or by incorrect JSON formatting. Use lowercase `-f` for string/ID variables and `--input` with a JSON file for mixed types.
