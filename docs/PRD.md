# Product Requirements Document

## Vision
Spec-Driven Workflow keeps AI coding agents on a traceable, enforceable path from requirements to
verified implementation. It packages one agent-agnostic workflow through Microsoft APM so teams can
use the same specifications, review gates, testing evidence, and git enforcement across supported
coding-agent harnesses without surrendering their existing project data or configuration.

## Target Users

| Persona | Context | Primary Use Case |
|---------|---------|-----------------|
| **Development team** | Maintains software with one or more AI coding-agent harnesses | Apply a consistent, auditable specification and delivery workflow across tools |
| **Codex CLI user** | Works locally with Codex in an existing repository | Invoke every workflow phase and its independent reviewers through native Codex mechanisms without losing existing files or settings |
| **Workflow maintainer** | Publishes and upgrades the APM package | Evolve harness support without regressing existing targets or overwriting consumer-owned data |

## Core Features (Roadmap)

> **Status lives in [`specs/INDEX.md`](../specs/INDEX.md), the single source of truth.**
> This roadmap intentionally carries no Status column — it would only drift. See INDEX for each
> spec's current lifecycle state (In Planning → Planned → In Progress → In Review → Validated).

| Priority | ID | Spec | File |
|----------|----|------|------|
| P0 (MVP) | SPEC-1 | Codex CLI Support | [Spec](../specs/SPEC-1-codex-support/spec.md) |
| P0 (MVP) | SPEC-2 | Security Reviewer Round Contract | [Spec](../specs/SPEC-2-security-reviewer-round-contract/spec.md) |

## Success Metrics
- APM installs every workflow primitive into locations recognized by each supported harness.
- Every supported harness can complete requirements, reviewed technical design, implementation,
  verification, and close-out without harness-specific gaps.
- Re-running installation or update preserves consumer-owned content and configuration.
- Automated packaging and behavioral tests detect placement, collision, preservation, and existing-
  harness regressions before release.

## Constraints
- Keep the core workflow agent-, language-, framework-, and design-system-agnostic.
- Codex support requires APM 0.31.0 or later; existing non-Codex behavior remains compatible.
- Installation must remain explicit, auditable, idempotent, dependency-light, and free of network
  access in the setup script.
- Git and `jq` remain the only setup-time executable dependencies.

## Non-Goals
- Building a Codex app-only experience beyond capabilities shared with Codex CLI.
- Replacing APM with a separate installer or distribution channel.
- Selecting or requiring a particular Codex model.
- Adding stack-, framework-, or product-design conventions to the core workflow.

## Open Questions
<!-- Project-level decisions nobody has settled. `/requirements` records them here — instead of
     asking the terminal — when `interaction.mode` is "file" in .spec-workflow/config.json, noting
     what it ASSUMED and built the PRD on; you fill in **Answer:** (your choice, or "confirmed").
     These are the widest-blast-radius questions there are ("is a backend needed?"), so while one is
     unanswered NO spec may advance past 🔵 In Planning — check-open-questions.sh enforces it.
     Answered questions STAY here as the decision record.
     Delete this section if there is nothing open.

### Q-1: _The decision, as a question_
- (a) _Option — trade-off_
- (b) _Option — trade-off_
**Assumed:** _(b), because …_
**Answer:**
-->
_None._

---

**Governing context:** see `.spec-workflow/context-map.md` for where this project's
architecture, security, and other context lives (repo files by default — e.g. `ARCHITECTURE.md` — or
an external tool / MCP provider).

Use `/requirements` to create a detailed spec for each item in the roadmap above.
