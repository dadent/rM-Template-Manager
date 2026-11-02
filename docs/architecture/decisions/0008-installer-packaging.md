# ADR-0008 — Minimal distribution; no installer

- **Status:** Proposed — revised draft confirmed by the project owner 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16
- **Revision:** Supersedes the first draft of this ADR (2026-10-16), which recommended
  adopting Velopack and running a half-day packaging spike. That draft was never accepted;
  it was revised after examining who will actually run this software. See "Why this was
  reversed" below.
- **Resolves:** open decision #5 in `research_scheduling.md` §15 and `PRD.md` §14.1
- **Conflicts with:** `PRD.md` §12.4, which mandates an MSI installer. The PRD must be
  amended at v2.0 if this ADR is accepted.

## Context

`PRD.md` §12.4 calls for a self-contained EXE **and** an MSI installer. That requirement
was written without asking who would install it. Asking changes the answer.

### Who actually runs this software?

Running it requires a reMarkable Paper Pro **in Developer Mode** — a state that factory-resets
the device and disclaims the warranty. That is a high bar, and it collapses the user list:

| Audience | Will they install it? |
|---|---|
| **The author** | Yes, repeatedly — after every firmware update. This is a tool he wants for himself. |
| **Anyone else** | Almost certainly not. It needs hardware they probably don't own, in a state they'd have to wipe the device to reach. No such users exist today, and recruiting them is not a goal of this project. |

So the realistic deployment target is **one machine, belonging to the person who builds
it.** An installer — Start Menu entry, uninstaller, update channel, signed MSI — is
infrastructure for distributing software to people. There is nobody to distribute to.

### What is worth building anyway?

Two things, and neither requires an installer framework:

- **A release pipeline.** Versioning, tagging, building, and publishing artifacts
  unattended is a skill worth practicing and a habit worth having. It is also what makes
  "which build am I running?" answerable. This is a `dotnet publish` step plus a workflow.
- **A demo recording.** Since nearly nobody can run this against real hardware, a short
  screen capture of the tool deploying templates to the actual device is the only way to
  show it working — to anyone curious, and to the author's own future reference. It costs
  far less than an installer and conveys far more.

## Decision

Distribute the minimum that serves the one real user.

1. **Publish a self-contained, single-file, win-x64 EXE** from the release workflow on
   every tagged release, starting at the walking skeleton. One `dotnet publish` step, no
   extra tooling.
2. **Attach SHA-256 checksums** and auto-generated release notes to each release.
3. **Build no installer.** No Velopack, no WiX, no MSIX, no Inno Setup.
4. **Buy no code-signing certificate.** $200–400/year plus a reputation ramp before
   SmartScreen warnings subside, to smooth an install nobody is performing. Note the
   warning honestly in the README instead.
5. **Record a short demo** of the tool working against the device once there is something
   worth showing.

### Reduced verification (replaces the half-day spike)

One thing still needs confirming, and it is needed regardless: **WPF single-file
self-contained publishing on .NET 10.** WPF has historically had single-file caveats, so
this gets verified during the walking skeleton — roughly an hour, inside work already
planned. If it misbehaves, fall back to a zipped framework-dependent build. That fallback
is entirely acceptable here and needs no new decision.

## Why this was reversed

The first draft assumed "someone should be able to download and run this in seconds" was a
requirement, and sequenced an installer in before the first feature release. That premise
does not survive the hardware prerequisite: essentially nobody *can* run it, with or
without an installer. Once that is stated plainly, installer work is effort spent on a
path no one will take, and the demo recording is revealed as the thing that path was
meant to accomplish.

Recording the reversal rather than quietly editing it is deliberate. The reasoning is more
useful than the conclusion, and noticing that a requirement had never been justified is
the kind of thing [ADR-0001](0001-record-architecture-decisions.md) exists to capture.

## Revisit triggers

Reopen this decision if any of these occur:

- Real external users appear — a GitHub issue asking for an installer is the clearest signal.
- The project is ever positioned as a product rather than a personal tool.
- Deployment to a second machine the author does not control becomes necessary.

Because step 1 keeps a working release pipeline in place, adding an installer later means
adding one job to an existing workflow, not building distribution from nothing. Nothing
here is expensive to reverse.

## Consequences

**Good.** Zero packaging tooling to learn, configure, or maintain. A runnable, versioned
artifact exists from the first milestone, so there is never a build the author cannot
reach. The release pipeline — the genuinely useful part — still gets built. Several days
of effort move to the architecture, the test suite, and the review workflow, which is
where the learning actually is.

**Costs.** No Start Menu entry, no uninstaller, no auto-update; the author launches an EXE
from a folder. For one user on one machine, a non-issue. Unsigned binaries show a
SmartScreen warning, acknowledged in the README rather than paid to avoid.

**Honest trade-off.** This forfeits hands-on experience with installer authoring and code
signing specifically. A real but narrow loss, accepted because the same hours spent on
domain design, test depth, and the review pipeline teach more.
