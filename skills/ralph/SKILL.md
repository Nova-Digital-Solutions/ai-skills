---
name: ralph
description: "Convert PRDs to prd.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json."
---

# Ralph PRD Converter

Converts existing PRDs to the prd.json format that Ralph uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to `prd.json` in your ralph directory.

---

## Output Format

```json
{
 "project": "[Project Name]",
 "branchName": "ralph/[feature-name-kebab-case]",
 "description": "[Feature description from PRD title/intro]",
 "userStories": [
 {
 "id": "US-001",
 "title": "[Story title]",
 "description": "As a [user], I want [feature] so that [benefit]",
 "acceptanceCriteria": [
 "Criterion 1",
 "Criterion 2",
 "Typecheck passes"
 ],
 "priority": 1,
 "passes": false,
 "notes": ""
 }
 ]
}
```

---

## Story Size: Finding the Right Balance

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Amp instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### The Goldilocks Principle

Stories should be **small enough** to complete in one iteration, but **large enough** to represent meaningful progress. Overly granular stories create excessive overhead (reading context, verifying, committing) that slows down the overall build.

### Group related operations together:

**Database schema for a module → ONE story**
```
❌ Too granular:
- US-001: Add users table
- US-002: Add posts table
- US-003: Add comments table

✅ Better:
- US-001: Add database schema for blog module (users, posts, comments tables with indexes)
```

**CRUD operations for an entity → ONE story**
```
❌ Too granular:
- US-010: Create listPosts query
- US-011: Create getPost query
- US-012: Create createPost mutation
- US-013: Create updatePost mutation
- US-014: Create deletePost mutation

✅ Better:
- US-010: Create posts CRUD operations (list, get, create, update, delete)
```

**Related UI components → ONE story**
```
❌ Too granular:
- US-020: Add progress bar to list view
- US-021: Add progress bar to detail view
- US-022: Add status dropdown to detail view

✅ Better:
- US-020: Add progress display and status controls to work item views
```

### Right-sized stories:
- Create all database tables for a module (schema story)
- Create all CRUD operations for an entity (backend story)
- Build a complete page with its core functionality
- Add a feature with 2-4 related UI changes
- Implement a form with validation and submission

### Too big (still split these):
- "Build the entire dashboard" - Split into: schema, backend CRUD, list page, detail page, filters
- "Add authentication" - Split into: schema + auth config, auth pages, protected routes
- "Build full CRUD UI" - Split into: backend operations, list view, create/edit form, detail view

### Too small (combine these):
- Individual database table additions (combine into one schema story)
- Individual query/mutation per story (combine into CRUD story)
- Minor UI tweaks that are part of the same feature

**Rule of thumb:** 
- If you cannot describe the change in 2-3 sentences, it is too big.
- If the story only touches one function/file with trivial changes, it is too small - combine with related work.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

### Always include as final criterion:
```
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

### For stories that change UI, also include:
```
"Verify in browser using dev-browser skill"
```

Frontend stories are NOT complete until visually verified. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false` and empty `notes`
5. **branchName**: Derive from feature name, kebab-case, prefixed with `ralph/`
6. **Always add**: "Typecheck passes" to every story's acceptance criteria

---

## Splitting Large PRDs

If a PRD has big features, split them into meaningful chunks - but don't over-split:

**Original:**
> "Add user notification system"

**Split into (good balance):**
1. US-001: Add notifications schema and backend operations (table, CRUD queries/mutations)
2. US-002: Create notification UI components (bell icon, dropdown panel, notification items)
3. US-003: Add mark-as-read and notification preferences

**Over-split (avoid this):**
1. US-001: Add notifications table ← too small
2. US-002: Create listNotifications query ← too small
3. US-003: Create getNotification query ← too small
4. US-004: Create createNotification mutation ← too small
5. US-005: Add notification bell icon ← too small
6. US-006: Create dropdown panel ← combine with #5
7. US-007: Add mark-as-read mutation ← too small
8. US-008: Add notification preferences page

**The overhead of each iteration (context loading, verification, commits) adds up. 
3 well-scoped stories will complete faster than 8 tiny ones.**

---

## Example

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output prd.json (well-balanced):**
```json
{
 "project": "TaskApp",
 "branchName": "ralph/task-status",
 "description": "Task Status Feature - Track task progress with status indicators",
 "userStories": [
 {
 "id": "US-001",
 "title": "Add status field and update query",
 "description": "As a developer, I need status tracking in the database.",
 "acceptanceCriteria": [
 "Add status column to tasks: 'pending' | 'in_progress' | 'done' (default 'pending')",
 "Add index on status field",
 "Create updateTaskStatus mutation that validates status values",
 "Update listTasks query to accept optional status filter parameter",
 "Typecheck passes"
 ],
 "priority": 1,
 "passes": false,
 "notes": "Schema + backend in one story since they're tightly coupled"
 },
 {
 "id": "US-002",
 "title": "Add status UI to task list",
 "description": "As a user, I want to see and change task status in the list.",
 "acceptanceCriteria": [
 "Each task row shows colored status badge (gray=pending, blue=in_progress, green=done)",
 "Each row has status dropdown that saves immediately via updateTaskStatus",
 "Add filter dropdown to page header: All | Pending | In Progress | Done",
 "Filter updates the task list via listTasks query",
 "Filter persists in URL params",
 "Typecheck passes",
 "Verify in browser using dev-browser skill"
 ],
 "priority": 2,
 "passes": false,
 "notes": "All status UI in one story - badge, toggle, and filter are related"
 }
 ]
}
```

**Note:** This is 2 stories instead of 4. The first handles all backend work, the second handles all UI work. 
Each story is still completable in one iteration, but we avoid the overhead of 4 separate iterations for tightly related changes.

---

## Archiving Previous Runs

**Before writing a new prd.json, check if there is an existing one from a different feature:**

1. Read the current `prd.json` if it exists
2. Check if `branchName` differs from the new feature's branch name
3. If different AND `progress.txt` has content beyond the header:
 - Create archive folder: `archive/YYYY-MM-DD-feature-name/`
 - Copy current `prd.json` and `progress.txt` to archive
 - Reset `progress.txt` with fresh header

**The ralph.sh script handles this automatically** when you run it, but if you are manually updating prd.json between runs, archive first.

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] **Previous run archived** (if prd.json exists with different branchName, archive it first)
- [ ] Each story is completable in one iteration (small enough)
- [ ] **Stories aren't over-granular** (combine related schema changes, CRUD operations, and UI components)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] **Design foundation story included** (see below)

### Quick Granularity Check
Count your stories and ask: "Could I combine any adjacent stories that touch the same feature area?"
- Multiple schema stories for one module → combine into one
- Multiple query/mutation stories for one entity → combine into CRUD story
- Multiple small UI tweaks for same page → combine into one UI story

---

## Design-Aware PRDs (IMPORTANT)

Generic user stories produce generic UIs. Include design guidance to avoid "AI slop."

### Include a Design Foundation Story Early

For any PRD with UI work, add a story like this around priority 15-20:

```json
{
  "id": "US-DESIGN-001",
  "title": "Create custom design system foundation",
  "description": "As a user, I need a distinctive, polished interface.",
  "acceptanceCriteria": [
    "Configure custom Google Fonts in app/layout.tsx using next/font/google",
    "Use distinctive display font (Outfit, Figtree, or Sora) for headings",
    "Use refined body font (DM Sans or Plus Jakarta Sans)",
    "Create custom color palette in globals.css - NOT stock ShadCN blue",
    "Primary color reflects app purpose (not generic blue)",
    "Define sidebar-specific dark theme colors",
    "Add custom shadows and animations to tailwind.config.ts",
    "Body element has antialiased class",
    "Typecheck passes"
  ],
  "priority": 15,
  "passes": false,
  "notes": "DESIGN: Visual foundation for all UI work"
}
```

### Write Design-Outcome Criteria (Not Implementation Details)

**Avoid:**
```
"Sidebar has bg-muted/40 background"  ← stock default
"Header has h-14 (56px) height"       ← arbitrary pixels
```

**Instead:**
```
"Sidebar uses dark theme that contrasts with content"
"Sidebar uses custom sidebar color variables"  
"Header has backdrop blur effect"
"Navigation items have hover transitions"
```

### Add a Polish Story

Near the end of UI-heavy PRDs, include:

```json
{
  "id": "US-POLISH-001",
  "title": "Add micro-interactions and animations",
  "acceptanceCriteria": [
    "Page content fades in on load",
    "Navigation items have hover transforms",
    "Active states have smooth transitions",
    "Tooltips on collapsed sidebar items",
    "Toast notifications properly positioned and styled",
    "Typecheck passes",
    "Verify in browser using dev-browser skill"
  ],
  "priority": 50,
  "passes": false,
  "notes": "DESIGN: Polish pass after core functionality"
}
```

### Design Quick Check

Before saving prd.json for UI-heavy features:
- [ ] Has design foundation story (fonts, colors, shadows)?
- [ ] Sidebar/header stories mention theming, not just dimensions?
- [ ] At least one polish/animation story?
- [ ] Acceptance criteria describe outcomes, not stock defaults?
