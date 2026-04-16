---
name: document-manifest
description: "Split a project overview document into 5 standardized pre-PRD documents (Product Design, User Definition, Frontend Architecture, Backend/Infrastructure, Metrics/Data). Use when starting a new project and need to decompose an overview into structured documents for PRD writing. Triggers on: split documents, document manifest, split overview, create split docs, decompose overview."
---

# Document Manifest — Overview Splitter

Split a project overview document into 5 standardized pre-PRD documents. This skill standardizes the pre-PRD document split phase: instead of ad-hoc serial chats producing documents of varying quality, it defines exactly what 5 documents must be produced, what each must contain, and how to cross-validate them.

**This skill does NOT do PRD writing** — it produces the intermediate documents that PRD writing draws from.

## The Job

1. Read the overview document provided by the user completely before starting
2. Generate all 5 documents in order, saving each to `/docs/`
3. Mark inferences: where the overview is vague or doesn't specify something, mark as `[INFERRED — verify]`
4. Make each document self-contained — don't reference "see the overview," include the relevant information directly
5. Cross-check all 5 documents for terminology consistency after producing them
6. Output a cross-check summary showing any inconsistencies found

## The 5 Documents

### Document 1: Product Design Document

**File:** `docs/split-product-design.md`

**Must contain:**
- Color palette with exact hex codes
- Typography (fonts, sizes, weights, line heights)
- Component patterns (buttons, cards, tables, badges, modals, forms)
- Layout grid and spacing scale
- State patterns (hover, active, disabled, selected, error, success)
- Animation/transition standards (if any)
- Responsive breakpoints

**Quality check:** "Could a developer build any UI component using only this document?"

---

### Document 2: User Definition Document

**File:** `docs/split-user-definition.md`

**Must contain:**
- All user roles with descriptions
- Role hierarchy and inheritance
- Permissions matrix (what each role can see/do)
- Key user journeys per role (3–5 each)
- Goals ranked by importance per role
- Edge case users (multi-role, limited access, first-time)
- User onboarding considerations

**Quality check:** "Could you write acceptance criteria for any feature using only this document?"

---

### Document 3: Frontend Architecture Document

**File:** `docs/split-frontend-architecture.md`

**Must contain:**
- Complete page inventory (every page/view in the application)
- Navigation structure (sidebar items, header items, how pages connect)
- Page layouts (sidebar+main, full-width, split-panel — per page)
- Shared/reusable components (what's shared across pages)
- Responsive behavior per layout type
- Routing structure (URL patterns, dynamic segments, nested routes)
- State management approach

**Quality check:** "Could a developer build the app shell and navigation using only this document?"

---

### Document 4: Backend/Infrastructure Document

**File:** `docs/split-backend-infrastructure.md`

**Must contain:**
- Data model (all entities, fields, relationships, indexes)
- API/query patterns (Convex queries, mutations, actions — or REST endpoints depending on stack)
- Authentication flow (login, session, token refresh, logout)
- Real-time/sync behavior
- External integrations (third-party APIs, data sources)
- File/media handling
- Performance considerations (pagination, caching, query optimization)
- Environment configuration

**Quality check:** "Could a developer set up the full backend using only this document?"

---

### Document 5: Metrics/Data Document

**File:** `docs/split-metrics-data.md`

**Must contain:**
- Key metrics with exact formulas/calculations
- Data sources for each metric (which system, which tables/fields)
- Dashboard requirements (which metrics displayed where, refresh rates)
- Calculated/derived fields
- Data freshness indicators
- Export requirements (CSV, PDF, reports)
- Data transformation rules
- Historical data handling

**Quality check:** "Could a developer build all dashboards and data displays using only this document?"

## Process Rules

### Inference Marking

When the overview document is vague or silent on a topic, do not invent content. Instead:
- Include the section with whatever information is available
- Mark assumed details with `[INFERRED — verify]` inline
- If an entire section has no source material, write: "Not specified in overview. [INFERRED — verify]: " followed by reasonable assumptions, or state that this section needs input from the team

### Self-Contained Documents

Each document must be readable and usable on its own. If Document 3 (Frontend Architecture) references user roles, include the role names and brief descriptions — don't say "see the User Definition Document." Duplication across documents is expected and intentional.

### Cross-Check After All 5

After producing all 5 documents, verify consistency across them:
- **User role names** — same names and descriptions in every document that mentions them
- **Entity/model names** — same names in Backend doc and anywhere else they appear
- **Page/view names** — same names in Frontend Architecture and anywhere else they appear
- **Component names** — consistent naming between Product Design and Frontend Architecture
- **Terminology** — no cases where one document calls something "dashboard" and another calls it "portal"

Output a **Cross-Check Summary** listing:
- Consistent terms (brief confirmation)
- Any inconsistencies found with document locations and recommended resolution

## Output Structure

```
docs/
├── split-product-design.md
├── split-user-definition.md
├── split-frontend-architecture.md
├── split-backend-infrastructure.md
└── split-metrics-data.md
```

Each file should use standard markdown with clear heading hierarchy. No YAML frontmatter needed on the split documents themselves.

## Important Notes

- The 5-document structure is the standard — don't skip documents even if the project seems simple
- The user will review these documents before proceeding to PRD planning
- If the overview document doesn't contain enough information for a section, say so explicitly rather than inventing content
- This is a decomposition task, not a creative writing task — extract and organize, don't embellish
