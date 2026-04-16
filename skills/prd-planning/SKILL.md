---
name: prd-planning
description: "Take split documents and produce a complete PRD plan — what PRDs to write, in what order, with dependencies and implementation batches. Use after the document manifest split, before writing individual PRDs. Triggers on: prd plan, prd map, plan prds, map prds, what prds do I need, prd planning."
---

# PRD Planning

## The Job

1. Receive the split documents (from Document Manifest skill), overview document, and tech stack documentation
2. Analyze the full scope of the project
3. Produce a `prd-map.md` file with PRD inventory, ordering, dependencies, and batches
4. Flag decision points where human judgment is needed

## Input Requirements

The skill needs these documents loaded as context:
- All 5 split documents (Product Design, User Definition, Frontend Architecture, Backend/Infrastructure, Metrics/Data)
- The original overview document
- Tech stack documentation (if separate)

## PRD-0: Always First

ALWAYS include PRD-0 as the first entry. PRD-0 is the project scaffolding PRD that sets up the tech stack, authentication, first user bootstrap, and basic app shell. It is written using a dedicated Project Scaffolding PRD template (a separate skill), NOT the standard PRD skill. PRD-0 must be implemented before any other PRD.

## PRD Classifications

Every PRD gets one of these classifications, which determines which review passes apply later:

| Classification | Description | Examples |
|---------------|-------------|----------|
| **SCAFFOLDING** | Project setup, tech stack, auth, app shell. PRD-0 always. | PRD-0: Project Scaffolding |
| **STRUCTURAL** | Base UI layout, navigation, sidebar, header — the shell before features exist. No real product logic yet. | PRD-1: App Shell & Navigation |
| **FOUNDATIONAL** | New user-facing page or feature with real product logic. The core of most projects. | PRD-3: Tasks Page, PRD-5: Client Dashboard |
| **BACKEND-ONLY** | Data models, APIs, integrations, metrics — no frontend UI. | PRD-8: Reporting Engine, PRD-12: Integration |
| **CHANGE** | Modification to an existing feature that already has a foundational PRD. | Change-48 on PRD-3 |

## Output: prd-map.md

The output file must contain these sections:

### Section 1 — PRD-0: Project Scaffolding

Brief description of what PRD-0 covers for this specific project (tech stack, auth method, app shell structure). Always SCAFFOLDING classification.

### Section 2 — PRD List

For each subsequent PRD (PRD-1, PRD-2, etc.):
- PRD number and name (e.g., "PRD-1: App Shell & Navigation")
- One-paragraph description of what it covers
- Which split documents are its primary inputs
- Dependencies on other PRDs (which must be implemented first)
- Complexity estimate: SIMPLE / MEDIUM / COMPLEX
- Review classification: SCAFFOLDING / STRUCTURAL / FOUNDATIONAL / BACKEND-ONLY

### Section 3 — Implementation Ordering

PRDs grouped into implementation batches:
- **Batch 0:** PRD-0 (scaffolding) — always first and alone
- **Batch 1:** PRDs that depend only on PRD-0 (typically independent core features — can run in parallel)
- **Batch 2:** PRDs that depend on Batch 1 PRDs
- **Batch 3+:** Continue as needed

Within each batch, note which PRDs are independent (can be implemented in parallel) and which have ordering constraints within the batch.

### Section 4 — Decision Points

Flag areas where the PRD decomposition isn't obvious and the human needs to decide:
- Features that could be one PRD or multiple
- PRDs that share so many components that parallel implementation may cause conflicts
- Features that depend on data from many other PRDs and might need deferral
- Any ambiguity about scope boundaries

### Section 5 — Minimum Viable Product

Identify the minimum set of PRDs needed to have a demonstrable, usable product. This is the "if you could only build X PRDs, which ones?" question.

## Critical Instructions

Think about implementation ordering, not just logical organization. The question is not "what groups of features go together?" but "what order do I actually need to build things in so that each PRD can be implemented against a working codebase?"

Consider:
- What needs to exist for a developer to log in and see the app? (That's PRD-0)
- What pages/features are independent of each other? (Those can be parallelized)
- What features depend on other features existing first? (Those go in later batches)
- What is the minimum set of PRDs needed to have a demonstrable product? (Flag this)

Do NOT just group features by category. Group them by build order. A dashboard PRD that depends on data from 4 other features can't go in Batch 1 even if it's the most important feature — it goes in whatever batch follows its dependencies.

## Output Location

Save to: `docs/prd-map.md` (or `tasks/prd-map.md` depending on project convention — ask the user if unclear).

## Important Notes

- The PRD map is a planning document, not a PRD itself
- It should be reviewed and adjusted by the human before PRD writing begins
- Complexity estimates inform the complexity budget that the PRD skill will use
- The classification determines which review passes run on each PRD later
- Don't create more PRDs than necessary — look for natural groupings. 8-15 PRDs is typical for a medium project. More than 20 suggests over-decomposition.
