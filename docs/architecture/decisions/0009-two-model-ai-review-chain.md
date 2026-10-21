# ADR-0009 — Iterative two-model AI review, converging before human approval

- **Status:** Proposed — choice confirmed by the project owner 2026-10-21; flips to Accepted in the first PR, per ADR-0001
- **Date:** 2026-10-16

## Context

Nearly all code in this project will be written by AI agents. The point of the project is
to relearn disciplined development and to end up with a tool the author actually uses — so
**how** the code gets reviewed is part of what is being learned, not overhead around it.

The owner has two subscriptions: Claude (Claude Code) and ChatGPT (Codex CLI). Verified on
this machine: `codex-cli 0.161.0`, authenticated, with `codex exec` (non-interactive) and
`codex review` (non-interactive code review) — so a Codex gate can be scripted rather than
hand-driven.

Four forces shape the design:

1. **A single model reviewing its own work is a weak gate.** It shares the blind spots
   that produced the code. An independent model from a different vendor finds a genuinely
   different class of defect.
2. **One review round is not convergence.** A reviewer that returns findings has, by
   definition, found a change worth making — and changes introduce new risk. Stopping
   after one pass means the last edits in a branch are the least reviewed.
3. **Rules must be machine-checkable to survive.** Conventions living only in prose get
   ignored by cold-starting agents. This is why `overview.md` §7 makes layering an
   executable test.
4. **AI tooling is churning fast** ([ADR-0001](0001-record-architecture-decisions.md),
   Context point 3). Any specific arrangement of agents and gates will be obsolete within
   months; the *shape* should outlive the implementation.

## Decision

### The gates

| # | Gate | Runs | Mechanism |
|---|---|---|---|
| 1 | **Implement** | Claude Code | Feature branch, never `main`. Small, single-purpose changes. |
| 2 | **Persona review** | Claude subagents | `.claude/agents/` personas driven by `.claude/skills/` rule files: architecture, .NET code quality, test quality, device safety. |
| 3 | **CI proof** | GitHub Actions | Build, full test suite, architecture tests, format, coverage. Proves `main`'s integrity would hold. |
| 4 | **Independent review** | Codex CLI | `codex review` on the branch diff, driven by `AGENTS.md`. |
| 5 | **Human approval** | The owner | Required reviewer via `CODEOWNERS` + branch ruleset. **No merge to `main` without it, ever.** |

### Gates 2–4 iterate until clean

Gates 2, 3, and 4 form a **loop, not a sequence.** Any finding from either model sends the
branch back to gate 1 for changes, and the loop restarts from gate 2 — so reviewers always
assess the final state of the branch, never an intermediate one.

**The PR is not presented for human review until one complete round produces zero findings
from both Claude's personas and Codex.** A round is only clean if nothing was changed
during it.

Each round is recorded in the PR description: round number, what each reviewer raised, and
what changed. The convergence history is the useful part — it shows what the models caught
that the implementation missed.

### Loop guards

Two models can deadlock, so the loop needs limits:

- **Style disagreements are a documentation defect, not a per-PR argument.** If the two
  models disagree on a convention, the gap belongs in
  [`docs/coding-standards.md`](../../coding-standards.md): settle it once, write it down,
  and both models follow it from then on. Never re-litigate the same preference on a
  second PR.
- **After three rounds without convergence, stop and escalate** to the owner with both
  positions stated plainly and no resolution attempted. Genuine judgment calls are his to
  make, and three rounds of ping-pong is strong evidence that the disagreement is a
  judgment call rather than a defect.
- **Findings may be declined, not silently dropped.** A finding the implementer disagrees
  with is answered in the PR with reasoning. An unanswered finding blocks the round.

### Shared rulebook, two front doors

`CLAUDE.md` and `AGENTS.md` are thin pointers to the same canonical documents — this ADR
set, `PRD.md`, and `docs/coding-standards.md`. Both models obey one rulebook; duplicating
rules per tool guarantees they diverge.

### Codex runs locally, not in CI

Codex CLI authenticates with a personal ChatGPT subscription token (`~/.codex/auth.json`),
which refreshes and is not appropriate to copy into CI secrets. Gate 4 therefore runs on
the development machine during the loop, with its output recorded in the PR. This keeps
the second opinion visible in the PR conversation without putting subscription credentials
in a GitHub secret.

### The learning-capture loop

The mechanism that makes this a system rather than a checklist: **review feedback must
land in the rules, not just in the code.**

- A `/capture-learning` command takes a review comment and proposes the concrete edit to
  the relevant rule file that would prevent a recurrence. Routing:
  **coding conventions and idioms → `docs/coding-standards.md`;** structural or
  technology decisions → a new or superseding ADR; agent behavior → the relevant
  `.claude/skills/` file.
- `docs/learnings/` logs each captured lesson with the PR that produced it.
- A review comment is not resolved until *either* the code changed *or* a rule changed —
  ideally both. Fixing the instance while leaving the rule unwritten guarantees the next
  agent repeats the mistake.
- This applies to feedback on the PRD and architecture documents as much as to code. The
  revision history of [ADR-0008](0008-installer-packaging.md) is the first instance:
  owner feedback reversed a decision, and the reasoning was recorded rather than
  silently edited.

## Consequences

**Good.** Two independent models, plus executable rules, plus convergence before a human
looks, plus a human gate on every merge, is a stronger pipeline than most small teams run.
The iteration requirement closes the gap in force 2 — the owner reviews a branch that both
models have signed off on in its final state, so his attention goes to design and intent
rather than to defects a reviewer should have caught. Routing style disputes into the
coding standard means the loop gets cheaper over time instead of repeating itself.

**Costs.** Latency: several automated rounds before a human sees the work. Mitigated by
keeping changes small and by gates 2–4 running unattended. Two subscriptions to maintain.
Duplicated findings across gates 2 and 4 are expected and harmless.

**Risks.** The loop can thrash on trivia, burning tokens without improving the code — the
three-round escalation and the coding-standard routing exist to bound that. It can also
become theater if a gate is skipped under time pressure; a skipped gate must be stated in
the PR, never hidden. And "zero findings" can be gamed by reviewers that stop looking
hard; watch for rounds that go clean suspiciously early.

**Expected churn.** Per force 4, this ADR will likely be superseded several times. The
durable commitments are the *shape*: an independent second opinion, iteration to
convergence, machine-checkable rules, human approval on every merge, and feedback captured
into rules. The specific tools, agent definitions, and file layouts will all change.
