# Hotfix Playbook

Hotfixes are emergency fixes applied directly to production (upstream/main) outside the normal weekly release cycle.

## Before Starting Any Hotfix

1. **Communicate** — Post in the team channel: what's broken, severity, who's working on it.
2. **Assess severity** — Is this truly urgent? Can it wait for the next release?
3. **Decide the scenario** — Does the fix already exist in staging?

## Decision Tree

```
Production bug reported
        │
        ▼
Is this critical enough for a hotfix?
        │
   ┌────┴────┐
   NO        YES
   │         │
   Fix in    Does the fix already
   dev,      exist in staging?
   normal    │
   release   ├── YES → Scenario A
             └── NO  → Scenario B
```

---

## Scenario A: Fix Already Exists in Staging

The bug has already been fixed in dev/staging but hasn't reached production yet. Use the cherry-pick GitHub Action.

### Steps

1. **Find the commit SHA** of the fix in staging:
   ```bash
   git log origin/staging --oneline --grep="fix:" | head -20
   ```
   Or search by file:
   ```bash
   git log origin/staging --oneline -- path/to/fixed/file.ts
   ```

2. **Go to the fork repo on GitHub:**
   - Navigate to: Actions → "Hotfix to Upstream"
   - Click "Run workflow"

3. **Fill in the workflow inputs:**
   - **Commit SHA**: The SHA from step 1 (e.g., `abc1234`)
   - **Branch name**: A descriptive name (e.g., `hotfix/fix-login-crash`)
   - **Description**: Brief explanation of the fix

4. **What the action does:**
   - Creates a new branch off `upstream/main`
   - Cherry-picks the specified commit onto that branch
   - Pushes the branch to the fork
   - Opens a PR from that branch to `upstream/main`
   - Assigns the upstream admin for review

5. **After the PR is merged:**
   - Verify the fix is live on production
   - Sync the fork to keep branches aligned:
     ```bash
     bash scripts/sync_fork.sh
     ```
     Or wait for the daily auto-sync at 7 AM WAT.

### If Cherry-Pick Fails

The action will fail if the cherry-pick has conflicts. Fall back to Scenario B — apply the fix manually on a branch off `upstream/main`.

---

## Scenario B: New Fix Needed

The fix doesn't exist yet. Write it directly on a branch off `upstream/main`.

### Steps

1. **Fetch upstream and create the hotfix branch:**
   ```bash
   git fetch upstream
   git checkout -b hotfix/description upstream/main
   ```

   **CRITICAL**: Branch off `upstream/main`, NOT `dev` or `staging`. Hotfix branches based on dev will include unrelated changes.

2. **Write and test the fix:**
   - Keep the fix minimal — only change what's necessary
   - Test locally against the production Convex backend if possible
   - Run lint and typecheck:
     ```bash
     npm run lint
     npm run typecheck
     ```

3. **Commit with conventional format:**
   ```bash
   git add .
   git commit -m "fix: description of the fix (#ISSUE)"
   ```

4. **Push the hotfix branch:**
   ```bash
   git push origin hotfix/description
   ```

5. **Create a PR to upstream/main:**
   ```bash
   gh pr create \
     --repo <client-org>/<project> \
     --base main \
     --head nova-digital-solutions:hotfix/description \
     --title "fix: description" \
     --body "## Hotfix

   **Problem:** Describe what's broken in production.

   **Fix:** Describe what this change does.

   **Testing:** How was this verified?

   **Severity:** Critical / High / Medium"
   ```

6. **Request review from upstream admin** — they must approve before merge.

7. **After the PR is merged:**
   - Verify the fix is live on production
   - Sync the fix back to staging and dev:
     ```bash
     bash scripts/sync_fork.sh
     ```
   - If auto-sync has conflicts, manually cherry-pick the fix into staging and dev:
     ```bash
     git checkout staging
     git cherry-pick <hotfix-commit-sha>
     git push origin staging

     git checkout dev
     git cherry-pick <hotfix-commit-sha>
     git push origin dev
     ```

---

## Post-Hotfix Checklist

- [ ] Fix is verified on production
- [ ] Fork is synced (upstream/main → staging → dev)
- [ ] Hotfix branch is deleted:
  ```bash
  git branch -d hotfix/description
  git push origin --delete hotfix/description
  ```
- [ ] Team channel is updated with resolution
- [ ] Related GitHub issue is closed
- [ ] If the bug exposed a gap, create a follow-up issue for better test coverage

## Common Mistakes

### Branching off dev instead of upstream/main
**Problem:** The hotfix branch includes all unreviewed dev changes.
**Fix:** Always `git checkout -b hotfix/x upstream/main`.

### Forgetting to sync back
**Problem:** The fix is in production but not in staging/dev. Next release PR may have conflicts, or the fix may be "undone" by staging code.
**Fix:** Always run `scripts/sync_fork.sh` after a hotfix merge.

### Not deleting the hotfix branch
**Problem:** Stale branches clutter the repo.
**Fix:** Delete after merge. Both locally and on origin.

### Hotfixing a non-critical bug
**Problem:** Hotfixes bypass the normal review cycle and add risk.
**Fix:** If it can wait until Tuesday, let it ride the normal release.
