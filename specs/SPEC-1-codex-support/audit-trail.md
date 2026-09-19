# SPEC-1: Codex CLI Support — Audit Trail

**Branch:** SPEC-1-codex-support
**Commits:** `e9fec85804bc0ea408fc7f5dfb775d934cad5366..HEAD` (no feature commits yet; evidence was collected from the working tree)
**Verified:** 2026-09-17

## Summary

Added first-class Codex CLI packaging through five Agent Skills, existing APM-compiled reviewer
agents, safe Codex model stamping with drift provenance, preservation/path-safety checks, and Codex
installation/invocation documentation. The shared security-reviewer wording defect discovered during
review was deliberately excluded for a future follow-up. Verification used APM
0.31.0 against isolated consumers; no network service, global Codex state, or forced installation was
used.

## Acceptance Criteria — evidence

| AC | Evidence | Where |
|----|----------|-------|
| AC-1 | APM deployed all five valid skills, including the four entry points | `tests/codex-support.test.sh::APM Codex deployment` |
| AC-2 | Generated names/metadata passed and no legacy slash invocation remained | `tests/codex-support.test.sh::Generated skill contract` |
| AC-3 | Both unchanged reviewer sources compiled to distinct Codex TOML agents; parent orchestration was exercised by the mandatory two-reviewer design review | `tests/codex-support.test.sh::APM deploys all skills and reviewer agents` |
| AC-4 | Seeded `AGENTS.md` requires the installed shared-rules skill, whose generated rules passed synchronization and invocation validation | `tests/codex-support.test.sh::seeded AGENTS.md requires shared workflow rules` |
| AC-5 | Fresh explicit setup succeeded and deployed living/enforcement artifacts in an isolated Codex consumer | `tests/codex-support.test.sh::explicit setup succeeds for Codex` |
| AC-6 | Existing instructions, overrides, Codex config, unrelated skills/agents, and same-name primitive collisions remained unchanged | `tests/codex-support.test.sh::setup preserves existing Codex and instruction data` |
| AC-7 | APM skipped user collisions; model drift and symlinked managed paths failed closed | `tests/codex-support.test.sh::skill collision is skipped without overwriting user data` |
| AC-8 | Repeated setup was byte-stable, the marked section was not duplicated, and model provenance allowed only known transformations | `tests/codex-support.test.sh::same-model setup is byte-stable` |
| AC-9 | Dedicated Codex suite passed packaging, metadata, preservation, collision, version, provenance, mixed-harness, and legacy regression checks | `tests/codex-support.test.sh` |
| AC-10 | README documents APM 0.31+, install/setup, skill mappings, reviewer/model behavior, ownership, `--force`, limitations, official references, and test commands | `README.md` |

## Edge Cases — evidence

| EC | Evidence | Where |
|----|----------|-------|
| EC-1 | Existing unmarked `AGENTS.md` was preserved and produced an actionable manual step | `tests/codex-support.test.sh::unmerged AGENTS.md produces an actionable manual step` |
| EC-2 | Existing `AGENTS.override.md` remained unchanged; precedence is documented | `tests/codex-support.test.sh::setup preserves existing Codex and instruction data` |
| EC-3 | Same-name user skill was skipped without overwrite | `tests/codex-support.test.sh::skill collision is skipped without overwriting user data` |
| EC-4 | Same-name reviewer agent was skipped without overwrite | `tests/codex-support.test.sh::reviewer-agent collision is skipped without overwriting user data` |
| EC-5 | Existing `.codex/config.toml` remained byte-identical | `tests/codex-support.test.sh::setup preserves existing Codex and instruction data` |
| EC-6 | Repeated setup preserved output and known model transformation state | `tests/codex-support.test.sh::same-model setup is byte-stable` |
| EC-7 | Simulated APM 0.30.9 stopped setup before creating `.spec-workflow` | `tests/codex-support.test.sh::unsupported APM version fails before setup writes` |
| EC-8 | Existing Codex configuration is never rewritten, including a consumer's subagent choice | `tests/codex-support.test.sh::setup preserves existing Codex and instruction data` |
| EC-9 | Combined Codex and Claude target installation produced both artifact families | `tests/codex-support.test.sh::mixed Codex and legacy harness deployment succeeds` |
| EC-10 | Skills are installed at repository scope under `.agents/skills`, which Codex officially discovers from nested working directories | `tests/codex-support.test.sh::APM deploys all skills and reviewer agents` |

## BDD Scenarios — evidence

| BDD | Evidence | Where |
|-----|----------|-------|
| BDD-1 | Fresh local APM install plus explicit setup produced five skills, two agents, living files, and enforcement | `tests/codex-support.test.sh::APM Codex deployment` |
| BDD-2 | The completed mandatory review ran distinct architecture/security agents in both rounds; offline packaging verified both project agents | `tests/codex-support.test.sh::APM deploys all skills and reviewer agents` |
| BDD-3 | Preservation fixture and same-name collisions retained every user sentinel | `tests/codex-support.test.sh::setup preserves existing Codex and instruction data` |
| BDD-4 | Consecutive setup/model runs were byte-stable and safely supported model A → B | `tests/codex-support.test.sh::same-model setup is byte-stable` |
| BDD-5 | Existing enforcement suite passed 107 checks; mixed Codex/Claude deployment succeeded | `tests/enforcement.test.sh` |
| BDD-6 | Old-APM fixture exited before setup mutations | `tests/codex-support.test.sh::unsupported APM version fails before setup writes` |

## Test run

- Command: `jq -e . .apm/live-seed/config.schema.json; bash -n .apm/scripts/*.sh .apm/scripts/pre-commit tests/*.sh; bash .apm/scripts/sync-codex-skills.sh --check; git diff --check; bash tests/codex-support.test.sh`
- Result: 22 Codex-support checks passed, 0 failed, 0 skipped; nested legacy suite passed 107, failed 0, skipped 0. JSON parsing, shell syntax, generated-skill synchronization, and diff whitespace checks also passed.
- Run against: branch `SPEC-1-codex-support`, working tree based on `e9fec85804bc0ea408fc7f5dfb775d934cad5366`

## Deviations & follow-ups

- The shared security-reviewer persona contract is a general cross-harness issue, not part of Codex
  packaging. It remains unchanged here for a future follow-up.
- Lockfile and model-state provenance protect against accidental collision and ordinary drift, not an
  actor who can coherently forge all repository metadata.
- Agent-file and provenance-ledger renames cannot form one cross-file atomic transaction; an
  interruption fails closed and requires restoring the APM baseline before retrying.
