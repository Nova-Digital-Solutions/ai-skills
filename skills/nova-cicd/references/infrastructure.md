# Infrastructure — Nova Fork-Based Deployment Model

## Why a Fork-Based Model?

Nova Digital Solutions builds software for clients. The **upstream repo** belongs to the client (or is the canonical production repo). Nova maintains a **fork** where all development happens. This gives:

1. **Clean separation of concerns**: Development and production are in different repos with different access controls.
2. **Client control**: The client (or upstream admin) has final approval over what goes to production.
3. **Independent CI/CD**: Each repo has its own GitHub Actions, branch protections, and Vercel deployments.
4. **No accidental production pushes**: Developers can't accidentally push to production because it's a different repo.

## Repository Structure

```
┌────────────────────────────────────────┐
│  UPSTREAM REPO (Production)            │
│  github.com/<client-org>/<project>     │
│                                        │
│  main ─── Vercel Production Project    │
│           └── production env vars      │
│           └── production Convex        │
│           └── custom domain            │
└────────────────────┬───────────────────┘
                     │
          Weekly PR (Tuesday)
          Hotfix PR (as needed)
                     │
┌────────────────────┴───────────────────┐
│  FORK REPO (Development)               │
│  github.com/nova-digital-solutions/... │
│                                        │
│  dev ──── Vercel Fork Project          │
│  │        └── dev preview deployments  │
│  │        └── dev Convex backend       │
│  │                                     │
│  staging ─ Vercel Fork Project         │
│            └── staging deployment      │
│            └── staging Convex backend  │
└────────────────────────────────────────┘
```

## Git Remotes

Every developer's local setup:

```bash
git remote -v
# origin    git@github.com:nova-digital-solutions/<project>.git (fetch/push)
# upstream  git@github.com:<client-org>/<project>.git (fetch/push)
```

- **origin** = Nova's fork. Push feature branches and dev here.
- **upstream** = Client's production repo. Never push directly. PRs only.

## Why Two Vercel Projects?

Vercel enforces a 1:1 mapping between a Git repository and a Vercel project. Since we have two repos (fork and upstream), we need two Vercel projects:

| Vercel Project | Connected Repo | Branches | Domain |
|---|---|---|---|
| Fork Project | nova-digital-solutions/project | dev, staging | *.vercel.app (preview) |
| Upstream Project | client-org/project | main | production domain |

This gives clean environment variable separation — the fork project has dev/staging Convex URLs and deploy keys, while the upstream project has production credentials.

## Convex Backends

Each environment has its own Convex deployment:

| Environment | Convex Backend | Connected To |
|---|---|---|
| dev | `dev-project-name` | Fork Vercel (dev branch) |
| staging | `staging-project-name` | Fork Vercel (staging branch) |
| production | `prod-project-name` | Upstream Vercel (main branch) |

Convex deploy keys are stored as Vercel environment variables, scoped to the correct branch.

## Branch Protection Rules

### Fork Repo (origin)

| Branch | Protection |
|---|---|
| `dev` | None — everyone pushes freely. CI runs on every push. |
| `staging` | Requires PR + CI passing. CODEOWNERS auto-assigns reviewers. |

### Upstream Repo

| Branch | Protection |
|---|---|
| `main` | Requires PR + 1 review from upstream admin. CI passing. |

## CI Pipeline

CI runs on every push to dev and on every PR:

1. **Lint** — ESLint with Convex plugin
2. **Type check** — `tsc --noEmit`
3. **Tests** — Unit and integration tests

All three must pass before a PR to staging can be merged.

## GitHub Actions

### Fork Repo Actions

| Action | Trigger | Purpose |
|---|---|---|
| CI (lint, typecheck, tests) | Push to dev, PRs | Quality gate |
| Weekly Release to Upstream | Scheduled Tuesday 9 AM WAT / Manual | Creates PR from staging to upstream/main |
| Hotfix to Upstream | Manual (commit SHA input) | Cherry-picks fix to upstream/main PR |
| Sync from Upstream | Scheduled daily 7 AM WAT / Manual | Pulls upstream/main → staging → dev |

### Upstream Repo Actions

| Action | Trigger | Purpose |
|---|---|---|
| CI | PRs to main | Quality gate for production |
| Vercel Deploy | Merge to main | Auto-deploys via Vercel integration |

## Complete Flow Diagram

```
Developer workstation
    │
    ├── git push origin dev              (free, CI runs)
    ├── git push origin feature/x        (free)
    │
    ▼
Fork: dev branch
    │
    ├── PR (requires CI passing)
    ▼
Fork: staging branch
    │
    ├── Tuesday: GitHub Action creates PR
    ├── Or: Manual "Weekly Release to Upstream" action
    ▼
Upstream: main branch (PR requires admin review)
    │
    ├── Vercel auto-deploys to production
    ▼
Production (end users)
```

## Troubleshooting

### "I don't have an upstream remote"

```bash
git remote add upstream git@github.com:<client-org>/<project>.git
git fetch upstream
```

### "Vercel isn't deploying my branch"

Only branches configured in the Vercel project settings trigger deployments. For the fork project, this is typically `dev` and `staging`. Feature branches get preview deployments if the Vercel project is configured for it.

### "CI is failing on staging but I didn't change anything"

The daily sync from upstream may have introduced changes. Check the sync action logs and resolve any issues in dev first.
