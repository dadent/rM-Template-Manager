# ADR-0001 — Record architecture decisions as ADRs

- **Status:** Proposed — choice confirmed by the project owner 2026-10-21; flips to Accepted in the first PR, per this ADR's own rule
- **Date:** 2026-10-16

## Context

This project is built mostly by AI agents across many sessions, reviewed by a second
model, and approved by one human. Three failure modes follow from that:

1. **Context loss.** A seven-month gap already proved that undocumented reasoning
   evaporates. Agents starting cold re-derive — or silently contradict — past decisions.
2. **Unexamined judgment.** Code records *what* was decided but never *why*. A decision
   whose reasoning cannot be reconstructed is one nobody learned from, and it cannot be
   challenged or improved later — not by a future session, and not by the author himself.
3. **Churn in the AI tooling itself.** AI software development tools and the best
   practices for using them are changing rapidly — faster than this product will be
   built. Decisions about agents, skill files, review gates, and model roles have a short
   half-life and will be revisited repeatedly, on a cadence driven by the industry rather
   than by our roadmap. Some of today's choices will look obsolete within months, and that
   is expected rather than a sign of poor judgment.

A single large design document is the wrong container for all three. It failed us once
already: `PRD.md` buried its architecture in §10.4, where no decision could be revisited
without editing the product spec. Point 3 makes it worse — a monolith forces unrelated,
stable decisions (merge semantics, device safety) to be re-opened and re-reviewed every
time a volatile one (which model reviews PRs, how skills are structured) changes. Small,
independently versioned records let the fast-moving decisions churn freely without
destabilizing the slow-moving ones, and make the *rate* of change on each visible.

## Decision

Record every significant technical decision as a numbered, immutable ADR in
`docs/architecture/decisions/`, using the lightweight Nygard format: Context, Decision,
Consequences.

- Files are named `NNNN-kebab-case-title.md` and numbered sequentially.
- Status is one of `Proposed`, `Accepted`, `Rejected`, `Superseded by ADR-NNNN`.
- **Once `Accepted`, ADRs are append-only.** A reversed decision gets a new ADR that
  supersedes the old one; accepted text is never rewritten. The history of being wrong is
  the valuable part.
- **While still `Proposed`, an ADR may be revised in place** — it is a draft under review,
  and review exists to change it. Record what changed and why in a `Revision:` line in the
  header, so the reasoning survives even though the text did not.
- An ADR moves from `Proposed` to `Accepted` only by human approval in a PR review.
- Agents MUST read the register in `docs/architecture/overview.md` §9 before proposing
  design changes, and MUST write an ADR rather than quietly deciding.

## Consequences

**Good.** Decisions survive session boundaries and model changes. Review happens at the
decision, not after 2,000 lines of code assume it. The `Proposed` → `Accepted` transition
is a natural, low-friction human approval gate. Reviewers can read the project's reasoning
without reading its source.

**Costs.** Overhead per decision, and judgment required about what counts as
"significant." Rule of thumb: if reversing it later would mean changing more than one file,
or if a reasonable engineer would ask "why did you do it *that* way?", it needs an ADR.

**Risk.** ADRs that drift out of date are worse than none. Mitigated by append-only
supersession and by treating a stale ADR as a reviewable defect. Given the churn described
in Context point 3, expect the AI-workflow ADRs to be superseded several times over the
life of the project; a chain of superseding ADRs on the same topic is a healthy signal,
not a mess to clean up.
