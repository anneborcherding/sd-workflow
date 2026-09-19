# SPEC-1: Codex CLI Support

**Status:** 🟢 Validated
**Version:** v1
**Created:** 2026-09-17
**Last Updated:** 2026-09-17

## Overview
Add first-class Codex CLI support to the APM package so Codex users can invoke every workflow phase,
run the mandatory independent architecture and security reviews, inherit the workflow rules, and
retain the same git-enforced lifecycle as existing harnesses. The integration must use Codex-native
skills and custom agents while preserving all consumer-owned files and keeping existing harness
output unchanged.

## Changelog

| Version | Date | Change | Driver |
|---------|------|--------|--------|
| v1 | 2026-09-17 | Initial spec | — |

## Dependencies

- Requires APM 0.31.0 or later for the Codex target, shared `.agents/skills` deployment, and
  `.codex/agents` compilation.
- Has no dependency on another product spec.

## User Stories

### US-1: Invoke the full workflow in Codex
**As a** Codex CLI user **I want to** invoke native equivalents of every workflow command **so that**
I can complete requirements, design, implementation, verification, and close-out without changing
harnesses.

### US-2: Receive independent plan reviews
**As a** Codex CLI user **I want to** run the architecture and security reviewers as Codex subagents
**so that** the mandatory two-round review pipeline remains independent and enforceable.

### US-3: Adopt safely in an existing repository
**As a** repository owner **I want to** install and update Codex support without overwriting my
instructions, skills, agents, configuration, specifications, or other project data **so that** I can
adopt the workflow without destructive migration.

### US-4: Maintain existing harness compatibility
**As a** workflow maintainer **I want to** add Codex-specific output without changing other target
behavior **so that** current Claude, OpenCode, Cursor, and Copilot users do not regress.

## Acceptance Criteria

- [x] AC-1: Installing the package for APM's `codex` target on APM 0.31.0 or later deploys usable
  Codex skills equivalent to `requirements`, `technical-design`, `write-tests`, and
  `frontend-architecture`, with valid `SKILL.md` metadata and complete workflow instructions.
- [x] AC-2: A Codex CLI user can explicitly discover and invoke each deployed workflow through
  Codex's supported skill interface, and the documentation maps the former slash-command names to
  their Codex equivalents.
- [x] AC-3: The `architecture-reviewer` and `security-reviewer` compile unchanged into valid
  project-scoped `.codex/agents/*.toml` definitions that Codex can invoke as separate parallel
  subagents according to the inputs assigned by the existing Plan Review Workflow.
- [x] AC-4: Codex receives all applicable global and path-scoped workflow instructions through its
  supported project-instruction mechanism, including the security rule for `.env*` and API work.
- [x] AC-5: A fresh Codex-target installation includes the same living templates, enforcement
  scripts, configuration, and explicit setup behavior as other supported targets.
- [x] AC-6: Normal installation and update without APM's explicit `--force` override never replace,
  truncate, delete, or silently merge pre-existing
  consumer-owned `AGENTS.md`, `AGENTS.override.md`, `.agents/skills/**`, `.codex/agents/**`,
  `.codex/config.toml`, Codex hooks/settings, PRD, specs, security rules, context map, supplemental
  rules, or workflow configuration.
- [x] AC-7: Package-owned managed output is refreshed only when ownership is unambiguous; any
  collision that cannot be resolved losslessly fails safely or produces a precise entry in
  `.spec-workflow/MANUAL-STEPS.md` without modifying the conflicting user file.
- [x] AC-8: Re-running setup and update is idempotent: user-owned bytes remain unchanged, the marked
  workflow section is not duplicated, retired package-owned artifacts are handled only according to
  the existing managed-file policy, and no duplicate Codex primitive is created.
- [x] AC-9: Automated tests cover fresh Codex deployment, repeat deployment, every protected-file
  collision class, valid skill and agent structure, review-agent availability, and unchanged output
  or behavior for Claude, OpenCode, Cursor, and Copilot fixtures.
- [x] AC-10: The README states the APM 0.31.0+ Codex requirement, installation and setup steps,
  Codex skill invocations, reviewer behavior, file ownership rules, limitations, and a reproducible
  verification procedure.

## Edge Cases

| # | Scenario | Expected Behavior |
|---|----------|-------------------|
| EC-1 | A consumer already has an `AGENTS.md` without the workflow marker | Existing content remains byte-for-byte intact; the current consent/manual-step flow governs adding the marked section |
| EC-2 | `AGENTS.override.md` exists and may shadow `AGENTS.md` | The installer does not modify it and documentation warns that Codex precedence can suppress broader instructions |
| EC-3 | A user skill has the same name as a workflow skill | Installation does not overwrite either skill or leave ambiguous package ownership; it stops safely or reports an actionable manual resolution |
| EC-4 | A user custom agent has the same name as a reviewer | Installation preserves the user agent and stops safely or records an actionable collision instead of silently changing review semantics |
| EC-5 | `.codex/config.toml` contains unrelated or newer settings | All existing bytes and settings remain untouched unless a proven lossless, narrowly scoped merge is explicitly required by the design |
| EC-6 | Setup is run repeatedly or after `apm update` | The result contains one copy of each package-owned primitive and no changes to consumer-owned data |
| EC-7 | APM is older than 0.31.0 | Documentation and/or setup reports that Codex support requires 0.31.0+ without breaking an existing non-Codex installation |
| EC-8 | Codex subagents are disabled by consumer configuration | Files install without changing that choice; verification reports the prerequisite and documentation explains how it affects mandatory reviews |
| EC-9 | Another supported harness is installed alongside Codex | Both targets receive their native artifacts and existing harness behavior remains unchanged |
| EC-10 | Codex is launched below the repository root | Repo-scoped skills and layered `AGENTS.md` instructions remain discoverable according to Codex's documented lookup rules |

## BDD Scenarios

### BDD-1: Fresh Codex installation exposes the workflow
**Given** a repository with a Codex harness marker, APM 0.31.0 or later, and no prior workflow files
**When** the package is installed for the Codex target and its explicit setup is run
**Then** all four workflow skills, both reviewer agents, workflow instructions, living templates,
and git enforcement are available in their documented locations.

### BDD-2: Codex completes independent plan review
**Given** a spec with an initial technical design and both Codex reviewer agents installed
**When** Codex runs the mandatory Plan Review Workflow
**Then** Codex invokes architecture and security as separate subagents in each round, supplies the
round-specific context required by the existing Plan Review Workflow, and does not recommend
implementation while a critical finding remains unresolved.

### BDD-3: Existing user data survives installation
**Given** a repository containing user-authored project instructions, Codex configuration, skills,
agents, specs, and workflow living files
**When** the package is installed, set up, and updated
**Then** every consumer-owned file's pre-existing prose/data remains unchanged and every unresolved
name collision is reported without destructive writes; an explicitly forced APM install is outside
this guarantee because it is deliberate destructive authorization.

### BDD-4: Setup is idempotent
**Given** a completed Codex-target installation
**When** the same package setup is run again
**Then** no workflow section, skill, agent, hook, configuration entry, or manual-step entry is
duplicated and managed artifacts remain valid.

### BDD-5: Existing harnesses do not regress
**Given** fixtures for Claude, OpenCode, Cursor, and Copilot with their current workflow output
**When** Codex support is installed or the package's regression suite is run
**Then** all pre-existing harness-specific behaviors and preservation guarantees still pass.

### BDD-6: Unsupported APM version is explained safely
**Given** a consumer attempting Codex installation with APM older than 0.31.0
**When** they follow the Codex setup documentation or encounter the version check
**Then** they receive a clear upgrade instruction and no existing non-Codex workflow data is changed.

## Out of Scope

- Codex app-only behavior that is not also supported by Codex CLI.
- Publishing this workflow as an OpenAI plugin or through a separate marketplace.
- Selecting, downloading, or requiring a particular Codex model.
- Modifying a consumer's global `~/.codex` or `~/.agents` files.
- Redesigning the shared specification lifecycle or git enforcement semantics.
- Correcting the shared security-reviewer persona's contradictory round-input wording; tracked
  independently in a future follow-up.

## Open Questions

_None._
