---
name: prd-review
description: "Review a PRD for completeness, identifying missing user stories, interaction gaps, and UI state coverage. Use when you have a PRD that needs quality review before implementation. Triggers on: review this prd, check prd completeness, prd review, audit this prd, is this prd complete."
---

# PRD Review Skill

Systematically analyze a PRD to identify gaps that would cause incomplete implementations when used by autonomous agents or junior developers.

---

## Critical Rules

### Severity Calibration — READ THIS FIRST

**You MUST apply these definitions strictly. Do NOT inflate severity.**

The primary consumer of these PRDs is an **AI coding agent** (not a human developer). AI agents implement exactly what is specified and skip or silently invent what isn't. Calibrate severity with that in mind.

**CRITICAL** — Will cause a bug, broken behavior, or silent misimplementation that an AI coding agent is unlikely to catch on its own. Examples:
- A user-facing entity is missing a CRUD operation that isn't listed in Non-Goals (agent won't build it)
- Two sections contradict each other (agent follows whichever it reads last)
- A required API operation has no specification (agent invents a signature or skips it)
- A data model is missing a field that user stories reference (agent creates a broken schema)
- A mutation's error handling or validation rule is unspecified (agent skips validation entirely)
- A status transition, lifecycle rule, or business constraint is ambiguous (agent picks one interpretation — possibly wrong)
- An acceptance criterion references behavior that isn't defined anywhere in the PRD (agent hallucinates the behavior)
- A cross-PRD contract is incomplete — the PRD says "use X from PRD-Y" but doesn't specify what to do if X doesn't exist yet (agent crashes or skips silently)

**MINOR** — An experienced human developer would figure it out, but an AI agent might not. The PRD should be explicit. Examples:
- Missing empty state text for a list view (agent may skip the empty state entirely or invent text)
- Loading state not specified (agent may not add one, or add an inconsistent one)
- A token budget isn't documented (agent won't add a guard)
- Scroll behavior unspecified for a page (agent defaults to browser default — probably fine, but may miss sticky headers)

**NOT A GAP** — Do not report these:
- Implementation details that any agent would handle correctly given the surrounding context (e.g., "the Convex query returns ascending by default which matches the FIFO intent described in the same section")
- Edge cases that are impossible or nearly impossible given the data model constraints
- Things that are clearly specified in one section and don't need restating in another
- Stylistic preferences about how something is documented
- Theoretical concerns about scale that the PRD already acknowledges and defers

**If you're unsure whether something is CRITICAL or MINOR, it's MINOR.** Do not downgrade MINOR to NOT A GAP just because a human *could* figure it out — the question is whether an AI agent would get it right without the specification. Only classify something as NOT A GAP when the correct behavior is unambiguous from context.

### Entity Classification

Before running CRUD checks, classify each entity:

- **User-facing:** Has UI pages, appears in user stories as something the user directly interacts with. Apply full CRUD checks.
- **Internal/system:** Background records, run logs, join tables, structured output types. CRUD checks do not apply — check only that the PRD specifies how they're created and queried by the system components that use them.
- **Cross-PRD extension:** Fields or mutations added to another PRD's entities. Check only that the extension is clearly specified and non-breaking.

**Do NOT flag missing "Edit" or "Delete" stories for internal entities.** An implementer will not be confused by the absence of a user-facing delete story for `ThinkerRun`.

### When a PRD Is Done

A PRD is **ready for implementation** when:
- Every user-facing entity has stories covering its user-facing operations (which may intentionally exclude some CRUD operations — check Non-Goals)
- No two sections contradict each other
- An implementer can build every user story without inventing behavior

A PRD does NOT need:
- 100% score on every checklist item
- Every theoretical edge case documented
- Every "nice to have" clarification added

**If a PRD scores ≥ 90% and has zero CRITICAL gaps, say so clearly and recommend proceeding to implementation.** Do not hunt for things to fill a report. Empty sections are fine — they mean the PRD passed that check.

---

## The Job

1. Read the PRD provided by the user — **read it completely** before starting analysis
2. Extract and classify all entities (Step 1)
3. Run CRUD coverage check — **only for user-facing entities** (Step 2)
4. Run internal consistency check — contradictions, testability, component-data alignment (Step 2.5)
5. Run relationship & hierarchy check (Step 3)
6. Run UI state coverage check (Step 4)
7. Run interaction pattern check (Step 5)
8. Run API-to-story alignment check (Step 6)
9. Run package dependencies check (Step 7)
10. Run database index coverage check (Step 8)
11. Generate a gap report with specific recommendations (Step 9)
12. Optionally: Generate missing user stories — **only for CRITICAL gaps**

---

## Step 1: Entity Extraction & Classification

Read through the PRD and identify ALL entities. An entity is anything that:
- Has a data model/interface defined
- Appears in user stories as something created, viewed, edited, or deleted
- Is mentioned in API endpoints
- Appears in UI specifications

Classify each entity before proceeding:

```
ENTITIES FOUND:
1. [Entity A] (user-facing) - mentioned in: [US-001, Data Models, API, UI]
2. [Entity B] (internal) - mentioned in: [Data Models, API — no UI, system-created only]
3. [Entity C] (cross-PRD extension) - adds fields to [Other PRD]'s [Table]
```

---

## Step 2: CRUD Coverage Check

**Apply ONLY to user-facing entities.** For internal entities, skip this step entirely — do not flag missing CRUD stories for system records.

For each user-facing entity, check the Non-Goals section FIRST. If the PRD explicitly defers or excludes an operation (e.g., "Users cannot delete observations"), mark it as "N/A (Non-Goal)" — not "MISSING."

| Entity | Create | Read (List) | Read (Detail) | Update | Delete | Notes |
|--------|--------|-------------|---------------|--------|--------|-------|
| Entity A | US-002 | US-001 | US-005 | N/A (Non-Goal) | N/A (Non-Goal) | Intentionally read-only per Non-Goals |
| Entity B | MISSING | US-003 | N/A | US-004 | MISSING | Has tasks but no way to add them! |

### Create Check
- [ ] Is there a story for creating this entity? (Or is creation intentionally system-only per Non-Goals?)
- [ ] Does it specify the trigger (button, menu item)?
- [ ] Does it specify required vs optional fields?
- [ ] Does it specify what happens after creation (redirect, close modal, etc.)?

### Read (List) Check
- [ ] Is there a story for viewing a list of this entity?
- [ ] Does it specify sorting options?
- [ ] Does it specify filtering options?
- [ ] Does it specify pagination or infinite scroll?
- [ ] Does it specify what columns/fields are shown?

### Read (Detail) Check
- [ ] Is there a story for viewing a single item's details?
- [ ] Does it specify how to navigate to detail (click row, dedicated button)?
- [ ] Does it specify the layout (tabs, sections)?

### Update Check
- [ ] Is there a story for editing this entity? (Or is editing intentionally excluded per Non-Goals?)
- [ ] Does it specify which fields are editable?
- [ ] Does it specify the edit interaction (modal, inline, page)?
- [ ] Does it specify validation?

### Delete Check
- [ ] Is there a story for deleting this entity? (Or is deletion intentionally excluded per Non-Goals?)
- [ ] Does it specify confirmation behavior?
- [ ] Does it specify what happens to related/child entities?

---

## Step 2.5: Internal Consistency Check

Scan for contradictions within the PRD itself — things that an agent would implement differently depending on which section it read first.

### Overview vs Non-Goals
- [ ] Does the overview claim a feature that is explicitly deferred in Non-Goals?
- [ ] Are deferred features consistently described as deferred throughout (not partially specified in user stories)?

### Cross-PRD Source Truthfulness & Testability
- [ ] For each entity or value that references an external PRD or system (e.g., a status field set only by an agent defined in a later PRD), does that PRD/system actually exist in the current batch?
- [ ] For each workflow group: is there a UI path to CREATE the primary entity within this PRD's scope?
- [ ] If not, is there a dev note explaining how to seed test data (dashboard, script, etc.)?

Flag untestable groups in the gap report using this format:
```
⚠️ UNTESTABLE: [Workflow Group]
Reason: [Entity] can only be created by [External PRD/System], not in scope.
Recommendation: Add dev note to [US-XXX] explaining how to seed via [dashboard/script].
```

### Component-Data Shape Alignment
*Only apply this check when the PRD explicitly defines component props or interfaces.*
- [ ] For each shared component with defined props, check that the data model produces the shape those props expect
- [ ] e.g., if a DiffViewer takes `(oldContent, newContent)` strings but the data model stores a pre-computed diff string — that's a mismatch
- [ ] e.g., if a selector component expects `{ id, label }[]` but the query returns raw DB records — flag it
- [ ] If component interfaces are not specified in the PRD, skip this check — it can't be evaluated

---

## Step 3: Relationship & Hierarchy Check

For entities that contain or relate to other entities:

### Parent-Child Relationships
```
RELATIONSHIPS FOUND:
- Work Item CONTAINS Tasks
- Template CONTAINS Sections
- Section CONTAINS Template Tasks

CHECKS:
- [ ] Can Tasks be added to a Work Item? Story exists? [YES/NO - US-XXX]
- [ ] Can Tasks be removed from a Work Item? Story exists? [YES/NO]
- [ ] Can Tasks be reordered within a Work Item? Story exists? [YES/NO]
- [ ] What happens when Work Item is deleted? Tasks cascade? Specified? [YES/NO]
```

### Hierarchy Depth
```
If nesting exists (e.g., Tasks → Subtasks):
- [ ] Is the nesting depth specified? (1 level, 2 levels, unlimited?)
- [ ] Are operations for child entities specified?
- [ ] Is the UI for nested items specified?
```

---

## Step 4: UI State Coverage

Check if the PRD specifies all UI states:

### Empty States
For each list/collection view:
- [ ] Empty state message specified?
- [ ] Call-to-action in empty state specified?
- [ ] Empty state illustration/icon specified?

### Loading States
- [ ] Initial load indicator specified?
- [ ] Skeleton loaders vs spinners specified?
- [ ] Loading state for individual operations specified?

### Error States
- [ ] Form validation errors specified?
- [ ] Network/API error handling specified?
- [ ] Retry mechanism specified?

### Success Feedback
- [ ] Success notification style specified (toast, inline, redirect)?
- [ ] Undo option for destructive actions specified?

### Layout & Scroll Behavior

For each page/view, think through: "If this page has lots of content, 
what will the user need to always see while scrolling?"

**Review Questions:**
1. **Will navigation disappear?** If the header scrolls away, how does user navigate?
2. **Will context disappear?** Can user always see WHAT they're looking at?
3. **Will primary actions disappear?** Submit buttons, main CTAs - still accessible after scroll?
4. **For split views:** Does each panel scroll independently, or does scrolling 
   one panel affect the other?

**Common Gaps to Flag:**
- List + sidebar views where sidebar disappears on scroll (sidebar should be sticky)
- Detail pages with action buttons that scroll out of view (actions should be sticky)
- Forms where submit button is only at the bottom (submit area should be sticky or floating)
- Headers that scroll away losing context (header should be sticky)
- Split-panel views that scroll as one unit instead of independently

**If Not Specified, Add to Gaps:**
"Page layout doesn't specify scroll behavior. Recommend: [specific suggestion based on page type]"

Example: "Ticket detail page should have: sticky header with ticket info, 
sticky reply composer at bottom, scrollable conversation thread, 
scrollable sidebar for metadata."

---

## Step 5: Interaction Pattern Check

### Modal vs Inline
For each create/edit operation:
- [ ] Interaction pattern specified (modal, inline, page, panel)?
- [ ] Modal close behavior specified (click outside, X button, Escape key)?

### Confirmation Dialogs
For each destructive action:
- [ ] Confirmation required? Specified?
- [ ] Confirmation message specified?
- [ ] Button labels specified ("Delete" vs "Remove" vs "Cancel")?

### Form Behavior
- [ ] Validation timing specified (on blur, on submit, real-time)?
- [ ] Required field indicators specified?
- [ ] Save behavior specified (auto-save, explicit save button)?

---

## Step 6: API-to-Story Alignment

Check that every backend operation has a corresponding user story **or is documented as internal-only**. Use the terminology for your project's backend (REST endpoints, Convex functions, GraphQL mutations, tRPC procedures, etc.):

Internal-only operations (used only by background agents, crons, or other system components) do NOT need user stories — they need clear documentation of which system component calls them and when. Mark these as "OK (internal)" not "MISSING."

```
BACKEND OPERATIONS vs USER STORIES:

| Operation             | Type     | Corresponding Story       | Status  |
|-----------------------|----------|---------------------------|---------|
| tasks:create          | mutation | US-011: Add Task          | OK      |
| tasks:update          | mutation | NONE                      | MISSING |
| thinkerRuns:create    | mutation | US-620 (internal)         | OK (internal) |
```

---

## Step 7: Package Dependencies Check

- [ ] Every npm/pip/etc. package mentioned in component specs, implementation notes, or functional requirements has a row in a dependencies table
- [ ] Every library referenced by name in prose (e.g., "built on `react-markdown`") is formally listed
- [ ] If no dependency table exists but packages are referenced, flag it: **MISSING — add a Package Dependencies section**

---

## Step 8: Database Index Coverage Check

For each query or list operation in the API section:
- [ ] If it orders by a custom field (not a field the database indexes automatically), is there an explicit index on that field?
- [ ] If it filters by a custom field, is there an explicit index on that field?
- [ ] Check the Data Models section — do the index definitions match the query patterns described in the API section?

```
INDEX COVERAGE:
| Query/Operation | Orders/Filters By | Index Defined? |
|-----------------|-------------------|----------------|
| list            | updatedAt desc    | YES / MISSING  |
| search          | status, createdAt | YES / MISSING  |
```

Common miss: a `list` operation ordered by `updatedAt` with no index defined on that field.

---

## Step 9: Generate Gap Report

**Before writing the report, count your CRITICAL gaps. If you have zero, say so in the first line and keep the report short.**

Output a structured report:

```markdown
# PRD Review: [PRD Name]

## Verdict

[One of:]
- **READY FOR IMPLEMENTATION** — No critical gaps. [N] minor suggestions below. Proceed to building.
- **NEEDS FIXES** — [N] critical gap(s) that would block or break implementation. Fix these, then proceed.
- **NEEDS REWRITE** — Fundamental structural issues (< 50% coverage). Recommend rewriting with the PRD skill.

## Critical Gaps (Must Fix)

[Only if there are genuine critical gaps per the severity calibration above.]
[If none: "None found." — do NOT fill this section with inflated findings.]

### 1. [Gap Title]
**Problem:** [What's wrong]
**Impact:** [What breaks if not fixed — be specific]
**Recommendation:** [How to fix it]

## Minor Gaps (Nice to Fix)

[Items an implementer could reasonably figure out, but the PRD should be explicit about.]
[Report all genuine minor gaps — don't artificially cap the list. But each item must fail a specific checklist check from Steps 2–8, not just be a "nice to have" observation.]

### 1. [Gap Title]
**Recommendation:** [One-line fix]

## Sections That Passed Clean

[List the checks that found no issues. This gives the user confidence the review was thorough
without padding the report with non-findings dressed up as findings.]

- Entity coverage: ✓ (all user-facing CRUD covered, internal entities appropriately scoped)
- Internal consistency: ✓ (no contradictions found)
- Index coverage: ✓ (all query patterns have indexes)
- [etc.]
```

**Do NOT include these sections if they have no findings:**
- "Implicit Assumptions Found" — only include if an assumption would genuinely cause an implementer to build the wrong thing
- "Recommended Additional User Stories" — only include for CRITICAL missing stories

---

## Quick Checklist Output

**When to use:** Use this instead of the full gap report (Step 9) when the user wants a fast pass rather than a thorough review — e.g., "quick check" or "is this roughly complete?" For a thorough review before implementation, always use Step 9.

For a fast review, output this checklist:

```markdown
## PRD Completeness Checklist: [PRD Name]

### Entity Coverage (user-facing only)
| Entity | Create | List | Detail | Edit | Delete | Notes |
|--------|--------|------|--------|------|--------|-------|
| [Name] | ✓ | ✓ | ✓ | N/A (Non-Goal) | N/A (Non-Goal) | [notes] |

### UI States
- [✓/✗] Empty states for all lists
- [✓/✗] Loading states specified
- [✓/✗] Error handling specified
- [✓/✗] Success feedback specified
- [✓/✗] Confirmation dialogs for destructive actions

### Interaction Patterns
- [✓/✗] Modal vs inline specified for all forms
- [✓/✗] Validation behavior specified
- [✓/✗] Save/cancel behavior specified

### Relationships
- [✓/✗] All parent-child operations covered
- [✓/✗] Cascade/orphan behavior specified
- [✓/✗] Hierarchy depth specified (if nested)

### Layout & Scroll Behavior
- [✓/✗] Sticky elements specified for each page (header, sidebar, actions)
- [✓/✗] Scroll containers defined (what scrolls vs stays fixed)
- [✓/✗] Split views scroll independently (if applicable)
- [✓/✗] Primary actions remain accessible while scrolling

### API / Backend Alignment
- [✓/✗] Every user-facing operation has a corresponding user story
- [✓/✗] Internal operations documented with calling component

### Internal Consistency
- [✓/✗] Overview claims match non-goals (no contradictions)
- [✓/✗] Deferred features are consistently deferred throughout
- [✓/✗] Component prop interfaces match the data shapes that feed them *(skip if PRD doesn't define component interfaces)*

### Testability
- [✓/✗] Every workflow group has a creation path in this PRD's scope
- [✓/✗] Untestable workflows have dev notes about seeding

### Technical Completeness
- [✓/✗] All referenced npm packages listed in a dependencies table
- [✓/✗] Every query sorted/filtered by a custom field has a database index

**Verdict: [READY / NEEDS FIXES / NEEDS REWRITE]**
```

---

## Usage

When the user provides a PRD:

1. **Read it completely** before starting analysis
2. **Apply severity calibration strictly** — re-read the Critical Rules section before writing the report
3. **Be honest when a PRD is good** — a clean report is a valid outcome
4. **Don't pad the report** — empty sections and "None found" are signs of a thorough PRD, not a lazy review
5. **Generate missing stories only for CRITICAL gaps** — not for minor nice-to-haves
6. **Be specific** — "Missing delete story for Tasks" not "Some operations missing"
7. **One full review pass per request** — run all checks once and report. If the user asks you to re-review after making fixes, check only those fixes — do not re-run the full review looking for new things to report.

If the PRD is very incomplete (< 50% score), recommend rewriting with the comprehensive PRD skill rather than patching.
