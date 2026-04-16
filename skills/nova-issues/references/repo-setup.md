# Repository Setup Reference

Full instructions for setting up a new Nova Digital Solutions repository. This is rarely needed — only when starting a brand new project.

## 1. Create the Repository

```bash
gh repo create Nova-Digital-Solutions/PROJECT_NAME \
  --private \
  --description "Brief project description" \
  --clone
```

For client projects, always use `--private`.

## 2. Initialize with Dev Branch

```bash
cd PROJECT_NAME
git checkout -b dev
git push -u origin dev
```

The `dev` branch is where day-to-day work merges. `main` is for production releases.

## 3. Set Team Access

```bash
# Add the dev team with write access
gh api orgs/Nova-Digital-Solutions/teams/developers/repos/Nova-Digital-Solutions/PROJECT_NAME \
  -X PUT -f permission=push

# Add tech leads with maintain access (if applicable)
gh api orgs/Nova-Digital-Solutions/teams/tech-leads/repos/Nova-Digital-Solutions/PROJECT_NAME \
  -X PUT -f permission=maintain
```

## 4. Clean Up Labels

Remove GitHub's default labels and create only what Nova uses:

```bash
# Delete all default labels
for label in bug documentation duplicate enhancement "good first issue" "help wanted" "invalid" question wontfix; do
  gh label delete "$label" --repo Nova-Digital-Solutions/PROJECT_NAME --yes 2>/dev/null || true
done

# Create Nova's labels
gh label create "blocked" \
  --repo Nova-Digital-Solutions/PROJECT_NAME \
  --description "Work is blocked — see issue comments for reason" \
  --color "F9D0C4" --force

gh label create "client-reported" \
  --repo Nova-Digital-Solutions/PROJECT_NAME \
  --description "Originated from a client request or complaint" \
  --color "C5DEF5" --force

gh label create "needs-design" \
  --repo Nova-Digital-Solutions/PROJECT_NAME \
  --description "Requires design input before implementation" \
  --color "D4C5F9" --force
```

## 5. Repository Settings

Configure via `gh api`:

```bash
REPO="Nova-Digital-Solutions/PROJECT_NAME"

# Enable squash merge only, auto-delete branches after merge
gh api repos/$REPO \
  -X PATCH \
  -f default_branch=main \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true
```

## 6. Branch Protection Rules

### Main branch (production)

Requires PR with at least 1 approval. No direct pushes.

```bash
gh api repos/$REPO/branches/main/protection \
  -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

### Dev branch (integration)

Requires PR but allows self-merge (developer can merge their own PR to dev).

```bash
gh api repos/$REPO/branches/dev/protection \
  -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

## 7. Add to Nova Work Board

```bash
# Get the repo URL
REPO_URL="https://github.com/Nova-Digital-Solutions/PROJECT_NAME"

# The board is project #1 in the org
# Note: repos aren't "added" to boards — issues from any org repo can be added.
# But you can set a default project for the repo's issues:
gh api repos/$REPO/properties/values \
  -X PATCH \
  --input - <<'EOF'
{
  "properties": []
}
EOF
```

The board auto-includes issues when they're added via `gh project item-add`.

## 8. External Integrations

These are set up manually in the GitHub UI or respective service dashboards:

### Vercel (for frontend projects)

1. Go to vercel.com → Import Project → Select the repo
2. Set Framework Preset and Root Directory
3. Add environment variables
4. Enable Preview Deployments for PRs

### CodeRabbit (AI code review)

1. Install CodeRabbit GitHub App on the repo
2. It auto-reviews PRs once installed
3. Configure via `.coderabbit.yaml` if needed

### Slack Notifications

1. In Slack: `/github subscribe Nova-Digital-Solutions/PROJECT_NAME`
2. Configure: `/github subscribe Nova-Digital-Solutions/PROJECT_NAME issues pulls commits reviews`
3. Set channel to the project's dedicated Slack channel

## 9. README Template

Every repo should have a README with at minimum:

```markdown
# Project Name

Brief description.

## Setup

1. Clone the repo
2. Install dependencies: `pnpm install`
3. Copy env: `cp .env.example .env.local`
4. Run dev server: `pnpm dev`

## Architecture

Brief overview of the tech stack and project structure.

## Deployment

How deployments work (Vercel, manual, etc.)
```

## Checklist

Use this when setting up a new repo:

- [ ] Repository created (private, under Nova-Digital-Solutions org)
- [ ] Dev branch created and pushed
- [ ] Team access configured
- [ ] Default labels cleaned up, `blocked` label created
- [ ] Squash merge enabled, branch auto-delete enabled
- [ ] Main branch protection (PR + 1 review)
- [ ] Dev branch protection (PR required, self-merge OK)
- [ ] Added to Nova Work Board
- [ ] Vercel linked (if frontend)
- [ ] CodeRabbit installed
- [ ] Slack channel subscribed
- [ ] README created
- [ ] `.env.example` created
