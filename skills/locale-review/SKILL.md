# Locale Review

Review the linguistic quality of translated locale files against the English source.
Modeled on i18n-ai-translate's `check` pipeline + ethereum.org's intl-review rubric,
with Claude as the engine (no API key, no writes).

## Inputs

- Source of truth: `src/i18n/locales/en.json` (i18next flat-file-per-locale).
- Targets: locale codes passed as arguments (e.g. `fr ar`), or all 19 non-`en` files if none given.

## Pipeline

1. **Mechanical pre-pass** (deterministic, per locale — run with `jq`/node, not judgment):
   - Missing / extra keys vs `en.json`.
   - Interpolation variables: every `{{var}}` in the source value must appear in the target value.
   - Plural suffixes: for each `en` key family (`_one`/`_other`…), the target must carry the
     CLDR-required categories for its language (`Intl.PluralRules(lang).resolvedOptions().pluralCategories`)
     — critical for ar (six forms), ru/pl (`_few`/`_many`).
2. **Linguistic review** — spawn one agent per locale (parallel, background). Each agent acts as a
   native-speaker reviewer + copywriter for its language and reviews **every** key in batches
   (~80 keys/batch) against these dimensions:
   - **Fidelity** — meaning drift, omissions, additions vs the English source.
   - **Naturalness** — literal/machine-translation smell; must read as written by a native, not translated.
   - **Tone** — warm, reassuring, adult; NEVER babyish (audience = tired parents, not children).
     Exception: `onboarding.*` keys use the playful Dr. Zayd mascot voice.
   - **Register** — correct formality for the locale (e.g. fr `vous` vs `tu` — must be consistent
     app-wide; informal-warm is the target unless the locale's convention says otherwise).
   - **Terminology consistency** — the same concept (e.g. allergen, purée, meal plan, premium)
     translated the same way across all keys.
   - **Locale conventions** — punctuation (fr narrow no-break space before `!?:;`), units,
     date/number wording; RTL-safe copy for ar.
3. **Report** — each agent returns findings as structured rows:
   `key · en · translated · issue · severity (critical/major/minor) · suggested fix`.
   Critical = wrong meaning, broken placeholder, harmful advice. Major = unnatural/wrong tone.
   Minor = polish. Plus a per-locale verdict: overall quality grade (A–F) + top themes.
4. **Synthesis** — merge agent reports, rank by severity, present a compact table + per-locale
   grades. Propose fixes but NEVER edit locale files without explicit user approval per finding
   set (fixes are copywriting, human-reviewed — see the no-machine-translation rule).

## Hard rules

- Read-only by default: this skill audits; edits happen only after user approval.
- Never suggest machine translation (DeepL etc.) as a fix path — fixes are human-quality copywriting.
- Product rules apply to suggestions too: no calories/macros, no guilt mechanics, no ellipsis
  truncation, medical-disclaimer tone stays intact.
- Cite keys exactly; never paraphrase a finding without its key.
