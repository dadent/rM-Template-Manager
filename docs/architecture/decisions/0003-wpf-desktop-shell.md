# ADR-0003 — Use WPF for the desktop shell

- **Status:** Proposed — choice confirmed by the project owner 2026-10-16, document reviewed 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16

## Context

The UI shell needs a Windows desktop framework. Three candidates were considered against
the project's actual goals: relearning disciplined desktop development, and producing a
tool the author will genuinely use. Reaching Mac users was considered and deliberately
deprioritized.

| Option | For | Against |
|---|---|---|
| **WPF** | Mature, best-in-class Visual Studio 2022 tooling; by far the largest body of training data, so AI agents generate higher-quality code; simplest packaging story; no cross-platform CI matrix | Windows-only; in maintenance mode — supported but not actively invested in |
| **Avalonia** | Cross-platform (reMarkable's user base skews Mac); reads as a current stack | Less tooling maturity; less training data; multi-platform packaging and CI; new framework to learn concurrently with restarting the project |
| **WinUI 3** | Microsoft's forward story for new Windows desktop | Still Windows-only; rockier tooling and packaging; smallest training corpus of the three |

The decisive consideration is **risk of stalling**, not framework currency. A seven-month
gap already cost this project its momentum once, and a project that never ships teaches
nothing. The skills actually worth rebuilding here — layered design, executable
architecture rules, test discipline, CI rigor, and running an AI-assisted workflow well —
are independent of the XAML dialect. WPF minimizes the chance of never finishing.

Avalonia is also deliberately WPF-shaped: the same XAML dialect and MVVM model. Learning
WPF well therefore makes a future Avalonia port a shell rewrite rather than a
re-education, so the learning is not stack-specific dead weight.

## Decision

Use **WPF on .NET 10** with MVVM, via the CommunityToolkit.Mvvm source generators.

Keep the shell deliberately thin. ViewModels orchestrate Application-layer calls and hold
no device, filesystem, or SSH knowledge — enforced by the architecture tests in
`overview.md` §7. All rendering and layout logic stays in the Domain `LayoutResolver`, so
the preview is computed by testable pure code and merely *drawn* by the UI
(see [ADR-0007](0007-preview-rendering.md)).

**This ADR is recorded precisely because the choice is contestable.** Picking a familiar
framework without examining the alternatives is the habit worth breaking; picking it with
the trade-off written down is the practice this project exists to rebuild.

## Revisit triggers

Reopen this decision if any of these occur:

- The cross-platform OneNote sync module (Phase 3+) becomes the primary product.
- Demand for macOS support materializes from real users.
- Microsoft announces an end-of-support date for WPF on a current LTS.

Because the Domain and Application layers are framework-free by construction, a port
replaces only `RmTemplateManager.Wpf`. The estimated blast radius is one project out of four.

## Consequences

**Good.** Fastest path to a running, visible application. Best AI code-generation quality
of the three options. Single-platform packaging ([ADR-0008](0008-installer-packaging.md))
and a single-platform CI matrix. Matches the existing PRD, so no spec churn.

**Costs.** Windows-only, forfeiting the Mac share of reMarkable owners. Some of what is
learned will be specific to a maintenance-mode framework — substantially offset by how
directly WPF's XAML and MVVM knowledge transfers to Avalonia.

**Constraints this imposes.** The preview renderer must work within WPF's drawing model
or an embedded surface. UI tests are limited to ViewModels; no cross-platform UI
automation. CI runs on `windows-latest` runners, which are slower and costlier in minutes
than Linux — acceptable for a project of this size.
