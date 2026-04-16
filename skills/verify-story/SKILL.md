---
name: verify-story
description: Verify that a user story's acceptance criteria are met before committing. Use this skill after implementing a story and staging changes with `git add -A`, but before committing. Checks each acceptance criterion against the staged diff and codebase using code inspection only — no running servers required. Returns a per-AC verdict (pass/fail/uncertain) and blocks the commit on any failure. Always invoke this in any autonomous development loop before marking a story complete or running git commit.
allowed-tools: Bash, Grep, Glob, Read
---

# Verify Story

You are a meticulous code reviewer checking whether a just-implemented user story actually satisfies each of its acceptance criteria — before any code is committed.

This is a **blocking gate**. If any criteria fail, the implementation must be fixed and this skill re-run before proceeding to commit.

## What you need

The story's acceptance criteria should already be in your context (from the story prompt or recent conversation). If they aren't visible, ask for them before proceeding.

## Process

### Step 1: Get the staged diff

```bash
git diff --cached
git diff --cached --stat
```

If the diff is empty, the changes may not be staged. Check the working tree instead:

```bash
git diff
git diff --stat
```

Read the diff carefully before evaluating any criteria. Understanding *what actually changed* is the foundation of every check.

### Step 2: Classify each acceptance criterion

For each AC, decide what kind of evidence would confirm it's implemented. The goal is to match intent — not just pattern-match on keywords.

| AC type | Evidence to look for |
|---|---|
| UI element (button, badge, skeleton, icon) | Component name or relevant class in diff |
| Navigation / routing | `href`, `router.push`, `Link`, `redirect`, `useRouter` |
| Toast / notification | `toast(` call in the relevant action handler |
| Confirmation / dialog | `AlertDialog`, `Dialog`, `confirm(`, modal component |
| Activity / audit log | Logging mutation called in the handler |
| Backend function (query / mutation / action) | Function definition or invocation in diff |
| Loading / skeleton state | Conditional render checking a loading flag |
| Keyboard shortcut | `onKeyDown`, `useEffect` with key listener, `e.key` |
| Form validation / disabled state | Disabled prop, required check, error condition |
| Styling / layout | Class names, CSS values, responsive variants |
| Config / seed data | Key name or value present in config or seed files |
| Real-time / reactive behavior | State updates, subscriptions, event handlers |
| Error handling | Try/catch, error state, error toast, guard clause |

### Step 3: Search for evidence

For each criterion, look in this order:

1. **Scan the staged diff first** — the diff shows exactly what changed. If the criterion is addressed there, that's your evidence.
2. **Grep specific changed files** if the diff is large and you need to narrow down:
   ```bash
   grep -n "pattern" path/to/changed/file.tsx
   ```
3. **Check pre-existing code** — if the criterion was already implemented before this story, it still counts. Look in the relevant files using Grep or Read.

**Be generous but honest.** If the code clearly implements the *intent* of the criterion, that's a pass — even if the exact implementation pattern differs from what you'd expect. Don't fail an AC because the variable name doesn't match your guess. Fail it only when the behavior genuinely isn't there.

### Step 4: Output the verdict

```
## Story Verification: [Story ID] — [Story Title]

### Acceptance Criteria

1. ✅ [AC text]
   Evidence: `src/components/DocumentCard.tsx:38` — conditional `{isLoading && <Skeleton />}` renders skeleton on loading state

2. ❌ [AC text]
   Missing: No `toast(` call found in the save handler. The `handleSave` function returns after mutation but does not notify the user.

3. ⚠️ [AC text]
   Uncertain: Requires interactive validation (e.g., real-time preview, keyboard event). Code structure looks correct — `onKeyDown` handler at line 87 handles `Cmd+S` — but runtime behavior cannot be confirmed by code inspection alone.

---

### Summary
- ✅ Passed: N
- ❌ Failed: N
- ⚠️ Uncertain: N

**Verdict: PASS / FAIL**
```

**Verdict rules:**
- **PASS** — all criteria are ✅ or ⚠️. Safe to commit.
- **FAIL** — one or more criteria are ❌. Fix the failures, re-stage with `git add -A`, and re-run this skill before committing.

⚠️ Uncertain criteria are **non-blocking**. They represent interactive or behavioral things that can't be confirmed by reading code. After committing, note them in the progress log so they can be manually validated.

## After a FAIL

Fix the specific gaps identified in the ❌ criteria, then:

1. `git add -A`
2. Re-run this skill
3. Only commit once the verdict is **PASS**

Do not mark the story complete in `prd.json` until the verdict is PASS.
