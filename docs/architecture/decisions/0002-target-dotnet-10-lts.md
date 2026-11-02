# ADR-0002 — Target .NET 10 LTS

- **Status:** Proposed — choice confirmed by the project owner 2026-10-16, document reviewed 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16
- **Supersedes (once accepted):** the .NET 8 choice in `PRD.md` §1.3 and `research/research_scheduling.md` §3

## Context

The original plan (March 2026) targeted .NET 8 LTS, which was the sensible LTS at the time.

**.NET 8 reaches end of support in November 2026** — next month. Starting a brand-new
codebase on a runtime that leaves support before the first real feature ships would mean
an immediate forced migration, and would mean learning a platform on its way out.

.NET 10 is the current LTS. The machine already has SDK `10.0.201` installed alongside
`8.0.426`, so there is no setup cost.

## Decision

Target **.NET 10 (LTS)** for all projects. Pin the SDK with a `global.json` using
`rollForward: latestFeature` so local and CI builds agree and a future SDK install cannot
silently change build behavior.

Set shared properties once in a root `Directory.Build.props`: `Nullable=enable`,
`TreatWarningsAsErrors=true`, `LangVersion=latest`, deterministic builds.

## Consequences

**Good.** Supported through 2028. Current C# language features. WPF is fully supported on
.NET 10, so this costs nothing against [ADR-0003](0003-wpf-desktop-shell.md). Single-file
self-contained publishing and trimming are mature, which helps
[ADR-0008](0008-installer-packaging.md).

**Costs.** `TreatWarningsAsErrors` will occasionally block AI-generated code on trivia.
That is the intent: it is cheaper to fix a warning than to review around it. Nullable
reference types add annotation work in the domain — also intentional, since the domain is
where correctness matters most.

**Follow-up.** Update `PRD.md` §1.3 to .NET 10 when the PRD is revised to v2.0.
