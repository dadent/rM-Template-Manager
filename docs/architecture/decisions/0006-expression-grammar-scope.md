# ADR-0006 — Scope the expression grammar from the reference corpus

- **Status:** Proposed — **no longer blocked.** Corpus refreshed 2026-11-01 and confirmed current as of firmware **3.29.1.0**; all conclusions hold. Ready for the owner's review
- **Date:** 2026-10-16
- **Revision 2026-11-01:** evidence table corrected for measurement scope, refresh result
  recorded, and the item-type conclusion narrowed. Full findings:
  [`docs/template-format-findings.md`](../../template-format-findings.md)
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

**The figures below are the corrected, stock-only measurements**, confirmed against the
2026-11-01 refresh. The original draft of this ADR counted some features across stock
*plus* the owner's three custom templates and others across stock only, without stating
which — so several counts were higher than the stock corpus warrants. No conclusion
changed, but a corpus-derived decision must state its scope precisely. Stock and user
templates are now stored separately so the error cannot recur.

Measured across the 65 stock templates:

| Feature | Occurrences in corpus |
|---|---|
| Item types | `path` 118, `group` 115, `text` 60 — **exactly the three documented**, no others |
| Ternary `? :` | present in 55 of 65 template files |
| `<` | 131 |
| `>` | 91 |
| `||` | 24 |
| `&&`, `==`, `!=`, `<=`, `>=` | **0 — none appear anywhere** |
| `templateWidth` | 384 |
| `templateHeight` | 217 |
| `parentWidth` | 76 |
| `parentHeight` | 23 |
| `paperOriginX` | 2 |
| `paperOriginY` | 0 — documented in the PRD but never used |
| `formatVersion` | `1` on all 65 files |

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

1. **Only three item *types*** are implemented. An unknown `type` is a validation error,
   not a silently ignored node. This constrains the type set only — **not the fields those
   types carry**, which the November refresh found to be richer than `PRD.md` §6.5
   documents (fill and stroke colour, antialiasing, cubic Bézier and close-path commands).
   See [`template-format-findings.md`](../../template-format-findings.md) §3 and
   [ADR-0007](0007-preview-rendering.md).
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

## Corpus refresh result (2026-11-01) — blocker cleared

Two firmware updates landed in quick succession, giving three captures across three
firmware generations. Outcome: **the format did not drift, and every conclusion in this
ADR holds.**

| Capture | Firmware | Result |
|---|---|---|
| 2026-03-01 | not recorded (older) | baseline |
| 2026-11-01 #1 | not recorded — the release preceding 3.29.1.0 | identical |
| 2026-11-01 #2 | **3.29.1.0** — confirmed from `/etc/os-release` `IMG_VERSION` | identical |

| Check | Result |
|---|---|
| Stock template files | 65 → 65 → 65, none added, none removed |
| Files with changed content | **0** |
| `templates.json` | identical — 11,949 bytes, 79 entries |
| Aggregate SHA-256 over all 66 files | **identical across all three** |
| `formatVersion` | `1`, unchanged |
| JSON key set | no differences |
| New item types, operators, built-in variables | none |

The corpus is therefore current as of firmware 3.29.1.0, which was the condition for
accepting this ADR. Three generations without change does not *prove* stability —
`formatVersion` exists so reMarkable can change the format — but it establishes that the
format is not volatile, so the corpus is a sound basis for the Domain design.

Three things came out of the refresh beyond the confirmation:

1. **A measurement scope error in this ADR**, corrected in the evidence table above —
   some counts had included the owner's custom templates.
2. **The PRD's item schema is incomplete** — undocumented top-level keys
   (`supportedDevices`, `iconData`) and path fields (`fillColor`, `strokeColor`,
   `antialiasing`), plus `C` and `Z` path commands. This does not touch the expression
   grammar, but it forced a correction to [ADR-0007](0007-preview-rendering.md).
3. **A firmware-detection bug in the harvest script**, which would have labelled snapshots
   with the host OS version instead of the firmware release.

Full detail: [`template-format-findings.md`](../../template-format-findings.md).

Both updates wiped the owner's custom templates while leaving all 65 stock templates
byte-identical — the product's core use case (`PRD.md` §4.6), now observed twice rather
than assumed.

**One caveat carried forward:** the harvest script has still never run successfully
end-to-end. The detection bug is fixed, but the captures were taken manually, so the
script must not be trusted until it has been exercised against a device.

## Required corpus refresh procedure

The whole decision rests on the corpus, so the corpus must be current. This is a
**Phase 0 prerequisite, ahead of any MVP work** (see `overview.md` §6.0), and must be
repeated after **every** firmware update.

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
