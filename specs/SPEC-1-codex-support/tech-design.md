# SPEC-1: Codex CLI Support — Tech Design

**Designed:** 2026-09-17
**Services:** APM primitive sources, installer/model emitter, enforcement test suite, documentation

### Current-State Findings

- APM 0.31.0 recognizes `codex` as a target.
- Installing the current package for that target emits valid project-scoped reviewer definitions at
  `.codex/agents/architecture-reviewer.toml` and `.codex/agents/security-reviewer.toml`.
- `apm compile --target codex` can compile workflow instructions into a generated `AGENTS.md`, but
  APM correctly preserves a hand-authored root `AGENTS.md` and therefore emits no replacement. The
  package must support both states without claiming that skipped instructions were installed.
- The current `.apm/prompts/*.prompt.md` files are not emitted as Codex skills, leaving Codex without
  native entry points for the four workflows.
- APM 0.31.0 supports multi-skill packages at `.apm/skills/<name>/SKILL.md` and deploys them to the
  shared `.agents/skills/<name>/SKILL.md` location used by Codex CLI.
- The installer detects Codex agents only to report model stamping as unsupported, although current
  Codex custom-agent TOML supports `model` and `model_reasoning_effort`.

### Primitive Architecture

Keep the existing `.apm/prompts/*.prompt.md` files as the canonical workflow sources for existing
harnesses. Add four generated Codex-compatible entry-point skills plus one shared-rules skill:

```text
.apm/
├── prompts/
│   ├── requirements.prompt.md                 # canonical workflow body
│   ├── technical-design.prompt.md
│   ├── write-tests.prompt.md
│   └── frontend-architecture.prompt.md
├── skills/
│   ├── requirements/SKILL.md                 # generated, committed
│   ├── technical-design/SKILL.md
│   ├── write-tests/SKILL.md
│   ├── frontend-architecture/SKILL.md
│   └── spec-driven-workflow/SKILL.md          # generated shared rules
└── scripts/
    ├── codex-primitives.tsv                   # reviewed public mapping
    └── sync-codex-skills.sh                   # deterministic generator/checker
```

`codex-primitives.tsv` explicitly records each public skill name, trusted description, canonical
source file(s), and permitted invocation-token substitutions. Each entry-point skill has only the
Agent Skills fields `name` and `description` in its YAML frontmatter. Its body is derived from the
corresponding prompt after frontmatter, with a deliberately small substitution table that changes
user-facing `/requirements`, `/technical-design`, `/write-tests`, and `/frontend-architecture`
references to their `$...` Codex forms. Shared prose should be made harness-neutral at the source
when that does not alter existing behavior; substitutions cover unavoidable invocation syntax.

The shared-rules skill is generated from the ordered `.apm/instructions/*.instructions.md` sources.
It uses the same manifest-declared invocation substitutions as all four entry-point skills. A final
negative validation rejects any generated skill that still contains a user-facing invocation of
`/requirements`, `/technical-design`, `/write-tests`, or `/frontend-architecture`; examples that
describe existing-harness syntax must be explicitly allowlisted by source line in the manifest.
Instruction frontmatter is removed, and each source is separated by a deterministic Markdown
comment naming its repository-relative path plus blank lines so adjacent headings cannot merge.

The marked workflow section seeded/appended to `AGENTS.md` tells Codex to read the shared-rules skill
before any task. This gives a hand-authored `AGENTS.md` the full managed rules without replacing its
prose and does not depend on implicit skill matching.

The generator supports:

- default/write mode: atomically regenerate all five committed `SKILL.md` files;
- `--check` mode: generate into a securely created temporary directory, compare regular files with
  committed output, and exit nonzero
  with the stale skill names without modifying the tree.

The source-to-output mapping is manifest-driven rather than inferred from every prompt in the
directory. This prevents an unrelated future prompt from silently becoming a public Codex skill and
makes additions, removals, descriptions, source order, and substitutions reviewable. `--check`
fails on an undeclared generated skill or declared missing source/output.
Skill names remain identical to existing command names, so Codex invocation is `$requirements`,
`$technical-design`, `$write-tests`, and `$frontend-architecture`.

### Reviewer Agent Integration

Continue using `.apm/agents/*.agent.md` as the reviewer source of truth. APM remains responsible for
compiling those sources to `.codex/agents/*.toml`; this package will not implement a second TOML
compiler.

Do not change either shared reviewer persona in this spec. The parent Plan Review Workflow remains
authoritative for the context supplied in each round, and Codex receives the same compiled reviewer
sources as every other harness. The existing contradiction in the security-reviewer persona's
round-input wording is a cross-harness concern deferred to a future follow-up.

Extend the existing model configuration path as follows:

1. Detect `.codex/agents` in `init-and-wire.sh` and include `codex` in the model-configuration prompt.
2. Document Codex model values as exact Codex model IDs; an empty value continues to inherit the
   parent/default model.
3. Add a Codex TOML emitter to `emit-agent-models.sh`. Read the configured string through `jq`, reject
   CR, LF, NUL, and unsupported control characters, and serialize the remainder as a JSON basic
   string (valid TOML basic-string escaping). `#`, quotes, backslashes, tabs, and Unicode remain data.
4. Mutate only the root `model` key before the one-line root `developer_instructions` assignment in
   APM's known generated schema. Reject duplicate keys, tables, malformed structure, or unexpected
   reviewer identity; validate the complete expected key structure after generating the candidate.
5. Before changing a reviewer TOML, parse APM 0.31's lock schema fail-closed and verify: the regular,
   non-symlinked root `apm.lock.yaml`; exactly one dependency named `spec-driven-workflow`; the exact
   normalized relative deployed path; one matching project-relative deployment whose active owner
   matches that dependency; and a current file SHA-256 equal to its recorded content hash. A matching
   filename or editable lock path alone is never ownership proof. A repository-controlled lockfile
   remains trust metadata, not a cryptographic authority. Unknown lockfile schema versions fail
   closed with a manual step rather than being guessed.
6. Maintain an installer-owned `.spec-workflow/agent-model-state.json` provenance ledger. Each Codex
   reviewer entry records a unique reviewer identity and destination, the dependency identity,
   normalized relative destination, APM baseline hash from the current lock, generator version,
   canonical hash of all non-model content, exact previously stamped model, and exact post-stamp
   file hash. The schema is versioned; unknown versions, duplicate reviewer identities or
   destinations, unknown keys, and wrong JSON types fail closed. Write it atomically only after the
   agent file is validated and replaced successfully, updating only that reviewer and preserving
   other valid entries.
7. Authorize a mutation only in one of three states:
   - **APM baseline:** current file hash equals the matching lock content hash; initial or post-update
     stamping may proceed and replaces any prior ledger entry.
   - **Known package transformation:** current file hash equals the ledger's post-stamp hash, and the
     ledger's dependency, destination, baseline hash, and stamped model match the current file and
     lock context; canonical non-model content still equals the recorded baseline-derived hash;
     model A may safely change to B and the ledger is updated.
   - **Unknown/drifted:** every other state fails closed without changing either file or ledger.
8. If the desired model is already present and the file is either the exact APM baseline (inherit/no
   stamp) or the exact recorded package transformation, make no write. This keeps repeated setup
   byte-stable. If APM update restores a new baseline, the lock hash permits re-stamping and replaces
   stale provenance. A user edit invalidates the post-stamp hash and blocks later changes.
9. Create the candidate with `mktemp` in the verified destination directory, mode 0600, validate it,
   preserve the destination's mode, and rename on the same filesystem. No parser/validation failure
   may alter the destination or lockfile.
10. If ownership cannot be proven, leave the file and provenance ledger byte-for-byte unchanged and
   add a precise
   `.spec-workflow/MANUAL-STEPS.md` notice.

The agent-file rename and ledger rename cannot be one cross-file atomic transaction. If the agent
replacement succeeds but the ledger update fails, the next run treats the state as unknown and
fails closed. Its manual step instructs the user to restore the APM baseline with `apm install` or
`apm update`, then rerun setup; it never adopts the transformed file merely because its model looks
plausible.

`model_reasoning_effort` is intentionally not added to the workflow config in this spec; reviewer
agents inherit the parent/default reasoning effort. Supporting a separately configurable effort
would require a schema migration and is not necessary for feature parity.

No Codex configuration file is needed for normal operation: current Codex releases enable subagents
by default, and the installed Plan Review Workflow explicitly instructs the parent to invoke the two
reviewers. If a consumer has disabled subagents, setup preserves that choice and documentation tells
them that the mandatory review phase cannot run until they re-enable it.

### Installation and Ownership Contract

Use APM's native primitive deployment and collision handling for `.agents/skills` and
`.codex/agents`; do not copy either tree from `init-and-wire.sh`. The explicit setup script remains
responsible only for living-file seeding, managed `.spec-workflow` enforcement, safe model stamping,
and manual-step reporting.

Ownership classes remain:

| Class | Examples | Update behavior |
|---|---|---|
| Consumer-owned, seed once | `AGENTS.md`, PRD, specs, security rules, context map, supplemental rules, workflow config | Create only when absent; otherwise preserve, except the existing consent-based marked `AGENTS.md` append |
| APM-managed primitives | `.agents/skills/<workflow>`, `.codex/agents/<reviewer>.toml` | APM deploys/refreshes only files recorded as package-owned; collisions fail safely unless a consumer explicitly uses APM's force option |
| Installer-managed enforcement | `.spec-workflow/hooks/**`, copied templates, schemas, `.spec-workflow/.gitignore`, regenerated `MANUAL-STEPS.md`, `agent-model-state.json` | Refresh/prune only declared managed names; preserve valid model provenance additively and replace entries only after a successful owned-file mutation |
| Never touched | `AGENTS.override.md`, `.codex/config.toml`, unrelated Codex hooks/settings, unrelated user skills and agents, global Codex files | Preserve byte-for-byte |

The documentation must warn that `apm install --force` is an explicit APM escape hatch that can
overwrite collisions and is outside AC-6 and the package's non-destructive default path.

Before its first mutation, `init-and-wire.sh` performs a fail-closed safety preflight:

- canonicalize and validate the intended git root and any `APM_PROJECT_DIR` override;
- require every managed destination to be relative to and resolve beneath that root;
- reject symlinked destination files and symlinked path components for `.spec-workflow`, Codex agent
  targets, `AGENTS.md`, and every living/managed file it may write or prune;
- require regular source files from the installed package and reject aliased/nested source and
  destination roots that escape the expected package/consumer relationship;
- require secure `mktemp` creation (no predictable fallback), restrictive permissions, same-filesystem
  atomic rename, and cleanup traps; and
- normalize untrusted values such as `core.hooksPath` before terminal or Markdown notices so control
  characters cannot forge output or checklist entries.

The APM 0.31+ check occurs before any setup-script mutation when a Codex target is detected. Older
APM versions receive an upgrade instruction and setup exits without writing. APM itself owns any
earlier primitive-deployment behavior; documentation requires immutable package pins and disallows
claiming rollback for artifacts an older external APM may already have written.

### Instruction Behavior

The package does not require `apm compile` to replace or create root `AGENTS.md`. The marked workflow
section requires Codex to load `.agents/skills/spec-driven-workflow/SKILL.md`, whose generated body
contains the global and scoped rules. The security instruction remains a pointer that tells Codex to
resolve the actual rules through `.spec-workflow/context-map.md`. Because Codex lacks a native
path-scoped rules directory, Codex sees that small security pointer globally; the target rules are
loaded only when its declared paths apply.

The installer must keep its existing `AGENTS.md` behavior:

- absent: seed the neutral project-memory stub plus marked workflow section requiring the shared
  rules skill;
- existing with marker: do nothing;
- existing without marker: append only with interactive consent using an atomic whole-file rewrite,
  otherwise report a manual step; existing prose stays byte-for-byte intact;
- `AGENTS.override.md`: never modify; document Codex precedence and the possibility that it shadows
  the workflow guidance in the same directory.

### Compatibility and Versioning

- Change the documented APM requirement from the previously verified 0.25.0 baseline to 0.31.0+ for
  Codex support.
- Keep existing prompt files and agent Markdown unchanged unless a workflow correction applies to
  every harness.
- Do not add `targets:` to `apm.yml`; auto-detection and explicit `--target codex` remain supported.
- Do not add runtime dependencies.
- Existing harness output is protected with regression fixtures and the existing enforcement suite.

### Test Design

Add a dedicated `tests/codex-support.test.sh` packaging/integration suite instead of coupling this
feature to the enforcement state-machine suite. Use only securely created temporary fixtures whose
canonical paths match a fixed `/tmp` prefix; cleanup refuses empty, root, home, or workspace paths.
The release CI path must run this suite with APM 0.31+; local absence may skip loudly, never silently
pass the release gate.

Cover:

1. Skill synchronization tests: generator `--check`, Agent Skills metadata validation, declared
   substitutions across all five skills, source parity, deterministic source boundaries, a negative
   assertion for unsupported slash invocations, and a deliberately stale copy that fails without
   mutation. Any intentional legacy-syntax allowlist binds source identity plus exact expected text;
   stale, missing, or duplicate exemptions fail generation.
2. APM Codex integration test, gated on APM 0.31.0+: install a local package copy into a temporary
   consumer and assert all five `.agents/skills/*/SKILL.md` files—including
   `spec-driven-workflow`—and both `.codex/agents/*.toml` files.
3. Reviewer schema tests: required TOML keys, source instructions preserved unchanged, both reviewer
   names available, and parent orchestration assigns the documented round-specific inputs.
4. Model-emitter tests: unset inherits; safe values including quotes, backslashes, tabs, Unicode and
   `#`; rejected CR/LF/control and key-injection payloads; initial baseline stamp; repeated runs
   byte-stable; model A → B without APM update; APM refresh followed by restamp; stale provenance
   replacement after a new baseline; and drifted, malformed, symlinked, lock/provenance-tampered,
   duplicate, traversal, absolute, and unowned same-name agents unchanged with a manual notice and no
   temporary residue. Inject failure after agent replacement but before ledger replacement and verify
   the next run fails closed with baseline-restoration guidance.
5. Preservation fixtures for existing `AGENTS.md`, `AGENTS.override.md`, `.codex/config.toml`, user
   skills, user agents, every seed-once living file, and mixed Codex plus legacy harness installs.
6. Existing enforcement and installer-reconciliation tests remain green.
7. Adversarial setup fixtures cover symlinked `.spec-workflow`, `.codex`, `.codex/agents`, reviewer
   files, `AGENTS.md`, managed/living files, hostile temporary siblings, and hostile `TMPDIR`.
8. Characterization fixtures cover absent and hand-authored `AGENTS.md`, primitive collisions,
   mixed targets, nested-directory discovery, and the strongest offline evidence of both reviewer
   definitions being selectable. A documented manual Codex smoke test proves actual parallel use.

Tests must not use `--force`, modify global Codex state, or depend on network access.

### Documentation Changes

Update README sections for requirements, installation, start-here commands, deployed layout,
reviewer model configuration, supported stamping, and verification. Show both forms side by side:

| Existing harness command | Codex CLI equivalent |
|---|---|
| `/requirements <idea>` | `$requirements <idea>` |
| `/technical-design SPEC-X` | `$technical-design SPEC-X` |
| `/write-tests SPEC-X` | `$write-tests SPEC-X` |
| `/frontend-architecture <change>` | `$frontend-architecture <change>` |

Link to official Codex skills, subagents, and `AGENTS.md` documentation and to APM's multi-skill
package documentation.

Describe the lockfile and provenance ledger as collision and ordinary-drift controls, never as a
cryptographic boundary against an actor who can coherently rewrite repository files.

### Review Change Log

| Review finding | Design change |
|---|---|
| R1 architecture: ambiguous `AGENTS.md` ownership | Preserved consumer file; mandatory shared-rules skill supplies managed instructions |
| R1 architecture: prompt bodies used legacy slash commands | Manifest-controlled substitutions and negative validation across all five skills |
| R1 architecture: reviewer round contract conflicted | Excluded as a cross-harness correction for a future follow-up; SPEC-1 preserves reviewer sources and tests Codex orchestration |
| R1 architecture/security: filename/lock path was insufficient ownership | Exact dependency, deployment, schema, identity, baseline hash, and non-model-content checks |
| R1 security: symlink/path/temp-file overwrite risks | Canonical containment preflight, non-symlink/regular-file checks, secure same-directory temporaries |
| R1 security: `--force` contradicted preservation promise | AC-6 and BDD-3 explicitly exclude deliberate forced installation |
| R1 security: TOML injection and ambiguous edits | Restricted root-key mutation, strict encoding, complete candidate validation, hostile-value tests |
| R2 architecture: shared rules still needed substitutions | Same transformation/negative assertion now applies to all generated skills |
| R2 architecture: exact baseline hash blocked model A → B | Versioned three-state provenance ledger authorizes only known deterministic transformations |
| Remediation concerns: two-file failure and weak transformation proof | Fail-closed recovery guidance plus canonical non-model-content hash and injected-failure tests |

### Acceptance-Criteria Coverage

| Acceptance criteria | Design coverage |
|---|---|
| AC-1–2 | Generated `.apm/skills` collection, substitutions, Codex integration tests, invocation documentation |
| AC-3 | Existing APM agent compilation unchanged, parent round orchestration, Codex model emitter, smoke test |
| AC-4 | Mandatory shared-rules skill loaded via preserved `AGENTS.md`; context-map security pointer |
| AC-5 | Existing explicit setup retained and exercised in Codex fixtures |
| AC-6–8 | Ownership classes, lockfile ownership proof, collision fixtures, idempotence tests |
| AC-9 | Dedicated required `tests/codex-support.test.sh` packaging/integration suite |
| AC-10 | README update and official documentation links |

## Open Questions

_None._
