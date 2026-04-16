---
name: nova-cicd
description: >
  Enforces CI/CD guardrails for Nova Digital Solutions' fork-based deployment model.
  Triggers on: push to staging, deploy to production, create a PR, merge this, ship this,
  release, hotfix, promote to staging, what's queued for release, sync fork, git push,
  merge to main, push to main, deploy, ship, promote, what's in staging, release status,
  create pull request, open PR, cherry-pick, hotfix to upstream, production deploy,
  go live, cut a release, weekly release, feature freeze, Monday merge.
  This skill REFUSES dangerous actions, WARNS about risky ones, CORRECTS wrong approaches,
  and OFFERS the right alternative. Always read this skill before executing any
  git push, PR creation, merge, deploy, or release-related command.
---

# Nova CI/CD Guardrails

## Detect Deployment Model (FIRST STEP)

Nova repos use one of two models. **Detect which one before applying any guardrails:**

```bash
git remote -v | grep upstream
```

- **Has `upstream` remote?** → Fork-based model (dev → staging → upstream/main)
- **No `upstream` remote?** → Simple model (dev → main, same repo)

### Fork-Based Model (client projects with upstream repo)

```
Fork (origin)                    Upstream (upstream)
┌─────────┐   PR + review       ┌─────────┐
│   dev   │ ──────────────────►  │         │
│ (free)  │      staging         │  main   │ ── Vercel Production
│         │ ◄── PR from dev ──►  │         │
└─────────┘   ┌──────────┐      └─────────┘
              │ staging  │           ▲
              │ (gated)  │───────────┘
              └──────────┘  Weekly release PR
                              (Tuesday auto)
```

- **origin** = fork repo (development). `dev` auto-deploys preview via Vercel.
- **upstream** = production repo. `main` deploys to production via Vercel.
- Weekly release cycle: staging → upstream/main every Tuesday.

### Simple Model (internal repos, no upstream)

```
main ─── production (protected, requires PR + 1 review)
 │
dev ──── staging/preview (requires PR for routine work, self-merge OK)
 │
 ├── feature-branch
 └── fix-branch
```

- `main` is production. PRs from `dev` require 1 review.
- `dev` is the integration branch. Feature branches merge here first.
- No staging branch, no fork, no weekly release cycle.

## Guardrail Rules — ALWAYS CHECK BEFORE ACTING

Before executing ANY push, PR, merge, or deploy command, evaluate against this table.

### Fork-Based Model (upstream remote exists)

| Developer Action | Response | What To Do |
|---|---|---|
| `git push origin staging` | **BLOCK** | Staging only accepts PRs from dev. Create a PR instead. |
| `git push origin main` | **BLOCK** | main is upstream production. Releases go through the weekly cycle. Ask if they need a hotfix. |
| `git push upstream main` | **BLOCK** | Never push directly to production. Use the weekly release PR or hotfix workflow. |
| `git push upstream` (any) | **BLOCK** | Upstream is managed via PRs and GitHub Actions only. |
| PR to staging with failing CI | **WARN** | CI must pass on dev first. Check failures, fix them, then create the PR. |
| Hotfix branched off `dev` | **CORRECT** | Hotfixes MUST branch off `upstream/main`. Set up: `git checkout -b hotfix/desc upstream/main` |
| Merge to staging on Monday | **WARN** | Monday is feature freeze. Bug fixes are OK. New features must wait until Thursday. Ask which it is. |
| Direct production deploy | **REFUSE** | Production deploys happen via Tuesday's automated release PR. Offer to check what's queued. |
| PR to staging without review | **OFFER** | Staging PRs need at least 1 approval. Offer to request review from CODEOWNERS. |
| PR to main from dev | **CORRECT** | Production PRs come from staging, not dev. Offer to create a PR to staging instead. |

### Simple Model (no upstream remote)

| Developer Action | Response | What To Do |
|---|---|---|
| `git push origin main` | **BLOCK** | main is protected. Create a PR from dev instead. |
| PR to main without review | **WARN** | PRs to main require at least 1 review. Offer to add a reviewer. |
| Push to dev | **ALLOW** | Dev is the integration branch. Push freely. |
| PR from feature to main | **CORRECT** | Feature branches merge into dev first, then dev merges to main. |
| PR from dev to main | **ALLOW** | This is the correct flow. Requires 1 review. |

## Validation Logic

Before ANY git push, PR creation, or merge, run the guardrail checklist:

1. **Detect the deployment model** — check for `upstream` remote.
2. **Detect the target branch** from the command or request.
3. **Check the guardrail table** above (use the correct model). If BLOCK → refuse and explain why, offer the correct alternative.
4. **Check the day of week.** Monday = feature freeze for staging (fork model only).
5. **Check CI status** on the source branch: `gh run list --branch BRANCH --limit 5 --json status,conclusion`
6. **If creating a PR to staging or main**, suggest running the `review` or `security-review` skill on the diff first.

Run `scripts/validate_action.sh --action ACTION --target-branch TARGET --source-branch SOURCE` to automate checks.

## Branching Model

### Fork-Based

| Branch | Repo | Purpose | Who Pushes | Deploy Target |
|---|---|---|---|---|
| `dev` | origin (fork) | Active development | Everyone, freely | Vercel preview |
| `staging` | origin (fork) | Release candidate | PRs from dev only | Vercel staging |
| `main` | upstream | Production | Weekly PR from staging | Vercel production |
| `feature/*` | origin | Feature work | Developer | — |
| `hotfix/*` | origin | Emergency fix | Developer | PR to upstream/main |

### Simple

| Branch | Repo | Purpose | Who Pushes | Deploy Target |
|---|---|---|---|---|
| `dev` | origin | Integration / staging | Everyone, freely | Vercel preview |
| `main` | origin | Production | PRs from dev (1 review) | Vercel production |
| `feature/*` | origin | Feature work | Developer | — |

## PR Creation Workflow

### Feature Work → dev

```bash
# Push feature branch and create PR to dev
bash scripts/create_pr.sh --base dev --title "feat: description" --issue-number 42
```

No restrictions on merging to dev. CI runs automatically.

### Promoting to Staging

```bash
# Create PR from dev to staging
bash scripts/create_pr.sh --base staging --title "Release: batch description"
```

Requirements enforced:
- Source branch must be `dev`
- CI must be passing on dev
- At least 1 approval required (CODEOWNERS auto-assigns)
- Not Monday (feature freeze) unless it's a bug fix

After creating the PR, consider running:
- `review` skill on the diff for code quality
- `security-review` skill if the change touches auth, API keys, or user data

### Production Release

Production PRs are **automated**. Do NOT create them manually. See Release Workflow below.

## Release Workflow

### Check What's Queued

```bash
bash scripts/release_status.sh
```

Shows commits in staging that haven't reached production yet, grouped by type.

### Weekly Release (Automated)

- **Tuesday 9 AM WAT**: GitHub Action "Weekly Release to Upstream" auto-creates a PR from `fork/staging` to `upstream/main` with a generated changelog.
- **Tuesday-Wednesday**: Upstream admin reviews and merges.
- **Wednesday**: Vercel deploys to production.

### Manual Release (Emergency)

If a release is needed outside the Tuesday cycle:
1. Go to fork repo → Actions → "Weekly Release to Upstream" → Run workflow
2. Communicate with the team first
3. Ensure upstream admin is available to review

## Hotfix Decision Tree

```
Production bug reported
        │
        ▼
Does the fix already exist in staging?
        │
   ┌────┴────┐
   YES       NO
   │         │
   ▼         ▼
Scenario A   Scenario B
Cherry-pick  New fix off
via Action   upstream/main
```

### Scenario A: Fix exists in staging
→ Use GitHub Action "Hotfix to Upstream" with the commit SHA.
→ See `references/hotfix-playbook.md` for full steps.

### Scenario B: New fix needed
→ Branch off `upstream/main` (NEVER off dev!):
```bash
git fetch upstream
git checkout -b hotfix/description upstream/main
```
→ See `references/hotfix-playbook.md` for full steps.

**After ANY hotfix merges**: run `scripts/sync_fork.sh` or wait for the daily auto-sync.

## Fork Sync

### Automatic (Daily)
GitHub Action runs at **7 AM WAT** daily: upstream/main → staging → dev.
On conflict: sync aborts and creates a GitHub issue. Resolve promptly — delayed resolution causes painful release PR conflicts.

### Manual
```bash
bash scripts/sync_fork.sh
```

See `references/conflict-resolution.md` for merge conflict strategies.

## Commit Format

```
type: description (#ISSUE)
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`

## .gitignore Enforcement

When creating repos, reviewing PRs, or setting up new projects, verify `.gitignore` coverage:

- **BLOCK** any commit containing `.env`, `node_modules/`, or `*.pem` files
- **WARN** on missing `.gitignore` in new repos
- **CORRECT** if build artifacts (`.next/`, `dist/`, `.convex/`) are tracked

See `references/gitignore-practices.md` for the full template and verification commands.

## References

Load these only when detailed context is needed:
- `references/infrastructure.md` — Full infra: why fork model, Vercel setup, Convex backends
- `references/release-calendar.md` — Detailed weekly schedule, manual release process
- `references/hotfix-playbook.md` — Complete hotfix commands for both scenarios
- `references/env-vars.md` — Environment variables per branch/project
- `references/conflict-resolution.md` — Rebase vs merge, sync conflict resolution
- `references/gitignore-practices.md` — .gitignore template, critical rules, verification

## Quick Reference

```
# Daily development
git push origin dev                    # ✅ Always OK
git push origin feature/my-thing       # ✅ Always OK

# Promote to staging (PR only)
bash scripts/create_pr.sh --base staging --title "Release: ..."

# Check release queue
bash scripts/release_status.sh

# Hotfix (ALWAYS from upstream/main)
git fetch upstream && git checkout -b hotfix/fix upstream/main

# Sync fork manually
bash scripts/sync_fork.sh

# NEVER DO THESE
git push origin staging                # ❌ BLOCKED
git push origin main                   # ❌ BLOCKED
git push upstream main                 # ❌ BLOCKED
git push upstream anything             # ❌ BLOCKED
```
