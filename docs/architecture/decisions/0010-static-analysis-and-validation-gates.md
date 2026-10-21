# ADR-0010 — Static analysis as the first validation gate

- **Status:** Proposed — choice confirmed by the project owner 2026-10-21, including both open questions below; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-21
- **Prompted by:** review comment on the walking-skeleton definition of done — "do we have
  static code analysis as part of our validation framework?"

## Context

The honest answer when the question was asked: **partially, and nowhere specified.**

The pieces were scattered and assumed rather than decided:

- [ADR-0002](0002-target-dotnet-10-lts.md) sets `Nullable=enable` and
  `TreatWarningsAsErrors=true`.
- `docs/coding-standards.md` tags rules **[build]** — "compiler or analyzer" — and bans
  `.Result`/`.Wait()` on that basis, but **nothing in the repository configures an
  analyzer that would catch them.** The tag was writing a cheque no configuration cashed.
- `overview.md` §7 defines architecture tests, which are assertions in a test project, not
  static analysis.
- The walking skeleton's definition of done lists tests, coverage, CI, and a release
  artifact — **and no analysis step at all.**

So the repository had a credible testing story and no articulated analysis story. Two
drivers make that a worse gap here than it would be on a typical project:

**Driver D5 — most code is AI-generated.** An analyzer is the cheapest reviewer available.
It runs in milliseconds, never tires, never negotiates, and never approves something
because the surrounding code already did it that way. Everything an analyzer catches at
compile time is something that does not have to be caught by a human or a model.

**[ADR-0009](0009-two-model-ai-review-chain.md) makes this quantifiable.** Review there is
an iterative loop: any finding sends the branch back and restarts the round. A defect
caught by the compiler costs **seconds**. The same defect caught at gate 4 costs a **full
convergence round** — persona review, CI, and an independent Codex pass, all re-run. So
every rule promoted from **[review]** to **[build]** directly shortens the loop. Static
analysis is not a parallel nicety to the review chain; it is what keeps the review chain
affordable.

It also serves the coding standard's own pruning rule: rules the toolchain enforces should
be *deleted* from the prose. Analysis configuration is how that prose gets shorter.

## Decision

Define validation as an explicit **five-layer stack**, cheapest first. Each layer catches
what the one below it cannot.

| # | Layer | What it catches | Where it runs |
|---|---|---|---|
| 1 | **Compiler** | Null-safety violations, unused code, all warnings | Build, local and CI |
| 2 | **Analyzers** | Bug patterns, async misuse, banned APIs, code style | Build, local and CI |
| 3 | **Architecture tests** | Layering and dependency-direction violations | Test suite |
| 4 | **Unit / golden / property tests** | Behavioral defects | Test suite |
| 5 | **Security & supply chain** | Vulnerable dependencies, injection patterns | CI, scheduled |

### Layer 1 — compiler

Per ADR-0002, set once in `Directory.Build.props`: `Nullable=enable`,
`TreatWarningsAsErrors=true`, `LangVersion=latest`, deterministic builds.

### Layer 2 — analyzers

**Built-in, configured up:**

- `EnableNETAnalyzers=true` (default on net5+, stated explicitly so it cannot drift).
- `AnalysisMode=All` — the aggressive setting. Rules we genuinely disagree with get turned
  down **individually and with a comment** in `.editorconfig`, never by lowering the mode.
- `EnforceCodeStyleInBuild=true` — makes `IDE*` style rules from `.editorconfig` real
  build diagnostics instead of IDE-only suggestions.
- A single root `.editorconfig` is the one place severities are configured.

**Third-party analyzers — deliberately two, not ten:**

- **`Microsoft.CodeAnalysis.BannedApiAnalyzers`.** This is the high-value one. The
  "Forbidden" table in `coding-standards.md` becomes a `BannedSymbols.txt` file, which
  turns prose into build errors:

  ```
  M:System.DateTime.get_Now; use IClock instead (coding-standards §9)
  T:Newtonsoft.Json.JsonConvert; use System.Text.Json (coding-standards §7)
  P:System.Threading.Tasks.Task`1.Result; await instead (coding-standards §5)
  M:System.Threading.Tasks.Task.Wait; await instead (coding-standards §5)
  ```

  Each banned symbol carries its own rationale, so the error message teaches the rule
  rather than just blocking.

- **`Microsoft.VisualStudio.Threading.Analyzers`.** Async correctness — sync-over-async,
  missing `ConfigureAwait`, `async void`. Directly mechanizes the async section of the
  coding standard, which is otherwise the easiest thing for a generating model to get
  subtly wrong.

**Explicitly deferred:** one general-purpose analyzer package — `SonarAnalyzer.CSharp` or
`Meziantou.Analyzer` — evaluated in its own PR after the baseline is clean. Adding it now,
on top of `AnalysisMode=All`, would bury the walking skeleton in warnings and teach us
nothing about which findings matter.

**Explicitly rejected:** `StyleCop.Analyzers`. `dotnet format` plus `.editorconfig` covers
formatting, and StyleCop's mandatory documentation rules would add noise we would
immediately suppress.

### Layer 3 — architecture tests

Unchanged from `overview.md` §7. These stay tests rather than analyzers because the rules
are project-specific — no off-the-shelf analyzer knows that `Renci.SshNet` belongs in
exactly one file.

### Layer 4 — behavioral tests

Unchanged. Coverage targets per `PRD.md` §11.1.

### Layer 5 — security and supply chain

- **CodeQL** on every PR and on a weekly schedule. Free for public repositories.
- **`dotnet list package --vulnerable --include-transitive`** as a CI step that fails on a
  known advisory.
- **Dependabot** for NuGet and GitHub Actions, weekly, proposing upgrades through the
  normal PR gate.

### Severity and suppression policy

- Analyzer findings surface as warnings locally and become **errors in CI** via
  warnings-as-errors. A clean local build is a clean CI build.
- **No blanket suppressions.** No `GlobalSuppressions.cs`, no `<NoWarn>` lists in project
  files, no lowering `AnalysisMode` to silence a category.
- A suppression is inline, narrowly scoped, and carries a comment stating why. A
  suppression without a justification is a review finding.
- Turning a rule off repo-wide in `.editorconfig` is a deliberate act and belongs in a PR
  of its own, with the reasoning in the description.

### Ratchet, don't big-bang

The baseline is established once during the walking skeleton, where there are only a few
hundred lines to triage. Tightening afterwards — adding the general analyzer, raising a
severity — happens in **dedicated PRs, never bundled with feature work**, so the diff
shows only the rule change and its fallout.

### Definition of done, amended

The walking skeleton's definition of done gains one clause: **the solution builds clean
with zero analyzer warnings at the configured level**, and CI enforces it.

## Consequences

**Good.** The cheapest reviewer runs first and never gets skipped. The ADR-0009
convergence loop gets measurably shorter, because the defect classes most likely to appear
in generated code — sync-over-async, `DateTime.Now`, the wrong serializer — are
mechanically impossible to merge rather than something a reviewer has to notice.
`BannedApiAnalyzers` converts a prose table into build errors, which lets the coding
standard shrink; its error messages cite the rule, so the toolchain teaches the convention
to every future agent session. The validation story is now a named stack rather than an
assumption.

**Costs.** `AnalysisMode=All` produces real initial noise and needs a deliberate triage
pass. AI agents will occasionally fight a rule rather than satisfy it, which costs review
time until `.editorconfig` settles. Two more NuGet dependencies and one more CI job.

**Risks.** The failure mode of aggressive analysis is **suppression culture** — a wall of
warnings leads to blanket `NoWarn`, which is worse than no analysis because it looks like
rigor. The suppression policy above exists specifically to prevent that, and a growing
suppression count is a signal to revisit the rule set rather than add another entry.
Secondary risk: analyzer versions drifting between local and CI, mitigated by central
package management pinning them once.

## Resolved questions

*Both decided by the project owner on 2026-10-21.*

### 1. Analysis mode — `All`, with a named escape hatch

**Start at `AnalysisMode=All`.** Fall back to `Recommended` only if it demonstrably
obstructs completing the walking skeleton — not merely because it is noisy, which it will
be. Noise is triaged by tuning individual rule severities in `.editorconfig`; the mode
drops only if triage itself becomes the bottleneck.

Making that a documented trigger rather than a vague option matters: without it, the first
frustrating afternoon becomes a silent downgrade nobody revisits. If the fallback is ever
taken, it gets a superseding ADR saying which rules caused it, so the decision is
recoverable later when the codebase is larger and the triage cheaper.

### 2. General-purpose analyzer — `Meziantou.Analyzer`

The owner's constraint: static analysis should be genuinely integrated, but **not
burdensome on infrastructure or effort**, and fewer false positives is preferred.

**`Meziantou.Analyzer`** fits that directly. It is a plain NuGet analyzer package — no
server, no account, no external service, nothing in CI beyond the package reference. Its
rule set is pragmatic and tuned toward real defects rather than stylistic preference, so
the triage burden is low.

**Why not `SonarAnalyzer.CSharp`:** the standalone NuGet package works fine on its own, but
the gravity of that ecosystem pulls toward SonarCloud or a self-hosted SonarQube for
dashboards, quality gates, and history. That is precisely the infrastructure weight the
owner ruled out. Choosing the lighter tool avoids acquiring a server we would then feel
obliged to maintain.

**Sequencing is unchanged.** Meziantou is still added in its own PR *after* the walking
skeleton's baseline is clean, so its findings can be judged on their own rather than mixed
into the initial `AnalysisMode=All` triage.
