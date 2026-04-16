# Issue Body Templates

These templates are used by the agent when creating issues. They're concise and structured — designed for machine creation, not human form-filling.

## Bug Report

```markdown
## Description
[Clear description of the bug]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- Branch: [branch name]
- Browser/OS: [if applicable]
- Related issue: [if applicable]

## Screenshots / Logs
[Paste relevant error messages or screenshots]
```

### Example

```markdown
## Description
Login form submits but returns 500 error when password contains special characters.

## Steps to Reproduce
1. Navigate to /login
2. Enter email: test@example.com
3. Enter password: p@ss!word#123
4. Click "Sign In"

## Expected Behavior
User is authenticated and redirected to dashboard.

## Actual Behavior
500 Internal Server Error. Console shows: `TypeError: Cannot read property 'hash' of undefined`

## Environment
- Branch: main
- Browser: Chrome 120
- Related issue: #38 (auth system epic)
```

## Feature Request

```markdown
## Summary
[One-line summary of the feature]

## Motivation
[Why this feature is needed — what problem does it solve?]

## Proposed Solution
[How to implement it at a high level]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Notes
[Any technical considerations, dependencies, or design references]
```

### Example

```markdown
## Summary
Add dark mode toggle to user settings.

## Motivation
Multiple client requests for dark mode support. Reduces eye strain for users working at night.

## Proposed Solution
Add a theme toggle in Settings > Appearance. Store preference in user profile. Use CSS variables for theme switching. Default to system preference.

## Acceptance Criteria
- [ ] Toggle appears in Settings > Appearance
- [ ] Theme persists across sessions (stored in user profile)
- [ ] System preference is used as default
- [ ] All pages render correctly in dark mode
- [ ] No FOUC (flash of unstyled content) on page load

## Notes
- Use Tailwind dark: variant
- Existing color tokens in `tailwind.config.js` need dark equivalents
```

## Task

```markdown
## Objective
[What needs to be done and why]

## Details
[Implementation details, approach, or context]

## Checklist
- [ ] [Step 1]
- [ ] [Step 2]
- [ ] [Step 3]
```

### Example

```markdown
## Objective
Set up CI pipeline for the new API service.

## Details
Configure GitHub Actions for the `api-service` directory. Should run on PRs targeting `main` and `dev`. Needs Node 20, pnpm, and PostgreSQL service container for integration tests.

## Checklist
- [ ] Create `.github/workflows/api-ci.yml`
- [ ] Add lint step (ESLint + Prettier check)
- [ ] Add unit test step (Vitest)
- [ ] Add integration test step with PostgreSQL service
- [ ] Add build verification step
- [ ] Test with a sample PR
```

## Usage Guidelines

1. **Be specific.** Don't write "fix the bug" — describe the actual bug.
2. **Include context.** Reference related issues, branches, or epics.
3. **Keep it scannable.** Use headers and checklists, not paragraphs.
4. **Link parent epics.** If this is part of a larger effort, mention the epic number.
5. **Acceptance criteria are required for features.** This is how we know when it's done.
