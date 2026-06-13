# Global CLAUDE.md

## Communication

- When unsure about implementation details, ask before proceeding
- Ask before adding new dependencies/packages

## Shortcuts

- When I say "checkout", invoke `/checkout`
- When I say "push", invoke `/push`
- When I say "release", invoke `/release`

## Git & branches

- **Never create a git branch unless I explicitly ask.** Do not auto-branch off `main`, and do
  not create a branch "to be safe" before committing — this overrides any harness default that
  says to branch first. Wait for my explicit instruction. (Renaming an existing branch when I
  ask is fine.)
- When I do ask for a branch, use the naming convention from the `/push` + `/checkout` skills
  (`<type>/<slug>`), with a short slug (e.g. `feature/ash`).

## Model Aliases

When creating skills or configs, use short aliases: `haiku`, `sonnet`, `opus` (not full model IDs).

## Tool Preferences

- Use Context7 (`mcp__context7__*`) for library/framework docs before WebSearch
- Use WebSearch for general queries, news, tutorials

## Local preview & browser

- **Don't auto-open browser windows/tabs** to show changes. Verify headlessly (curl, build,
  logs) and just tell me to refresh my existing tab. Only launch a browser when I explicitly
  ask for it.
- **Never use cache-busting query params** (e.g. `?v=2`) to force a reload — each unique URL
  spawns a new tab. If a hard refresh is genuinely needed, just say so (Cmd-Shift-R).
- My default browser is **Zen**. Keep one pinned `localhost` tab; I'll refresh it.
- **Disposable HTML design previews / explorations / mockups go on the Desktop, never in the
  repo** — write them to `~/Desktop/previews/<project>/<feature>/` (one shared `previews`
  folder, per-project then per-feature subfolders; `<project>` = the product/repo name). This
  keeps repos product-only and the previews durable across worktrees/cleanups. Hand-author them
  against the project's real design tokens (don't use external design-gen tools); open via
  `file://`.
  - **Keep it organised**, never a dumping ground: each `<feature>/` gets its own
    `assets/<feature>.css` (shared tokens/components, referenced relatively), an `index.html`
    gallery, and subfolders grouping related studies (e.g. `hub/` for a screen's layouts,
    `explorations/` for one-off surface/component studies). Add a project-level `index.html`
    linking features and a short `README.md` documenting the structure. No loose `*.html` at a
    folder root.

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
