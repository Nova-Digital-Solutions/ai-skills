# Internal Documentation

Nova Digital Solutions internal knowledge base — operational processes, SOPs, guides, policies, templates, AI skills, and automation scripts.

## Structure

| Folder | What goes here |
|---|---|
| `processes/` | Operational workflows and step-by-step procedures (e.g., client onboarding, monthly close) |
| `sops/` | Formal Standard Operating Procedures with version control and ownership |
| `guides/` | How-to guides, reference material, and training docs |
| `policies/` | Company policies, compliance requirements, and rules |
| `templates/` | Reusable templates for documents, checklists, and forms |
| `skills/` | AI agent skills — reusable SKILL.md files for Claude, Cursor, and other AI coding assistants |
| `scripts/` | Automation scripts and tooling (e.g., Ralph autonomous agent) |

## Conventions

- **File naming:** Use kebab-case (e.g., `client-onboarding.md`)
- **Format:** Markdown (`.md`) for all documentation
- **Images/assets:** Place in an `_assets/` subfolder within the relevant section if needed
- **Ownership:** Add a frontmatter block at the top of each document with owner and last-reviewed date

### Document frontmatter

```markdown
---
title: Document Title
owner: Name or Team
created: YYYY-MM-DD
last-reviewed: YYYY-MM-DD
status: draft | active | deprecated
---
```

## Contributing

1. Create a branch for your changes
2. Add or update documentation following the conventions above
3. Open a PR for review
