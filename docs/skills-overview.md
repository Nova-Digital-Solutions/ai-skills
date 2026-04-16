# Agent skills — overview and usage

## Purpose

This document explains what **agent skills** are in this repository, how they are structured, and how both people and coding agents should use them. Skills live under [`skills/`](../skills/) at the repo root.

---

## What is a skill?

A skill is a **packaged set of instructions** for an AI coding agent. It tells the model *when* to activate specialized behavior and *what* to do next (workflows, guardrails, checklists, links to references, and sometimes scripts).

Skills are not runtime code in your product. They are **context and procedure** for the agent, similar to a runbook or a detailed prompt template, versioned next to your internal documentation.

---

## How agents use skills

1. **Metadata** — Each skill exposes a short `name` and `description` in YAML frontmatter. Agents (or the host product) use this to decide whether the skill matches the user’s task.
2. **Body** — When a skill is relevant, the agent reads `SKILL.md` and follows its sections (steps, rules, examples).
3. **Bundled assets** — Optional folders such as `scripts/`, `references/`, and `assets/` are loaded or executed only when the skill says to, so large material does not need to sit in the main prompt.

**For best results**, describe your goal in natural language that matches the skill’s description (for example “review this PRD for gaps” or “audit Convex performance”). The agent should then open the matching skill and apply it systematically.

---

## Anatomy of a skill in this repo

```
skills/<skill-id>/
├── SKILL.md          # Required: frontmatter + markdown instructions
├── scripts/          # Optional: shell, Python, etc.
├── references/       # Optional: deep-dive docs
└── assets/           # Optional: templates, icons, static files
```

The `SKILL.md` file must start with frontmatter, at minimum:

- `name` — Identifier for the skill.
- `description` — **Primary trigger text**: what the skill does and **when** to use it (phrases, domains, risky operations). Well-written descriptions make skills fire when they should.

Optional sections in the body cover workflows, policies, and pointers into `references/` or `scripts/`.

---

## How to use these skills as a human

**In Cursor (or similar hosts)**

- Install or symlink skills so the editor’s agent configuration can see them (for example under your user or project skills path, depending on your setup).
- Open this repo when working so relative paths like `skills/nova-cicd/SKILL.md` resolve correctly for you and for the agent.
- When you want a specific workflow, **name it** (“use the verify-story skill before commit”, “follow nova-cicd for this merge”) so the agent loads the right file.

**Creating or changing skills**

- Use [`skills/skill-creator/SKILL.md`](../skills/skill-creator/SKILL.md) as the guide for drafting, iterating, and (where applicable) benchmarking skills.
- Keep `SKILL.md` focused; move long material into `references/`.

**Finding skills outside this repo**

- The [`find-skills`](../skills/find-skills/SKILL.md) skill describes the open ecosystem (`npx skills`, [skills.sh](https://skills.sh/)) for discovering and installing additional skills.

---

## Catalog — skills in this repository

| Skill | Purpose |
|--------|---------|
| [application-ux-audit](../skills/application-ux-audit/SKILL.md) | Cross-PRD and codebase UX consistency audit. |
| [convex-auth-setup](../skills/convex-auth-setup/SKILL.md) | Convex authentication, identity mapping, access control. |
| [convex-components-guide](../skills/convex-components-guide/SKILL.md) | Convex components and encapsulation patterns. |
| [convex-function-creator](../skills/convex-function-creator/SKILL.md) | Convex queries, mutations, actions with validation and auth. |
| [convex-helpers-guide](../skills/convex-helpers-guide/SKILL.md) | convex-helpers utilities and patterns. |
| [convex-migration-helper](../skills/convex-migration-helper/SKILL.md) | Safe schema and data migrations. |
| [convex-performance-audit](../skills/convex-performance-audit/SKILL.md) | Convex performance, subscriptions, contention, limits. |
| [convex-quickstart](../skills/convex-quickstart/SKILL.md) | New Convex backend or adding Convex to an app. |
| [convex-schema-builder](../skills/convex-schema-builder/SKILL.md) | Schema design, indexes, relationships. |
| [document-manifest](../skills/document-manifest/SKILL.md) | Split an overview into pre-PRD documents. |
| [find-skills](../skills/find-skills/SKILL.md) | Discover and install skills from the ecosystem. |
| [frontend-design](../skills/frontend-design/SKILL.md) | Distinctive, high-quality frontend UI work. |
| [nova-cicd](../skills/nova-cicd/SKILL.md) | Nova fork-based CI/CD guardrails (push, PR, release). |
| [nova-issues](../skills/nova-issues/SKILL.md) | Nova GitHub issues, board, and billing/hours workflow. |
| [pdf](../skills/pdf/SKILL.md) | PDF extraction, forms, generation, manipulation. |
| [playwright-cli](../skills/playwright-cli/SKILL.md) | Browser automation via Playwright CLI patterns. |
| [prd](../skills/prd/SKILL.md) | Write a full PRD for a feature or project. |
| [prd-expander](../skills/prd-expander/SKILL.md) | Expand a thin PRD with product/UX depth. |
| [prd-planning](../skills/prd-planning/SKILL.md) | Plan which PRDs to write and in what order. |
| [prd-review](../skills/prd-review/SKILL.md) | PRD completeness review before implementation. |
| [ralph](../skills/ralph/SKILL.md) | Convert PRDs to Ralph `prd.json` format. |
| [react-best-practices](../skills/react-best-practices/SKILL.md) | React / Next.js performance patterns (Vercel). |
| [review](../skills/review/SKILL.md) | General review of pending changes. |
| [security-review](../skills/security-review/SKILL.md) | Security-focused review of pending changes. |
| [skill-creator](../skills/skill-creator/SKILL.md) | Author, improve, and measure skills. |
| [test-convex](../skills/test-convex/SKILL.md) | Test Convex changes in development. |
| [ux-journey-review](../skills/ux-journey-review/SKILL.md) | UX walkthrough review of a PRD. |
| [verify-story](../skills/verify-story/SKILL.md) | Verify acceptance criteria against staged work before commit. |
| [webapp-testing](../skills/webapp-testing/SKILL.md) | Local web app testing with Playwright. |

---

## Related documentation

- [Release process & deployment](release-process.md) — branching and deployments (complements **nova-cicd**).
- [GitHub workflow](github-workflow.md) — Git and GitHub practices for this org.
