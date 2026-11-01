# ADR-0007 — Render previews via a pure RenderPlan drawn by WPF

- **Status:** Proposed — choice confirmed by the project owner 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16
- **Revision 2026-11-01:** `RenderPlan` was under-specified. The November corpus refresh
  found cubic Bézier commands, closed subpaths, fill colour, stroke colour and an
  antialiasing hint in the stock templates — none of which the original display-list
  shape could carry. §"Decision" below is corrected. The architectural split is unchanged.
  Evidence: [`docs/template-format-findings.md`](../../template-format-findings.md) §3.
- **Resolves:** open decision #2 in `research_scheduling.md` §15 and `PRD.md` §14.1

## Context

The product must render a visual preview of a template — resolved expressions, path
geometry, text placement, groups with repeat/tiling, correct orientation, at device-accurate
dimensions (`PRD.md` §7.2) — and later update it live while editing (§7.3).

The corpus shows what this involves in practice: 128 path items, 124 groups, 67 text items,
and 102 `repeat` declarations including infinite tiling in both axes. The geometry work is
substantial; the drawing work is simple (straight lines via `M`/`L` commands, plus text).

| Option | For | Against |
|---|---|---|
| **WPF `DrawingVisual` / `DrawingContext`** | No dependencies; native to [ADR-0003](0003-wpf-desktop-shell.md); retained-mode and GPU-composited; vector output zooms cleanly; trivially supports export to XPS/print | WPF-only, so it does not survive a UI port |
| **SkiaSharp** | High performance; cross-platform; identical output in a future Avalonia port; easy PNG export | Native dependency to ship and package; an extra interop layer for a workload that is mostly straight lines |
| **`WriteableBitmap`, hand-rasterized** | Total control | Reimplements a rasterizer badly; no free anti-aliasing; poor zoom |

The real risk in all three is the same, and it is not the drawing API: it is putting
layout, expression resolution, and tiling logic inside UI code, where it becomes
untestable and non-portable.

## Decision

Split the problem in two, and put the hard half in the Domain.

1. **Domain `LayoutResolver` → `RenderPlan`.** A pure function from `TemplateDefinition`
   to a flat, immutable, render-agnostic display list. All expression evaluation, group
   nesting, bounding-box math, and repeat/tiling expansion happens here, with no reference
   to any drawing API.
2. **UI draws the `RenderPlan`.** A WPF control walks the display list and issues the
   corresponding draw calls. This renderer is intentionally dumb — a loop with no
   decisions in it.

### What `RenderPlan` must carry

*Corrected 2026-11-01 against the observed corpus. The original version listed only
straight line segments and text runs, which cannot render 13 filled paths, 54 closed
subpaths, or 260 cubic Bézier commands that ship on the device.*

A plan is an ordered list of **drawable figures**, each one of:

| Figure | Carries |
|---|---|
| **Path** | One or more **subpaths**, each an ordered run of segments plus an explicit `IsClosed` flag (from `Z`) |
| **Text** | Resolved absolute position, font size, and the string |

A path segment is either a **Line** (end point) or a **CubicBezier** (two control points
plus end point) — mirroring the `L` and `C` commands, with all coordinates already
resolved to absolute numbers.

Each path additionally carries its **paint**:

- `StrokeColor` — RGBA, parsed from 6- **or 8-digit** hex. The 8-digit case is real:
  `#00000000` appears in the corpus and means fully transparent, so alpha cannot be
  dropped.
- `StrokeWidth` — optional; absent means the device default.
- `FillColor` — optional RGBA. **Fill is a distinct concept from stroke**, not a variant
  of it; a figure may have either, both, or neither.
- `Antialias` — the hint from `antialiasing`, carried through rather than resolved away.

Colour is represented as a Domain value type (four bytes), never as a WPF `Color` or a raw
string, so the Domain stays framework-free and hex parsing is unit-tested in one place.

Infinite repeats are expanded against an explicit viewport the caller supplies, so
`"infinite"` resolves to a finite, testable figure count rather than an unbounded loop.

Infinite repeats are expanded against an explicit viewport the caller supplies, so
`"infinite"` resolves to a finite, testable segment count rather than an unbounded loop.

## Consequences

**Good.** The genuinely hard logic — tiling, nesting, expression-driven geometry — is pure
Domain code, unit-testable without a window, and a coverage target. `RenderPlan` is a
value object, so preview correctness is asserted by comparing plans in tests, not by
eyeballing pixels or diffing screenshots. Snapshot-testing a data structure is far more
robust than image comparison.

Swapping to SkiaSharp, or to Avalonia under [ADR-0003](0003-wpf-desktop-shell.md)'s revisit
triggers, replaces only the dumb renderer. The same `RenderPlan` can later feed PNG export,
print, or a web preview with no new layout code.

**Costs.** One extra abstraction between template and pixels. Justified: it is the seam
that makes the component testable and portable.

**Risks.** A pathological template could expand to an enormous `RenderPlan` and exhaust
memory. Mitigated by a configurable cap on expanded repeat instances, surfaced as a
validation warning rather than a hang.

**Deferred.** `iconCode` glyph rendering (open decision #6) depends on access to
reMarkable's icon font and is out of scope here; previews show template geometry, not
picker icons.
