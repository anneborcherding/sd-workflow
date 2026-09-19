# SPEC-2: Security Reviewer Round Contract

**Status:** 🟢 Validated
**Version:** v1
**Created:** 2026-09-17
**Last Updated:** 2026-09-19

## Overview

Correct the shared security-reviewer persona so its declared input contract matches the mandatory
two-round Plan Review Workflow for every supported harness. Round 1 must review the original plan
independently; Round 2 must evaluate the revised plan with both independent Round 1 reviews and the
change log.

## Changelog

| Version | Date | Change | Driver |
|---------|------|--------|--------|
| v1 | 2026-09-17 | Initial spec, separated from Codex CLI support | — |

## Dependencies

- No implementation dependency on SPEC-1; the defect exists in the shared reviewer source for all
  harnesses.

## User Stories

### US-1: Independent first-round security review
**As a** workflow user **I want to** receive a security review uninfluenced by the architecture
review in round one **so that** the two reviewers identify risks independently.

### US-2: Cross-informed second-round security review
**As a** workflow user **I want to** have security re-evaluate the revised plan with both first-round
reviews **so that** cross-discipline changes are checked before implementation.

### US-3: Consistent behavior across harnesses
**As a** workflow maintainer **I want to** define the round contract once in the shared reviewer
source **so that** every compiled harness receives the same correct behavior.

## Acceptance Criteria

- [x] AC-1: `security-reviewer.agent.md` explicitly states that Round 1 receives only the original
  plan and relevant governing context and must not receive or assume the architecture review.
- [x] AC-2: The same reviewer explicitly states that Round 2 receives the revised plan, change log,
  Round 1 security review, and Round 1 architecture review.
- [x] AC-3: `plan-review-workflow.instructions.md` and the reviewer persona describe the same input
  contract without contradictory prose.
- [x] AC-4: Tests verify independent Round 1 and cross-informed Round 2 instructions in every
  supported compiled reviewer format without otherwise changing reviewer behavior.
- [x] AC-5: Documentation describing the review pipeline remains accurate across all harnesses.

## Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| EC-1 | The parent omits the round label | Reviewer requests or infers the minimum safe context without treating an architecture review as required in Round 1 |
| EC-2 | An architecture review is accidentally included in Round 1 | Reviewer flags the loss of independence rather than silently treating the run as compliant |
| EC-3 | One Round 1 review is unavailable in Round 2 | Reviewer reports incomplete cross-informed context and does not certify the missing discipline's findings as resolved |
| EC-4 | A harness transforms agent source into another format | The compiled artifact retains both round-specific contracts semantically |

## BDD Scenarios

### BDD-1: Round 1 remains independent
**Given** an original technical plan and relevant codebase context
**When** the security reviewer is invoked for Round 1
**Then** it evaluates the plan without receiving or relying on the architecture review.

### BDD-2: Round 2 is cross-informed
**Given** a revised plan, change log, and both completed Round 1 reviews
**When** the security reviewer is invoked for Round 2
**Then** it checks whether both disciplines' critical findings are resolved and whether either set of
changes introduced new security risks.

### BDD-3: Compiled harnesses preserve the contract
**Given** the shared reviewer source and each supported APM target
**When** reviewer artifacts are compiled or installed
**Then** each artifact retains the independent Round 1 and cross-informed Round 2 instructions.

## Out of Scope

- Codex skills, Codex installation, or Codex-specific reviewer packaging.
- Changing the number of review rounds or their pass/fail policy.
- Changing reviewer models or model-selection configuration.
- Redesigning the architecture-reviewer persona.

## Open Questions

_None._
