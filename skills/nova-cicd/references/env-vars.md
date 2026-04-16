# Environment Variables Reference

## Overview

Each environment (dev, staging, production) has its own set of environment variables configured in the corresponding Vercel project. Because we use two Vercel projects (fork and upstream), environment variables are naturally isolated.

## Fork Vercel Project

Connected to: `nova-digital-solutions/<project>`

### dev Branch

| Variable | Description | Example |
|---|---|---|
| `CONVEX_DEPLOY_KEY` | Deploy key for the dev Convex backend | `prod:...` (scoped to dev deployment) |
| `NEXT_PUBLIC_CONVEX_URL` | Public Convex URL for the dev backend | `https://dev-project.convex.cloud` |
| `NEXT_PUBLIC_ENVIRONMENT` | Environment identifier | `development` |

Vercel scope: **Preview** (with branch filter: `dev`)

### staging Branch

| Variable | Description | Example |
|---|---|---|
| `CONVEX_DEPLOY_KEY` | Deploy key for the staging Convex backend | `prod:...` (scoped to staging deployment) |
| `NEXT_PUBLIC_CONVEX_URL` | Public Convex URL for the staging backend | `https://staging-project.convex.cloud` |
| `NEXT_PUBLIC_ENVIRONMENT` | Environment identifier | `staging` |

Vercel scope: **Preview** (with branch filter: `staging`)

## Upstream Vercel Project

Connected to: `<client-org>/<project>`

### main Branch

| Variable | Description | Example |
|---|---|---|
| `CONVEX_DEPLOY_KEY` | Deploy key for the production Convex backend | `prod:...` (scoped to production deployment) |
| `NEXT_PUBLIC_CONVEX_URL` | Public Convex URL for the production backend | `https://prod-project.convex.cloud` |
| `NEXT_PUBLIC_ENVIRONMENT` | Environment identifier | `production` |

Vercel scope: **Production**

## How Vercel Scoping Works

Vercel environment variables can be scoped to:
- **Production**: Only used for production deployments (the `main` branch of the upstream project)
- **Preview**: Used for preview deployments (branches, PRs). Can be further filtered by branch name.
- **Development**: Used for `vercel dev` local development.

For the fork project, we use **Preview** scope with branch filters to differentiate between dev and staging.

## Convex Deploy Keys

Each Convex deployment has a unique deploy key. The deploy key authorizes the Vercel build process to push Convex functions during deployment.

**Generate a deploy key:**
```bash
npx convex deploy --cmd 'echo' --project <project-name>
```

Or from the Convex dashboard: Project Settings → Deploy Keys.

**Key format:** Deploy keys start with `prod:` followed by a long string.

## Adding New Environment Variables

### For dev/staging (Fork Vercel Project)

1. Go to Fork Vercel Project → Settings → Environment Variables
2. Add the variable
3. Set scope to **Preview**
4. Add a branch filter for the correct branch (`dev` or `staging`)
5. Save

### For production (Upstream Vercel Project)

1. Go to Upstream Vercel Project → Settings → Environment Variables
2. Add the variable
3. Set scope to **Production**
4. Save

## Misconfiguration Risks

### Wrong Convex URL

If `NEXT_PUBLIC_CONVEX_URL` points to the wrong backend:
- **Staging pointing to dev**: Staging tests hit the dev database. Data may be inconsistent.
- **Dev pointing to production**: Development operations modify production data. **Critical risk.**
- **Production pointing to staging**: Users see staging data. **Critical risk.**

Always verify after adding or changing Convex environment variables.

### Missing Deploy Key

If `CONVEX_DEPLOY_KEY` is missing or wrong:
- Vercel build will succeed but Convex functions won't deploy
- The app will run with stale Convex functions
- Errors may not be immediately obvious

### Branch Filter Misconfiguration

If Vercel branch filters are wrong:
- A staging deployment could use dev env vars (or vice versa)
- Check: Vercel Project → Settings → Environment Variables → click the variable → verify the branch filter

## Verification Commands

Check which Convex URL the deployed app is using:
```bash
# In browser devtools on the deployed site:
# Look for WebSocket connections to *.convex.cloud
# The subdomain should match the expected backend
```

Check Convex deployment status:
```bash
npx convex dashboard --project <project-name>
```

## Local Development

For local development, use a `.env.local` file (gitignored):

```env
CONVEX_DEPLOYMENT=dev:<your-dev-deployment>
NEXT_PUBLIC_CONVEX_URL=https://your-dev-project.convex.cloud
```

Never use staging or production Convex URLs locally unless intentionally debugging a specific environment.
