---
name: prd
description: "Generate a comprehensive Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
---

# PRD Generator (Comprehensive Edition)

Create detailed, implementation-ready Product Requirements Documents that leave no gaps for autonomous agents or junior developers.

---

## The Job

1. Receive a feature description from the user
2. Run through the **Entity Discovery** phase (Phase 1)
3. Run through the **Interaction Completeness** phase (Phase 2) — CRUD for every entity
4. Run through the **Cross-PRD & External Dependencies** phase (Phase 2.5) — fallbacks, data shape alignment, testability
5. Run through the **Interaction Appropriateness** phase (Phase 3) — right component for the task?
6. Run through the **UI States & Patterns** phase (Phase 4)
7. Generate a structured PRD with complete user stories (Phase 5)
8. Save to the appropriate PRD file for your project structure

**Important:** Do NOT start implementing. Just create the PRD.

---

## PRD Types: Feature PRDs vs Change PRDs

Before creating a PRD, determine which type you need:

### Feature PRDs (New Features)
- Full, comprehensive PRDs using the phases below
- Represent the **source of truth** for what exists in the system after implementation
- Stored in your project's PRD directory (e.g., `docs/prds/`, `PRDs/`, etc.)
- Never track historical changes — just current reality

**Use this skill for Feature PRDs.**

### Change PRDs (Improvements to Existing Features)
- Lightweight PRDs for modifications to features that already have a Feature PRD
- Temporary documents that define a specific change or improvement
- After implementation, the parent Feature PRD is updated to reflect the change, and the Change PRD is archived or deleted

**Change PRD Template (use this instead of full phases):**

```markdown
# CHANGE: [Brief Description]

**Parent PRD:** [parent PRD filename]
**Status:** Pending | In Progress | Complete

## Problem
What's wrong or could be better?

## Proposed Change
What specifically should change?

## Affected User Stories
Which existing user stories are modified? List by ID (e.g., US-010, US-015)

## New User Stories (if any)
### US-NEW-001: [Story title]
**As a** [user type]
**I want to** [action]
**So that** [benefit]

**Trigger:** [How user initiates]
**Flow:** [Steps]
**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

## Acceptance Criteria
- [ ] Specific thing 1
- [ ] Specific thing 2

## Notes
Any implementation context for the agent
```

**Key insight:** Change PRDs are **ephemeral work tickets**, not permanent documentation. Feature PRDs are the permanent record.

---

## Phase 1: Entity Discovery

Before writing anything, identify ALL entities in the feature. An entity is anything that:
- Can be created, viewed, edited, or deleted
- Has its own data/attributes
- Appears in a list or detail view

### Ask the User:

```
ENTITY DISCOVERY

Based on your description, I've identified these entities:
1. [Entity A] - [brief description]
2. [Entity B] - [brief description]
3. [Entity C] - [brief description]

For each entity, please confirm or adjust:

A. Is this list complete? What entities am I missing?

B. For each entity, what are the key attributes/fields?
   (I'll suggest defaults, you can adjust)

C. Are there any hierarchies?
   - Does [Entity A] contain [Entity B]? (e.g., Work Items contain Tasks)
   - Can [Entity B] have children? (e.g., Tasks have Subtasks?)
   - How deep can nesting go?
```

---

## Phase 2: Interaction Completeness (CRUD+)

For EACH entity identified, systematically ask about operations:

### Ask the User:

```
OPERATIONS FOR: [Entity Name]

Which operations should users be able to perform?

CREATE:
 A. How is it created?
    1. Modal/dialog
    2. Inline (add row in table)
    3. Dedicated page
    4. Quick-add (minimal fields) + full form
 B. Required fields vs optional?
 C. Any wizard/multi-step flow?

READ:
 A. List view needed? 
    1. Table
    2. Cards/grid
    3. Both (toggle)
 B. Detail view needed?
    1. Full page
    2. Slide-over panel
    3. Modal
    4. Expandable row
 C. What fields shown in list vs detail?

UPDATE:
 A. How is it edited?
    1. Same modal as create
    2. Inline editing (click to edit)
    3. Dedicated edit page
    4. Edit panel/drawer
 B. Which fields are editable after creation?
 C. Any fields that lock after certain conditions?

DELETE:
 A. Delete allowed?
 B. Confirmation required?
 C. What happens to children/related items?
 D. Soft delete (archive) or hard delete?

ADDITIONAL OPERATIONS:
 - [ ] Reorder/drag-drop
 - [ ] Duplicate/copy
 - [ ] Archive/restore
 - [ ] Share with others
 - [ ] Export (CSV, PDF)
 - [ ] Bulk select + bulk actions
 - [ ] Search within list
 - [ ] Filter by attributes
 - [ ] Sort by columns
```

Repeat this for EVERY entity. Do not skip entities that are "contained within" others - those especially need explicit CRUD stories.

---

## Phase 2.5: Cross-PRD & External Dependencies

After the data model and operations are defined, check for any integration points with other PRDs or external systems. This is the right time — you now know what entities and fields exist.

For each dependency identified:

**A. Fallback behavior** — What happens when the dependency isn't built yet?
- Is the dependent UI element hidden, disabled, or replaced with a placeholder?
- Is this specified in the affected user stories?

**B. Data shape alignment** — Does the data model produce the shape each consuming component expects?
- If a component takes `(oldContent: string, newContent: string)`, don't store a pre-computed diff — store both sides
- If a selector expects `{ id, label }[]`, don't return raw DB records
- Mismatches here cause silent bugs or dead code; catch them at design time

**C. Testability** — Can each workflow group be exercised without the dependency?
- If not, add a dev note to the affected user stories explaining how to seed test data
- Don't leave "this feature will be tested when PRD-X is built" implicit

---

## Phase 3: Interaction Appropriateness

After identifying WHAT operations exist, consider WHETHER the interaction pattern matches the task. This prevents "technically complete but feels basic" implementations.

### The Core Question

For each input, control, or action, ask: 
"Given how users will actually use this, is this the right type of component?"

### Common Decision Points

Don't exhaustively answer all of these - just the ones relevant to your feature:

**Selection & Search:**
- Single item: Simple dropdown, or needs search/filtering for long lists?
- Multiple items: Checkboxes, or additive chips that stay visible?
- Entity references (contacts, tags, etc.): Plain text, or select-and-add?
- Search: Text filtering, or structured/faceted search with multiple dimensions?

**Temporal Inputs:**
- Single date: Picker sufficient, or needs time component?
- Date range: Two pickers, or unified range selector?
- Relative dates: Specific dates, or "last 7 days" / "this quarter" options?
- Recurring: Simple interval, or complex scheduling (2nd Tuesday of month)?

**Text & Content:**
- Length: Single line, textarea, or auto-growing?
- Formatting: Plain text, markdown, or rich text editor?
- Suggestions: Free-form, or offer autocomplete/templates?

**State & Status:**
- Binary state: Checkbox, toggle, or button?
- Multiple states: Dropdown, radio buttons, or segmented control?
- Workflow states: Linear progression indicator, or freeform selection?

**Display & Layout:**
- List of items: Table (data-heavy), cards (visual), list (compact), or user choice?
- Hierarchical data: Flat list, nested/tree, or grouped with headers?
- Comparisons: Side-by-side, or overlay/diff view?

**Actions & Placement:**
- Primary action: Prominent position (top-right, or bottom-right of forms)?
- Secondary actions: Grouped with primary, or separated?
- Destructive actions: Requires deliberate access (menu, confirmation)?
- Contextual actions: Inline with items, or in a toolbar/header?

**Feedback & Confirmation:**
- Success: Toast (ephemeral), inline (persistent), or redirect?
- Errors: Inline per-field, summary at top, or modal?
- Confirmations: Modal dialog, inline expand, or undo-based (act then offer undo)?

### How to Use This

Pick 2-3 decision points most relevant to your feature. For each:
1. State the current assumption (or lack thereof)
2. Consider alternatives
3. Document the choice in the PRD

Example:
> **Contact assignment in ticket**: Using additive chip selector. User types to search, 
> clicks contact to add as chip. Multiple contacts supported. Chips removable via X. 
> Why: Users often assign to multiple contacts; seeing who's already assigned matters.

This prevents an agent from implementing a plain text input where a smart selector would be expected.

---

## Phase 4: UI States & Patterns

### Ask the User:

```
UI STATES & PATTERNS

EMPTY STATES:
For each list/collection, what should empty state show?
 A. [Entity A] empty state message?
 B. [Entity B] empty state message?
 C. Include call-to-action button in empty state?

LOADING STATES:
 A. Show skeleton loaders? Spinners? Both?
 B. Any optimistic updates (show before server confirms)?

ERROR HANDLING:
 A. Form validation - inline or on submit?
 B. Error messages for failed operations?
 C. Retry options for network failures?

SUCCESS FEEDBACK:
 A. Toast notifications for actions?
 B. Inline success messages?
 C. Redirect after create/delete?

CONFIRMATION PATTERNS:
 A. Which destructive actions need confirmation?
 B. Confirmation style: modal dialog or inline?

KEYBOARD & ACCESSIBILITY:
 A. Any keyboard shortcuts needed?
 B. Tab order considerations?

VIEWPORT & SCROLL BEHAVIOR:

Think through each page from the user's perspective: "While I'm scrolling 
through content, what do I need to always see or access?"

Typically STICKY (user needs constant access):
- Navigation: Can user always get back/navigate elsewhere?
- Context: Does user always know what they're looking at? (title, breadcrumbs, selected item)
- Primary actions: Submit buttons, "Add New", key CTAs - will they scroll out of view?
- Filters/search: If user scrolls a long list, can they still filter?

Typically SCROLLS (the actual content):
- List items, table rows, conversation threads
- Form fields (but NOT the submit button)
- Detail content, activity history
- Secondary metadata

For SPLIT VIEWS (sidebar + main content, or list + detail):
- Each panel usually scrolls independently
- User shouldn't lose the sidebar when scrolling main content
- User shouldn't lose the list when scrolling detail

Ask: "If this page has 100+ items or a long form, what breaks?"
```

---

## Phase 5: Generate the PRD

Using all gathered information, generate a PRD with these sections:

### 1. Overview
Brief description of the feature and problem it solves.

### 2. Entities
List all entities with their attributes. Use TypeScript interfaces.

### 3. User Stories (COMPREHENSIVE)

**Critical:** Generate user stories for EVERY operation on EVERY entity.

For each entity, you MUST have stories for:
- Viewing the list (if applicable)
- Viewing detail (if applicable)
- Creating new
- Editing existing
- Deleting
- Any additional operations identified

**Story ID numbering:** Continue from the highest existing `US-XXX` number in the project's PRDs. If this is the first PRD, start at `US-001`. Never reuse an ID — even if a story is deleted, its number is retired.

**Format:**
```markdown
### US-XXX: [Verb] [Entity]
**As a** [user type]
**I want to** [action]
**So that** [benefit]

**Trigger:** [How does user initiate this? Button click? Menu item?]

**Flow:**
1. User clicks [button/link]
2. [Modal opens / Page navigates / Panel slides in]
3. User enters [fields]
4. User clicks [save/confirm]
5. [What happens on success]
6. [What happens on error]

**Acceptance Criteria:**
- [ ] [Specific, verifiable criterion]
- [ ] [Another criterion]
- [ ] Empty state shows "[message]" with [CTA button] when no items exist
- [ ] Loading state shows [skeleton/spinner] while fetching
- [ ] Error state shows [message] with retry option
- [ ] Success shows [toast/redirect/inline message]
```

### 4. UI Specifications

For each screen/view, specify:
- Layout (sidebar? header? tabs?)
- Components to use (table, cards, modal, etc.)
- Responsive behavior
- Empty, loading, error states

### 5. Functional Requirements
Numbered list of specific functionalities (FR-001, FR-002, etc.)

### 6. Backend API / Functions
Backend functions, mutations, queries, or endpoints needed for each operation. Use the terminology and style of your project's backend (REST endpoints, Convex functions, GraphQL mutations, tRPC procedures, etc.).

### 7. Data Models
Data model definitions for all entities, using the project's language and conventions (TypeScript interfaces, Python dataclasses, Go structs, DB schema, etc.).

### 8. Non-Goals (Out of Scope)
What this feature will NOT include.

### 9. Success Metrics
How will success be measured?

### 10. Open Questions
Remaining questions or areas needing clarification.

### 11. Implementation Notes
Edge cases, algorithmic decisions, failure contracts, and cross-PRD wiring details.

### 12. Package Dependencies
Every npm/pip/etc. package introduced by this PRD (not already in the project).

```markdown
| Package | Purpose |
|---------|---------|
| `package-name` | What it's used for |
```

If no new packages are needed, write: "No new package dependencies."

---

## Example: Complete Task Coverage

If you have a "Tasks" entity within "Work Items", you need ALL of these stories:

```markdown
### US-010: View Tasks in Work Item
**Trigger:** User navigates to Tasks tab in work item detail

### US-011: Add Task to Work Item
**Trigger:** User clicks "Add Task" button in Tasks tab
**Flow:**
1. User clicks "Add Task" button (visible at top of task list OR in empty state)
2. Inline row appears OR modal opens (specify which!)
3. User enters task name (required), assignee (optional), due date (optional)
4. User presses Enter or clicks Save
5. Task appears in list, sorted by [creation order/due date/etc.]

### US-012: Edit Task
**Trigger:** User clicks task name OR clicks edit icon OR double-clicks row
**Flow:** [Full flow specification]

### US-013: Complete Task
**Trigger:** User clicks checkbox next to task
**Flow:**
1. Checkbox shows pending state
2. Task status updates to "Completed"
3. Task moves to [bottom of list / completed section / stays in place with strikethrough]
4. Work item progress percentage updates

### US-014: Delete Task
**Trigger:** User clicks delete icon (appears on hover) OR selects from menu
**Flow:**
1. Confirmation dialog appears: "Delete this task?"
2. User clicks "Delete"
3. Task removed from list
4. Toast shows "Task deleted" with Undo option (if applicable)

### US-015: Reorder Tasks
**Trigger:** User drags task to new position
**Flow:** [Full specification]

### US-016: View Empty Task State
**Acceptance Criteria:**
- [ ] When no tasks exist, shows "No tasks yet"
- [ ] Shows "Add your first task" button
- [ ] Clicking button triggers US-011 flow
```

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** Your project's PRD directory (e.g., `docs/prds/`, `PRDs/`, `specs/`)
- **Filename:** `prd-[feature-name].md` (kebab-case)

---

## Final Checklist

Before saving the PRD:

- [ ] All entities identified and documented
- [ ] Every entity has complete CRUD stories (where applicable)
- [ ] Every story has trigger, flow, and acceptance criteria
- [ ] Empty states specified for all lists
- [ ] Loading states specified
- [ ] Error handling specified
- [ ] Confirmation dialogs specified for destructive actions
- [ ] Relationships and hierarchies documented
- [ ] No implicit assumptions - everything is explicit
- [ ] Scroll behavior specified for each page (sticky elements, scroll containers)
- [ ] Every query/list sorted or filtered by a custom field has a database index defined
- [ ] Overview claims don't contradict non-goals or deferral notes
- [ ] All npm/package dependencies listed in Section 12
- [ ] Every workflow group is testable in this PRD alone, or has a dev note about seeding
- [ ] Cross-PRD dependencies have explicit fallback behavior defined
- [ ] Component prop interfaces align with the data model shapes that feed them *(only check this if the PRD defines shared component interfaces)*
