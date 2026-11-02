# ADR-0006 — Scope the expression grammar from the reference corpus

- **Status:** Proposed
- **Date:** 2026-10-16
- **Resolves:** open decision #1 in `research_scheduling.md` §15 and `PRD.md` §14.1

## Context

`.template` files embed expression strings in dimensions, bounding boxes, path data, and
positions. `PRD.md` §6.4 specified a grammar from inspection: arithmetic, parentheses,
variables, ternaries, comparisons (`<`, `>`, `<=`, `>=`, `==`, `!=`), and logical
operators (`||`, `&&`). The open question was whether to build that full grammar or a
smaller subset.

This was previously a guess. It no longer needs to be — the repository already contains a
**65-template corpus** in `research/reference_material/`, which is the best available
sample of what real templates actually use.

**Caveat on the evidence below.** That corpus was captured around 2026-03-01 and the
capture did not record the device firmware version. Device firmware has moved from roughly
3.20 to 3.28+ since then. reMarkable ships new stock templates with releases and could
have changed `formatVersion`, added item types, or added built-in variables in that
window. The measurements below are therefore **provisional and dated**, and this ADR
cannot be accepted until the corpus is refreshed (see "Required corpus refresh" below).
Measured against the March 2026 corpus:

| Feature | Occurrences in corpus |
|---|---|
| Item types | `path` 128, `group` 124, `text` 67 — **exactly the three documented**, no others |
| Ternary `? :` | present in 55 of 65 template files |
| `<` | 131 |
| `>` | 91 |
| `||` | 24 |
| `&&`, `==`, `!=`, `<=`, `>=` | **0 — none appear anywhere** |
| `templateWidth` | 420 |
| `templateHeight` | 239 |
| `parentWidth` | 82 |
| `parentHeight` | 26 |
| `paperOriginX` | 2 |
| `paperOriginY` | 0 — documented in the PRD but never used |

So the grammar in active use is narrower than the PRD assumed: arithmetic, parens,
variables, `<`, `>`, `||`, and ternary. Ternaries are pervasive, which confirms they are
not an exotic edge case to defer.

## Decision

Build a **recursive-descent (Pratt) parser** producing an immutable AST, evaluated against
a scope chain of built-in variables plus ordered template constants. Target the grammar as
documented in `PRD.md` §6.4 — **the full operator set, not the observed subset.**

The reasoning for exceeding the evidence: once a precedence table exists, each additional
operator is one row and a handful of tests. `&&`, `<=`, `>=`, `==`, and `!=` cost almost
nothing to support and protect against templates outside our sample — including the user's
own future authored templates, which the editor phase will generate. Deliberately omitting
them would save no meaningful work while guaranteeing a crash on a plausible input.

What the corpus evidence *does* decide:

1. **Only three item types** are implemented. An unknown `type` is a validation error, not
   a silently ignored node.
2. **Ternaries are core, not optional** — they ship in the first version of the engine.
3. **Constants are order-dependent** and may reference earlier constants. Evaluation
   follows declaration order; a forward reference is a validation error.
4. **Unknown identifiers fail loudly** with a diagnostic naming the identifier and its
   location. Silent coercion to zero would produce subtly wrong templates that render
   plausibly — the worst possible failure mode for this product.
5. The engine is pure Domain code with no IO, and is a **100% coverage target**
   (`PRD.md` §11.1).

The corpus becomes the engine's golden-file test suite: every one of the 65 templates must
parse, and every expression in them must evaluate to a finite number.

## Required corpus refresh before acceptance

The whole decision rests on the corpus, so the corpus must be current. This is a
**Phase 0 prerequisite, ahead of any MVP work** (see `overview.md` §6.0).

1. Re-harvest `/usr/share/remarkable/templates` — every `.template` file plus
   `templates.json` — from the device on its current firmware.
2. **Record the firmware version with the snapshot.** Its absence is a real defect in the
   existing fixture set: we cannot say which firmware the current corpus describes.
3. Store snapshots as firmware-versioned directories (e.g.
   `tests/RmTemplateManager.TestKit/corpus/<firmware-version>/`) rather than overwriting.
   Keeping the March capture alongside the new one makes format drift visible and gives
   the `CompatibilityPolicy` real data to reason about.
4. Re-run the measurements above and update the table, noting both firmware versions.
5. **Re-examine the decision** against the new numbers. Specifically: any item `type`
   beyond `group`/`path`/`text`; any operator not in the grammar; any new built-in
   variable; and any change to `formatVersion`.
6. Build the harvest as a small, repeatable script in `tools/` rather than a one-off manual
   copy, since this must be redone after every firmware update. It also serves as early
   validation of the SSH/SCP approach in [ADR-0005](0005-ssh-library.md), ahead of any
   application code.

If the refresh reveals new constructs, this ADR is revised before acceptance rather than
superseded after the fact — the grammar has not been implemented yet, so there is nothing
to unwind.

## Consequences

**Good.** The hardest pure-logic component in the product is specified by evidence rather
than speculation, and arrives with a corpus of real-world regression fixtures for free.
Property-based tests can fuzz the parser for crashes and non-termination. Loud failures on
unknown input keep bad templates off the device. Firmware-versioned snapshots turn "did
reMarkable change the format?" into a question answerable by diffing fixtures.

**Costs.** Slightly more grammar than demonstrably needed. Accepted as cheap insurance.

**Deliberately excluded.** Function calls, string concatenation, variable assignment, and
units — none appear in the corpus. Each would need a new ADR, with evidence.

**Risk.** The corpus is reMarkable's stock templates plus the owner's own. A third-party
template could use syntax outside this grammar. Mitigated by the loud-failure rule: an
unsupported construct produces a clear diagnostic rather than a wrong render.

**Standing risk after acceptance.** Every firmware update can change the format. The
refresh procedure above becomes a recurring maintenance task, not a one-time step, and
re-running it is the first thing to do whenever a template fails to parse.
