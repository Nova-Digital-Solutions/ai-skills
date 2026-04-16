# Conflict Resolution Guide

## Rebase vs Merge — When to Use Each

### Rebase (Preferred for Feature Branches)

Use rebase when:
- Working on a feature branch that only you are working on
- You want a clean, linear history
- Your branch has a small number of commits

```bash
git checkout feature/my-thing
git fetch origin
git rebase origin/dev

# If conflicts occur, resolve each one:
# 1. Edit the conflicting files
# 2. git add <resolved-files>
# 3. git rebase --continue

# Force-push with lease (NEVER --force)
git push --force-with-lease origin feature/my-thing
```

**Why `--force-with-lease`?** It refuses to push if someone else has pushed to the branch since your last fetch. This prevents overwriting others' work. Never use `--force`.

**When NOT to rebase:**
- On shared branches (dev, staging, main) — NEVER rebase these
- When your branch has been reviewed and others have built on it
- When the branch has many commits and conflicts would be complex

### Merge (Preferred for Multi-Developer Branches)

Use merge when:
- Multiple developers are working on the same branch
- The branch has many commits
- You want to preserve the full history of parallel work

```bash
git checkout feature/big-thing
git fetch origin
git merge origin/dev

# Resolve conflicts, then:
git add .
git commit  # Creates a merge commit
git push origin feature/big-thing
```

### Summary

| Situation | Strategy |
|---|---|
| Solo feature branch, few commits | Rebase |
| Solo feature branch, many commits | Rebase or merge (judgment call) |
| Shared branch, multiple developers | Merge |
| dev, staging, main branches | Merge only (never rebase) |
| After code review, before merge to dev | Rebase to clean up (squash if needed) |

---

## Sync Conflict Resolution

When the daily auto-sync (7 AM WAT) encounters a conflict, it:
1. Aborts the merge
2. Creates a GitHub issue titled "Sync conflict: upstream/main → staging"
3. Tags the team for resolution

### How to Resolve Sync Conflicts

**Step 1: Identify the conflict**

Check the GitHub issue created by the action. It lists which files have conflicts.

```bash
git fetch upstream
git fetch origin
```

**Step 2: Resolve staging ← upstream/main**

```bash
git checkout staging
git pull origin staging
git merge upstream/main
```

Git will report conflicting files. For each file:

```bash
# Open the file, look for conflict markers:
# <<<<<<< HEAD
# (staging version)
# =======
# (upstream/main version)
# >>>>>>> upstream/main

# Resolve by keeping the correct version (or combining both)
# Remove the conflict markers
```

After resolving all conflicts:

```bash
git add .
git commit -m "chore: resolve sync conflict from upstream/main"
git push origin staging
```

**Step 3: Resolve dev ← staging**

```bash
git checkout dev
git pull origin dev
git merge staging
```

Same process — resolve conflicts, commit, push.

```bash
git add .
git commit -m "chore: resolve sync conflict from staging"
git push origin dev
```

**Step 4: Close the GitHub issue**

Add a comment explaining what was conflicting and how it was resolved. Close the issue.

### Common Causes of Sync Conflicts

| Cause | Prevention |
|---|---|
| Hotfix changed a file also modified in dev | Sync promptly after hotfixes |
| Config files edited in both repos | Coordinate config changes with upstream admin |
| Package lock file diverged | Regenerate: delete lock file, `npm install`, commit |
| Formatting differences | Ensure same Prettier/ESLint config in both repos |

### Why Prompt Resolution Matters

Sync conflicts compound. If Monday's sync conflict isn't resolved:
- Tuesday's release PR will have even more conflicts
- The automated release PR may fail to create
- Manual intervention becomes increasingly complex

**Rule of thumb:** Resolve sync conflicts within 4 hours of the issue being created.

---

## Package Lock Conflicts

`package-lock.json` (or `pnpm-lock.yaml`, `yarn.lock`) conflicts are common and annoying. The cleanest resolution:

```bash
# Accept the incoming version, regenerate the lock
git checkout --theirs package-lock.json
rm -rf node_modules
npm install
git add package-lock.json
```

Or if both sides added different packages:

```bash
# Accept either version, then install everything
git checkout --theirs package-lock.json
npm install
# Verify your packages are still present
npm ls <your-new-package>
git add package-lock.json
```

---

## Emergency: Stuck Merge State

If a merge goes wrong and you need to abort:

```bash
git merge --abort
```

If you've already committed a bad merge:

```bash
# Revert the merge commit (creates a new commit that undoes it)
git revert -m 1 <merge-commit-sha>
git push origin <branch>
```

Never use `git reset --hard` on shared branches. It rewrites history and will cause problems for everyone else.
