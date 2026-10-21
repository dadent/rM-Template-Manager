# ADR-0004 — License the repository under Apache-2.0

- **Status:** Proposed — choice confirmed by the project owner 2026-10-16, document reviewed 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16

## Context

The repository is already public and currently has **no license file at all**, which is
the worst of both worlds: visitors have no legal right to use the code, and the omission
reads as an oversight rather than a choice.

The October 2026 research recommended a source-available license (FSL-1.1 or PolyForm
Noncommercial) to protect future revenue. That recommendation was aimed at the **OneNote
sync engine**, which is the genuinely monetizable component — and which
`overview.md` §10 places in a separate, private repository.

For Template Manager specifically, the protective argument is weak. The comparable
product (RCU) sells for $12, so there is little revenue to defend — and a familiar
permissive license means anyone who reads this repository, including the author in two
years, needs no explanation of what they may do with it.

## Decision

License this repository under **Apache-2.0**.

- Add `LICENSE` at the repository root.
- Add `NOTICE` with the copyright line.
- Set the license in project metadata so it propagates to build artifacts.

Keep the monetizable sync engine in a separate private repository under a proprietary
license. Licensing is decided **per repository**, and this ADR governs only this one.

## Consequences

**Good.** Unambiguous and universally understood. Apache-2.0 grants an explicit patent
license and is accepted without question inside corporations, so nobody has to think about
it. It is compatible with the permissive dependencies this project will use.

**Costs.** Anyone may use this code commercially, including building a competing template
manager. Accepted: the value here is the learning and the tool itself, not exclusivity.

**Constraints this imposes.**

- **Do not copy code from GPL/AGPL projects** (RCU is AGPLv3, rmOneNoteSync is GPL-3.0)
  into this repository. Reading them for understanding is fine; copying is not.
- Check every dependency's license before adding it; prefer MIT/Apache/BSD.
- Add a DCO sign-off requirement before accepting any outside contribution, so the right
  to relicense is preserved.

**Not decided here.** Product naming and the "reMarkable" trademark question are separate
and still open; a license does not grant trademark rights.
