# Release Calendar — Weekly Cycle

## Weekly Schedule

### Monday — Feature Freeze

**What's allowed:**
- Bug fixes to staging (via PR from dev)
- Documentation updates
- Test improvements
- QA testing on staging environment

**What's NOT allowed:**
- New feature PRs to staging
- Refactors that change behavior
- Dependency upgrades (unless fixing a security vulnerability)

**Why:** Monday is for stabilizing staging before Tuesday's release PR. New features risk introducing bugs that won't be caught before the release.

### Tuesday — Release PR Creation

**9 AM WAT:** GitHub Action "Weekly Release to Upstream" runs automatically.

**What the action does:**
1. Compares `fork/staging` to `upstream/main`
2. If there are new commits, creates a PR with a generated changelog
3. The changelog groups commits by type (feat, fix, chore, etc.)
4. PR is created in the upstream repo, targeting `main`

**If nothing new:** The action detects no diff and does NOT create a PR. No action needed.

**PR format:**
```
Title: Release YYYY-MM-DD

Body:
## Changelog

### Features
- feat: add user dashboard (#42)
- feat: implement search (#45)

### Bug Fixes
- fix: correct date parsing (#48)

### Other
- chore: update dependencies (#50)

---
Full diff: <compare URL>
Commits: N
```

**After PR creation:**
- Upstream admin is notified (auto-assigned via GitHub)
- Admin reviews the changelog and diff
- Admin may request changes or ask questions

### Wednesday — Merge and Deploy

**Upstream admin merges the release PR.**

After merge:
1. Vercel detects the push to `main` and auto-deploys to production
2. Verify the production deployment:
   - Check the production URL
   - Run smoke tests if available
   - Monitor error tracking (Sentry, etc.)
3. The daily sync (or manual `sync_fork.sh`) will pull `main` back into staging and dev

**If issues are found post-deploy:**
- Assess severity
- If critical: initiate hotfix (see hotfix-playbook.md)
- If minor: fix in dev, include in next week's release

### Thursday — Normal Development

- Merge freely to staging via PRs from dev
- All types of changes welcome
- Focus on features for next week's release

### Friday — Normal Development

- Same as Thursday
- Consider what's in staging — is it release-ready?
- Friday afternoon: good time to review staging for completeness

## Manual Release Process

Sometimes a release is needed outside the Tuesday cycle. Common reasons:
- Urgent feature needed by client
- Multiple bug fixes accumulated and client needs them
- Coordinated release with external dependency

### Steps

1. **Communicate with the team** — announce in the team channel that a manual release is happening
2. **Verify staging is stable** — CI passing, no known issues
3. **Trigger the action:**
   - Go to fork repo → Actions → "Weekly Release to Upstream"
   - Click "Run workflow"
   - Select `staging` branch
   - Click "Run workflow"
4. **Notify the upstream admin** — they need to review and merge
5. **Verify after merge** — same as Wednesday verification

### When NOT to do a manual release

- Friday afternoon (nobody to fix issues over the weekend)
- When staging has untested changes
- Without informing the team
- When the upstream admin is unavailable

## Release Checklist

Before every release (automated or manual), verify:

- [ ] CI is passing on staging
- [ ] All PRs in staging have been reviewed
- [ ] No known bugs in staging that would affect production
- [ ] All linked issues are properly resolved
- [ ] Team is aware of the release
- [ ] Upstream admin is available for review (for manual releases)

## Skipped Releases

If there are no new commits in staging since the last release:
- The Tuesday action detects this and does NOT create a PR
- No action needed from anyone
- This is normal and expected during low-activity weeks

## Timezone Reference

All scheduled actions use **WAT (West Africa Time)**, UTC+1.

| Event | Time (WAT) | Time (UTC) |
|---|---|---|
| Daily fork sync | 7:00 AM | 6:00 AM |
| Tuesday release PR | 9:00 AM | 8:00 AM |
