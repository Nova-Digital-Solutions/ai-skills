---
name: nova-issues
description: >
  Automatic, invisible project management for Nova Digital Solutions. Triggers on ANY development
  activity: coding, committing, pushing, branching, merging, starting work, finishing work, or
  mentioning issues, tasks, bugs, hours, or the board. Also triggers on phrases like "I need to
  work on X", "this is done", "ship this", "push this", "ready for review", "what's on the board",
  "how many hours", "create an issue", "close this issue", "I'm blocked", "what should I work on",
  "project status". Manages GitHub issues, project board, and epics so the developer can focus on
  coding.
---

# Nova Project Management

Nova Digital Solutions tracks all billable work through GitHub Issues on the **Nova Work Board**.
Every task needs an issue. Every closed issue needs hours. Hours are how Nova bills clients.

**Org:** `Nova-Digital-Solutions` | **Board:** Nova Work Board (project #1)

## Core Principles

1. **Every task needs an issue** — create one silently if missing.
2. **Every issue goes on the board** — add it automatically after creation.
3. **Hours are mandatory on close** — this is the ONE thing that requires developer input.
4. **Status transitions are automatic** — inferred from git activity, never asked.

## Preflight (run once per session)

Run `bash <skill_path>/scripts/preflight.sh` and cache the output. This:

1. Verifies `gh auth status` — checks for `repo`, `project`, `read:org` scopes.
   - If `project` scope is missing, tell the developer:
     > Run `gh auth refresh -s project -h github.com` to add the project scope.
2. Determines OWNER/REPO from `git remote get-url origin`.
3. Queries the Nova Work Board project ID and all field/option IDs.
4. Outputs environment variables to source for the session.

**Do not proceed with any board operations until preflight succeeds.**

## Observation Rules

Constantly infer what the developer is doing. Never ask "are you working on an issue?" — figure it out.

### How to detect context

| Signal | How to read it |
|---|---|
| Branch name | `git branch --show-current` — parse for issue numbers (`42-login-page` → #42) or keywords |
| Commit messages | `git log --oneline -5` — look for `#N` references and conventional commit types |
| PR creation | `gh pr list --head BRANCH` — check if PR exists, parse body for `Closes #N` |
| Developer says | "I'm working on X", "this is done", "I'm blocked", "what's next" |

Run `bash <skill_path>/scripts/infer_issue_from_context.sh` to automate context detection.

## Automation Workflows

### Starting Work

```
Developer checks out branch or says "I'm working on X"
  │
  ├─ Issue number found in branch/context?
  │   ├─ YES → Verify issue exists → Set Status → "In progress"
  │   └─ NO → Search open issues by keywords
  │       ├─ Match found → Confirm with developer → Set Status → "In progress"
  │       └─ No match → Create issue silently (see Issue Creation below)
  │
  └─ Ensure assignee is set to the developer
```

### During Work

- **Commits with `#N`**: Verify issue #N exists and is In Progress. Update board if needed.
- **Commits without `#N`**: Run context inference. If no issue is tracked, create one.
- **Developer says "I'm blocked"**: Add `blocked` label, ask why, comment on the issue.
- **Context switch detected** (new branch, different topic): Ensure new work has an issue too.
- **Sub-task needed**: Create as a new issue and add as sub-issue of the current epic.

### Completing Work

```
Developer says "this is done" / "ship this" / "ready for review"
  │
  ├─ PR exists for current branch?
  │   ├─ YES → Ensure PR body has "Closes #N" → Set Status → "In Review"
  │   └─ NO → Create PR with conventional title → Link issue → Status → "In Review"
  │
  └─ Wait for merge / close events
```

### Issue Closing

```
Issue closes (via PR merge or manual close)
  │
  ├─ Ask developer: "How many hours on #N? (title)"
  │   └─ Developer responds with number
  │       ├─ Run: bash <skill_path>/scripts/close_issue.sh --repo OWNER/REPO --issue-number N --hours H
  │       └─ This updates Hours field, sets Status → Done, checks epic completion
  │
  └─ NEVER skip the hours prompt. This is how Nova bills.
```

## Labels

Labels are for cross-cutting concerns that board fields don't capture. Do NOT duplicate board fields (Type, Priority, Size) as labels.

| Label | When to apply | When to remove |
|---|---|---|
| `blocked` | Work can't proceed — always add a comment explaining why | Blocker resolved |
| `client-reported` | Issue originated from a client request or complaint | Never (historical record) |
| `needs-design` | Requires design input before implementation can start | Design delivered |

Apply labels during issue creation or when the situation changes. Use `gh issue edit NUMBER --repo OWNER/REPO --add-label "LABEL"`.

Ensure these labels exist in each repo. If missing, create them during repo setup (see `references/repo-setup.md`).

## Issue Creation

Three-step process — **never use `gh issue create --project`** (it's fragile and often fails):

1. **Create the issue**: `gh issue create --title "..." --body "..." --assignee @me`
2. **Set issue type**: GraphQL `updateIssueIssueType` mutation (Epic/Feature/Bug/Task)
3. **Add to board + set fields**: `gh project item-add` then GraphQL to set Status, Priority, Size

Use `bash <skill_path>/scripts/create_issue.sh` with flags:
```
--repo OWNER/REPO --title "Title" --body "Body" \
--type Feature --priority P1 --size M --assignee @me
```

For body templates, see `<skill_path>/references/issue-templates.md`.

## Issue Closing

Use `bash <skill_path>/scripts/close_issue.sh`:
```
--repo OWNER/REPO --issue-number 42 --hours 3.5 --reason completed
```

This handles: closing the issue, updating Hours (Float field), setting Status → Done, and checking
if the parent epic is complete.

## Board Field Reference

| Field | Type | Values | When to set |
|---|---|---|---|
| Status | Single select | Backlog, In progress, In Review, Done | On every state transition |
| Priority | Single select | P0, P1, P2 | On issue creation |
| Size | Single select | XS, S, M, L, XL | On issue creation |
| Hours | Number (Float) | Any decimal | On issue close — MANDATORY |
| Iteration | Iteration | Current sprint | On issue creation if iteration is active |
| Start date | Date | ISO 8601 | When Status → In progress |
| Target date | Date | ISO 8601 | On issue creation if deadline known |

For detailed field operations and GraphQL examples, see `<skill_path>/references/board-fields.md`.

## Epics

- An epic is an issue with type "Epic" that has sub-issues.
- Every issue in a larger effort must be a sub-issue of an epic.
- When all sub-issues close, prompt the developer to close the epic.
- See `<skill_path>/references/epics-and-sub-issues.md` for full GraphQL operations.

## Conventional Commits

All commits should follow: `type: description (#ISSUE)`

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`

Examples:
- `feat: add user login page (#42)`
- `fix: resolve null pointer in auth flow (#43)`

## Script Reference

| Script | Purpose |
|---|---|
| `scripts/preflight.sh` | Auth check, field ID discovery, session setup |
| `scripts/create_issue.sh` | Create issue → set type → add to board |
| `scripts/close_issue.sh` | Close issue → set hours → update status → check epic |
| `scripts/update_field.sh` | Generic board field updater (any field type) |
| `scripts/infer_issue_from_context.sh` | Detect current issue from git state |

## Detailed References

| File | When to read |
|---|---|
| `references/board-fields.md` | Updating board fields, GraphQL field operations |
| `references/epics-and-sub-issues.md` | Creating/managing epics and sub-issues |
| `references/issue-templates.md` | Issue body templates for Bug/Feature/Task |
| `references/repo-setup.md` | Setting up a new repo (rare) |
| `references/troubleshooting.md` | Scope errors, Float coercion, board visibility, common failures |

## Quick Reference

```bash
# Check current issue context
bash <skill_path>/scripts/infer_issue_from_context.sh

# Create an issue
bash <skill_path>/scripts/create_issue.sh --repo OWNER/REPO --title "Title" --body "Body" --type Feature --priority P1 --size M

# Close an issue with hours
bash <skill_path>/scripts/close_issue.sh --repo OWNER/REPO --issue-number 42 --hours 3.5

# Update a board field
bash <skill_path>/scripts/update_field.sh --item-id ITEM_ID --field-name Status --value "In progress"

# Run preflight
bash <skill_path>/scripts/preflight.sh
```

**Remember:** The developer should never have to think about project management. You handle it.
