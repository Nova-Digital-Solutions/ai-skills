# Internal Documentation

Nova Digital Solutions internal knowledge base — company docs, AI skills, templates, and automation scripts.

## Structure

| Folder | What goes here |
|---|---|
| `docs/` | All written knowledge: processes, guides, policies, SOPs |
| `skills/` | AI agent skills — reusable SKILL.md files for Claude, Cursor, and other AI coding assistants |
| `scripts/` | Automation scripts and tooling (e.g., Ralph autonomous agent, build-plan-generator) |
| `templates/` | Reusable templates for documents, checklists, and forms |

## Docs

### Engineering
- [GitHub Workflow](docs/github-workflow.md) — Git branching, PRs, project board, and repo setup

### Operations
_No docs yet._

### Company
_No docs yet._

## New Here?

If you just joined, read these docs in order:

1. [GitHub Workflow](docs/github-workflow.md) — how we use Git, GitHub issues, and the project board

More onboarding docs will appear here as we write them. Any doc with `onboarding: true` in its frontmatter is part of this path.

## Contributing

1. Create a `.md` file in `docs/` with a kebab-case name (e.g., `dev-environment-setup.md`).
2. Add frontmatter at the top:
   ```yaml
   ---
   title: Dev Environment Setup
   area: engineering | operations | company
   type: guide | process | policy
   onboarding: false
   owner: Your Name
   created: YYYY-MM-DD
   last-reviewed: YYYY-MM-DD
   status: draft | active | deprecated
   ---
   ```
3. Add a link to the **Docs** section above under the right topic heading.
4. If the doc is part of the new-hire onboarding path, set `onboarding: true` and `onboarding-order: N`, then add it to the **New Here?** list.
5. Open a PR for review.
