# SPEC-2: Security Reviewer Round Contract — Audit Trail

**Branch:** `SPEC-2-security-reviewer-round-contract`
**Commits:** `e9fec85804bc0ea408fc7f5dfb775d934cad5366..1f65e3c` (inherited SPEC-1 history; SPEC-2 implementation is currently uncommitted)
**Verified:** 2026-09-19

## Summary

The shared security-reviewer persona now declares independent Round 1 and cross-informed Round 2
contracts, rejects ambiguous, contaminated, and incomplete review context without certifying it, and
limits architecture-review analysis to valid Round 2 input. The matching workflow instruction,
generated Codex skill, README, and new packaging test preserve those semantics across every supported
APM target.

## Acceptance Criteria — evidence

| AC | Evidence | Where |
|----|----------|-------|
| AC-1 | The canonical contract assertion verifies Round 1 accepts only `Original Plan` and `Relevant Context`, excludes architecture review, and rejects contamination. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| AC-2 | The canonical contract assertion verifies all four Round 2 inputs and non-certifying behavior when a Round 1 review is missing. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| AC-3 | The workflow-alignment assertion verifies independent Round 1 payloads and complete, certifying Round 2 requirements. | `tests/security-reviewer-contract.test.sh::plan-review workflow aligns with the reviewer contract` |
| AC-4 | Isolated APM 0.31 compilation fixtures assert the contract in Claude, OpenCode, Cursor, Copilot, and Codex reviewer artifacts. | `tests/security-reviewer-contract.test.sh::Compiled reviewer matrix` |
| AC-5 | README documents the two-round contract and lists the cross-harness contract suite; generated Codex skills passed their freshness check. | `README.md`, `tests/codex-support.test.sh::Generated skill contract` |

## Edge Cases — evidence

| EC | Evidence | Where |
|----|----------|-------|
| EC-1 | Contract assertion verifies that an absent round label may infer Round 1 only from the unambiguous original-plan/context shape; every other shape is invalid. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| EC-2 | Contract assertion verifies contaminated Round 1 input is non-certifying and must not rely on architecture review. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| EC-3 | Contract assertion verifies a missing Round 1 review prevents a certifying Round 2 verdict or cross-discipline closure. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| EC-4 | Five compiled reviewer artifacts retain the semantic markers and omit the obsolete unconditional architecture-review contract. | `tests/security-reviewer-contract.test.sh::Compiled reviewer matrix` |

## BDD Scenarios — evidence

| BDD | Evidence | Where |
|-----|----------|-------|
| BDD-1 | The canonical contract assertion checks independent Round 1 context and the absence of architecture-review reliance. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| BDD-2 | The canonical contract assertion checks the revised plan, change log, both Round 1 reviews, and cross-discipline closure handling. | `tests/security-reviewer-contract.test.sh::assert_contract (shared security reviewer)` |
| BDD-3 | The five-target APM matrix installs the local package for every supported target and checks each emitted reviewer artifact. | `tests/security-reviewer-contract.test.sh::Compiled reviewer matrix` |

## Test run

- Command: `bash tests/security-reviewer-contract.test.sh`
- Result: 7 passed, 0 failed, 0 skipped (APM 0.31.0; Claude, OpenCode, Cursor, Copilot, and Codex)
- Command: `bash tests/codex-support.test.sh`
- Result: 22 passed, 0 failed, 0 skipped
- Command: `bash tests/enforcement.test.sh`
- Result: 107 passed, 0 failed, 0 skipped
- Run against: working tree at `1f65e3c` with uncommitted SPEC-2 changes

## Deviations & follow-ups

None. The audit records an uncommitted implementation state; update the commit range when SPEC-2 is
committed.
