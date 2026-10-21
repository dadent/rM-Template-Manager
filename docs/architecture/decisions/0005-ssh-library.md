# ADR-0005 — Use SSH.NET for SSH and SCP transport

- **Status:** Proposed — choice confirmed by the project owner 2026-10-21, including the SCP-first transfer decision; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16

## Context

The application's only channel to the device is SSH: run commands (`mount -o remount,rw /`,
firmware/battery/disk probes, reboot) and move files both ways (SCP). Authentication is
**password-based**, non-interactive, with the password supplied by the user per session
(`PRD.md` §3.2).

A correction to earlier research: `research/.../Research-and-Plan.md` §15 and
`research_scheduling.md` §15 list "SSH.NET" and "Renci.SshNet" as if they were two
candidates. They are the same library — `Renci.SshNet` is SSH.NET's root namespace and
NuGet package ID. There are really only three options.

| Option | For | Against |
|---|---|---|
| **SSH.NET** (`SSH.NET` / `Renci.SshNet`) | De facto .NET standard; MIT; `SshClient` + `ScpClient` + `SftpClient` in one package; non-interactive password auth is first-class; pure managed, no native deps | Historically uneven release cadence; async surface is partial in places and needs wrapping |
| **Shell out to Windows OpenSSH** (`ssh.exe`/`scp.exe`, built into Windows 10+) | Zero dependencies; battle-tested binaries; nothing to vendor | **Disqualifying:** OpenSSH offers no non-interactive password mechanism on Windows. There is no `sshpass` equivalent, and `ssh` reads the password from the console directly, not stdin. Would force key-based auth, which `PRD.md` §14.2 explicitly excludes. Also brittle: output parsing, exit-code mapping, and process lifetime management. |
| **Commercial libraries** (Rebex, etc.) | Polished, well-supported, fully async | Paid, and a closed-source dependency sits awkwardly in a public Apache-2.0 repository |

The password-auth requirement is decisive: it eliminates the OpenSSH option outright.

## Decision

Use **SSH.NET** (MIT), referenced by exactly one file —
`Infrastructure/Ssh/SshTransport.cs` — implementing the `ISshTransport` interface declared
in the Application layer.

- The architecture test suite asserts no type outside `Infrastructure` references
  `Renci.SshNet`, so the library cannot leak upward (`overview.md` §7).
- Wrap the library's synchronous calls behind a genuinely `async` + cancellable
  `ISshTransport` surface, so the UI contract in `PRD.md` §9.4 holds regardless of what
  SSH.NET supports natively.
- Pin an exact version; let Dependabot propose upgrades through the normal PR gate.
- Host-key handling is an explicit decision, not a default: on first connect, present the
  fingerprint to the user and persist it for comparison on later connects. Never
  blind-accept silently.

## Consequences

**Good.** One small adapter is the entire blast radius if the library is ever replaced.
Password auth works as the PRD requires. MIT is compatible with
[ADR-0004](0004-apache-2-license.md). Mocking `ISshTransport` means every Application-layer
workflow — including rollback paths — is testable with no tablet attached.

**Costs.** A dependency whose maintenance pace we do not control. Wrapping sync APIs in
`Task.Run` is a known smell; it is contained to one file and documented there.

**Risks.** A `ScpClient` quirk could corrupt a binary or text transfer. Mitigated by
post-upload verification in the deployment lifecycle (`PRD.md` §8.3 step 7) — we read back
and compare rather than trusting the write.

## File transfer: SCP first, SFTP as the fallback

*Decided 2026-10-21 by the project owner; this replaces the open sub-question in the
original draft.*

Both protocols ship in SSH.NET, so this is a choice of `ScpClient` vs `SftpClient`, not a
dependency decision.

**Start with SCP.** It matches the existing manual workflow — the one already proven
against this device — and the PRD's wording. Fidelity to a known-good process is worth
more at the outset than protocol elegance, because any transfer failure during early
development is then almost certainly our code rather than an unfamiliar protocol path.

**Switch to SFTP if SCP causes trouble.** Concretely, any of these is a trigger:

- Post-upload verification (lifecycle step 7) proves awkward — SFTP exposes `stat`, so
  size and existence checks come for free rather than needing a shell command.
- Transfers corrupt or mangle content, particularly around encoding or binary data.
- OpenSSH on the device deprecates or disables the SCP protocol in a future firmware.
  (Upstream OpenSSH has already moved `scp` onto SFTP internally; a reMarkable firmware
  that follows suit would force this.)

Because both clients sit behind `ISshTransport`, switching is a change to one file with no
ripple into Application or Domain. Budget: a few hours, not a redesign.
