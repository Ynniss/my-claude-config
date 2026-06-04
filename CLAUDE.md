# Global CLAUDE.md

## Communication

- When unsure about implementation details, ask before proceeding
- Ask before adding new dependencies/packages

## Shortcuts

- When I say "checkout", invoke `/checkout`
- When I say "push", invoke `/push`
- When I say "release", invoke `/release`

## Model Aliases

When creating skills or configs, use short aliases: `haiku`, `sonnet`, `opus` (not full model IDs).

## Tool Preferences

- Use Context7 (`mcp__context7__*`) for library/framework docs before WebSearch
- Use WebSearch for general queries, news, tutorials

## Testing — non-negotiable, every project

**Every piece of software we build must be testable and tested.** Tests are part of
Definition of Done, not an optional follow-up. This applies to all projects, all
technologies — no exceptions.

- **Definition of Done = tested.** Nothing is "done" until it has automated tests
  appropriate to what it is, and they pass. When wrapping up any feature/screen/module,
  proactively raise "what about the tests?" — never silently skip it. If tests are being
  deferred, say so explicitly and track it; don't let it pass unnoticed.
- **Pick the best tool for the technology.** Choose the idiomatic, best-in-class testing
  approach for the stack in play (confirm with me if it needs a new dependency):
  - UI / end-to-end wherever there's a user interface — drive the real UI. e.g. mobile
    React Native / Expo → **Maestro** (via the global `mobile-verify` skill); web →
    Playwright/Cypress; desktop → the platform's UI-automation tool.
  - Logic / APIs / libraries → the stack's standard runner (Jest/Vitest, pytest, Go test,
    JUnit, etc.).
- **Build for testability as you go.** Add what tests need while writing the code —
  stable test ids / accessibility labels on interactive elements, dependency seams,
  deterministic logic — so nothing has to be retrofitted later.
- **Verify, don't assume.** Before calling something done, actually run the tests / drive
  the app and report real results — pass or fail.

## GitHub Issues

- Interview me first (AskUserQuestion) before drafting - depth depends on complexity
- Show draft for approval before creating on GitHub
- After creating an issue, always display a roadmap table showing all open issues
