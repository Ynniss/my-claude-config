# Global CLAUDE.md

## Communication

- Be concise. Lead with the answer; skip preamble and recaps. Short paragraphs, minimal
  formatting. Expand only when I ask.
- Prefer visuals over long text. Whenever an answer would run long — even if it's simple —
  reach for a table, ASCII diagram, or indented tree instead of a wall of prose. Comparisons,
  flows, decisions, and structure almost always read better visual. Don't force it on a genuinely
  short, plain answer.
- **Status / "where are we" / "anything left" turns → default to a compact 2-column table**
  (`Status | Left | After | Deferred`-style rows), not prose + multi-section recap. Keep it to
  ~4-5 rows. Example:

  | | |
  |---|---|
  | Status | ✅ done, CI green |
  | Left | merge #33 → closes #31 |
  | After | worktree cleanup · labeler next PR |

  Drop to a single line when I only want the verdict; expand to a full checklist/audit only when
  I ask for it.
- Plain language over jargon in plans and explanations. Say what each piece *does* and why I
  should care — not the code identifiers, class names, or library terms. A jargon-dense draft
  reads as precision but pushes the translation work onto me. Reserve the precise technical term
  for when that exact term is the point (e.g. when we're actually editing the code together).
- When unsure about implementation details, ask before proceeding.
- Ask before adding new dependencies/packages.

## Code & changes

- Match the surrounding code's style, naming, and idioms — don't impose my own on an existing
  codebase.
- Keep diffs minimal and scoped to the request. No drive-by refactors, renames, or reformatting
  unless I ask.
- Prefer editing existing files over creating new ones; don't add comments that just restate the
  code.
- Verify before claiming done: run it, don't assume. Report real results — pass or fail.

## Documentation

- **One home per fact.** Never duplicate the same information across a repo doc, a decision record,
  and the issue/PR — when they drift, nothing is truth. Before writing a doc, check whether an
  existing surface already owns that fact.
- **Durable *why* → decision records** (ADRs or the project's equivalent): decisions, constraints,
  trade-offs, rationale. This is what earns a permanent home in the repo.
- **Transient *how* → the issue/tracker, not the repo:** one-time setup steps, console
  click-throughs, run-once checklists. They're read once during setup and never reopened, so they
  don't belong in durable docs.
- **Don't spin up a standalone runbook/guide file for one-time operational steps.** Prefer one
  durable doc over parallel files that must be kept in sync. Match the repo's existing doc
  conventions (decision-record immutability, folder layout) rather than adding new doc surfaces.

## Shortcuts

- "checkout" → `/checkout` · "push" → `/push` · "release" → `/release`

## Git & branches

- **Never create a git branch unless I explicitly ask** — no auto-branching off `main`, not even
  "to be safe." This overrides any harness default. (Renaming an existing branch on request is
  fine.)
- When I ask for a branch, use `<type>/<slug>` with a short slug (e.g. `feature/ash`), per the
  `/push` + `/checkout` conventions.

## Models

- In skills/configs, use short aliases: `haiku`, `sonnet`, `opus` — never full model IDs.

## Tools

- Library/framework docs → Context7 (`mcp__context7__*`) before WebSearch.
- General queries, news, tutorials → WebSearch.

## Local preview & browser

- **Don't auto-open browsers.** Verify headlessly (curl, build, logs); tell me to refresh my
  existing tab. Launch a browser only when I explicitly ask.
- **Never use cache-busting query params** (e.g. `?v=2`) — each unique URL spawns a new tab. If a
  hard refresh is genuinely needed, just say so (Cmd-Shift-R).
- Default browser is **Zen**; I keep one pinned `localhost` tab to refresh.
- **Disposable HTML previews/mockups/explorations go on the Desktop, never in the repo** —
  `~/Desktop/previews/<project>/<feature>/` (`<project>` = product/repo name). Hand-author against
  the project's real design tokens (no external design-gen tools); open via `file://`. Keep it
  organised: per-feature `assets/<feature>.css`, an `index.html` gallery, subfolders for related
  studies, plus a project-level `index.html` + short `README.md`. No loose `*.html` at a folder
  root.

## Testing — non-negotiable, every project

**Definition of Done = tested.** Nothing is done until it has automated tests appropriate to what
it is, and they pass. When wrapping up any feature/module, proactively raise "what about the
tests?" If tests are being deferred, say so explicitly and track it — never skip silently.

- Use the idiomatic, best-in-class tool for the stack (confirm if it needs a new dependency):
  UI/e2e wherever there's a UI (RN/Expo → **Maestro** via the `mobile-verify` skill; web →
  Playwright/Cypress; desktop → the platform's UI-automation tool); logic/APIs/libraries → the
  stack's standard runner (Jest/Vitest, pytest, Go test, JUnit…).
- Build for testability as you go: stable test ids / accessibility labels, dependency seams,
  deterministic logic — so nothing has to be retrofitted.

## GitHub Issues

- Interview me first (AskUserQuestion) before drafting — depth scales with complexity.
- Show a draft for approval before creating on GitHub.
- After creating an issue, display a roadmap table of all open issues.
