# Release Process & Deployment Guide

## Purpose

This document outlines our release process, branching strategy, and deployment infrastructure. The goal is to give every developer a clear, repeatable workflow for getting code from local development into production, with proper review gates and a predictable release schedule.

---

## How Our Infrastructure Is Set Up

We maintain a **fork** of the upstream production repository. All development happens in our fork. Code only reaches production through a reviewed pull request from our fork to the upstream repo.

Because Vercel ties each project to a single GitHub repository, we run **two separate Vercel projects**:

### Vercel Project 1: Fork (Development & Staging)

- **Connected to:** Our forked GitHub repository
- **Branches deployed:** `dev` and `staging` (preview deployments only)
- **No production deployment** -- this project only generates preview URLs
- **Convex backend:** Connected to our dev and staging Convex deployments
- **Who uses it:** The development team, for testing and review

| Branch | Preview URL | Convex Backend | Purpose |
|--------|------------|----------------|---------|
| `dev` | `dev.yourapp.com` (or auto-generated Vercel preview URL) | Dev deployment | Active development, quick iteration |
| `staging` | `staging.yourapp.com` (or auto-generated Vercel preview URL) | Staging deployment | Pre-production review, QA |

### Vercel Project 2: Upstream (Production)

- **Connected to:** The upstream GitHub repository
- **Production branch:** `main`
- **Convex backend:** Connected to the production Convex deployment
- **Who uses it:** End users

| Branch | URL | Convex Backend | Purpose |
|--------|-----|----------------|---------|
| `main` | `yourapp.com` | Production deployment | Live product |

### Why Two Projects?

Vercel requires a 1:1 relationship between a project and a GitHub repo. Since our fork and the upstream repo are separate repositories, each needs its own Vercel project. This also gives us clean separation of environment variables (API keys, Convex URLs) so there is zero risk of a preview deployment accidentally hitting the production database.

---

## Branching Model

```
  Developer's local machine
          |
          | git push
          v
    fork/dev                 Everyone pushes here freely.
          |                  Vercel auto-deploys a preview.
          |
          | Pull Request (requires 1 approval + CI passing)
          v
    fork/staging             Integration-tested, QA-ready.
          |                  Vercel auto-deploys a staging preview.
          |
          | Weekly Pull Request (auto-created, upstream admin approves)
          v
    upstream/main            Production. Vercel deploys to live.
```

### Branch Roles

**`dev` (fork)** -- The shared development branch. Every developer pushes here directly. No PR required to push to `dev`. This is where work-in-progress lives and where the team can preview the latest state of everything together. CI (lint, typecheck, tests) runs on every push.

**`staging` (fork)** -- The "ready for production" branch. Code moves here via a reviewed pull request from `dev`. Once something is in `staging`, it is considered stable and release-ready. Nothing should land in `staging` that is not ready to ship.

**`main` (upstream)** -- Production. Code moves here via a weekly cross-fork pull request from our `staging`. An admin on the upstream repo reviews and merges. This triggers the production Vercel deployment.

---

## Day-to-Day Developer Workflow

### 1. Working locally

```bash
git checkout dev
git pull origin dev

# Make your changes
git add .
git commit -m "feat: add profile settings page"
git push origin dev
```

That is it. Pushing to `dev` triggers two things automatically:
- Vercel deploys a preview you can share with the team
- CI runs lint, typecheck, and tests

### 2. Promoting to staging

When your work (or a set of changes on `dev`) is ready for release:

1. Go to GitHub and open a **Pull Request** from `dev` to `staging`
2. A reviewer is auto-assigned (via CODEOWNERS)
3. The reviewer checks the code and the `dev` preview URL
4. CI must pass
5. Once approved, merge the PR

You can open PRs to staging at any point during the week. There is no restriction on when code can land in staging. The restriction is only on when staging gets promoted to production.

### 3. What NOT to do

- **Do not push directly to `staging`.** Always go through a PR from `dev`.
- **Do not push directly to upstream `main`.** Always go through the weekly release process.
- **Do not merge to `staging` if the work is not ready to ship.** Staging is the release queue. If it is in staging, it ships with the next release.

---

## Weekly Release Cycle

Releases to production happen **once per week on a fixed schedule**.

### Release Calendar

| Day | Activity |
|-----|----------|
| **Monday** | Feature freeze for staging. Avoid merging new features to staging on Monday. Focus on bug fixes and QA against the staging preview. |
| **Tuesday 9 AM WAT** | A GitHub Action automatically creates a pull request from our fork's `staging` to upstream's `main`. The PR includes a changelog generated from commit messages. |
| **Tuesday - Wednesday** | The upstream admin reviews the release PR. The team is available to answer questions or address feedback. |
| **Wednesday** | The upstream admin merges the PR. Vercel deploys to production. |
| **Thursday - Friday** | Normal development resumes. Merge freely to staging for the following week's release. |

### What the automated release PR looks like

The PR is created automatically with:
- A title like "Release 2026-04-22"
- A changelog listing every commit that landed in staging since the last release
- The total number of commits included

If nothing new has been merged to staging since the last release, no PR is created.

### Can we release more than once a week?

Yes. The release workflow has a manual trigger. Any team member with Actions access can go to **Actions > Weekly Release to Upstream > Run workflow** and create a release PR on demand. Use this sparingly and communicate with the team when you do.

---

## Hotfix Process

Sometimes a bug in production cannot wait for the next weekly release. Here is the process for shipping an urgent fix outside the regular cycle.

### Scenario A: The fix already exists in staging

If a developer already merged a fix to staging earlier in the week:

1. Go to **Actions > Hotfix to Upstream > Run workflow**
2. Enter the **commit SHA** of the fix (find it in the staging branch's commit history)
3. Enter a **branch name** like `hotfix/fix-payment-crash`
4. Enter a brief **description** of what the fix addresses
5. The workflow cherry-picks that specific commit onto a new branch based on upstream's `main` and opens a PR to upstream
6. The upstream admin reviews and merges
7. After merge, run **Actions > Sync from Upstream** to pull the fix back into `staging` and `dev`

### Scenario B: The fix has not been written yet

If the bug needs a new fix written from scratch:

1. Branch off upstream's `main` (not off `dev` or `staging`):
   ```bash
   git fetch upstream
   git checkout -b hotfix/fix-payment-crash upstream/main
   ```
2. Write and test the fix locally
3. Push the branch to the fork: `git push origin hotfix/fix-payment-crash`
4. Open a PR from the hotfix branch directly to upstream's `main`
5. The upstream admin reviews and merges
6. After merge, cherry-pick or merge the fix into `staging` and `dev` so they do not drift

### Important

- Always communicate hotfixes in the team channel before triggering them
- After any hotfix merges upstream, always sync back into `staging` and `dev`
- The hotfix branch is disposable. Delete it after the PR merges.

---

## Keeping the Fork in Sync

A daily GitHub Action (runs at 7 AM WAT) automatically pulls changes from upstream's `main` back into our `staging` and then into `dev`. This ensures our fork does not drift from production.

If the sync encounters a merge conflict, it will:
- Abort the merge (nothing breaks)
- Create a GitHub issue with the title "Upstream sync conflict" and instructions for resolving it manually

When you see a sync conflict issue, resolve it promptly. A fork that is out of sync with upstream will cause painful merge conflicts when the next release PR is created.

---

## CI / Automated Checks

Every push to `dev` and every PR to `staging` triggers the CI pipeline, which runs:

1. **Lint** -- code style and formatting
2. **Typecheck** -- TypeScript compiler check (`tsc --noEmit`)
3. **Tests** -- runs the test suite if one exists

The `staging` branch has branch protection rules that **require CI to pass** before a PR can be merged. If CI fails, fix the issue on `dev` and push again. The PR will update automatically.

---

## Permissions & Access

| Action | Who can do it |
|--------|--------------|
| Push to `dev` | All developers |
| Open PR from `dev` to `staging` | All developers |
| Approve PRs to `staging` | Designated reviewers (CODEOWNERS) |
| Merge PRs to `staging` | Anyone with write access (after approval) |
| Trigger weekly release workflow | Anyone with Actions access |
| Trigger hotfix workflow | Anyone with Actions access |
| Approve and merge release PR to upstream | Upstream admin(s) |

---

## Environment Variable Reference

Each Vercel project and branch needs the correct environment variables to point at the right backend.

### Fork Vercel Project

| Variable | `dev` branch (Preview) | `staging` branch (Preview) |
|----------|----------------------|---------------------------|
| `CONVEX_DEPLOY_KEY` | Dev deployment key | Staging deployment key |
| `NEXT_PUBLIC_CONVEX_URL` | Dev Convex URL | Staging Convex URL |

### Upstream Vercel Project

| Variable | `main` branch (Production) |
|----------|---------------------------|
| `CONVEX_DEPLOY_KEY` | Production deployment key |
| `NEXT_PUBLIC_CONVEX_URL` | Production Convex URL |

Make sure these are set correctly in each Vercel project's settings. A misconfigured environment variable is the easiest way to accidentally point a preview at the production database.

---

## Quick Reference

```
I want to...                          Do this
---------------------------------------------------------------------------------------------------------
Start working on something             git checkout dev && git pull origin dev
Share my work with the team             git push origin dev (preview auto-deploys)
Get my work ready for release           Open PR: dev -> staging, get it reviewed
Ship to production                      Wait for Tuesday's automated release PR
Ship something urgently                 Use the Hotfix workflow in GitHub Actions
Check the staging preview               Visit the staging preview URL
Check the production site               Visit the production URL
See what is queued for next release     Compare staging to upstream/main on GitHub
```

---

## Questions?

If anything in this process is unclear, raise it in the team channel. We will update this document as the process evolves.
