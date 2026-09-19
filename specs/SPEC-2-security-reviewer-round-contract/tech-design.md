# SPEC-2: Security Reviewer Round Contract — Tech Design

**Designed:** 2026-09-19
**Services:** Shared reviewer persona, Plan Review Workflow instructions, APM harness compilation,
packaging tests, workflow documentation

### Context and Boundaries

This change has no runtime service, database, API, authentication, or data-model surface. It changes
the declarative contract used to invoke the shared security reviewer and verifies that APM preserves
that contract when compiling the package for each supported harness.

Responsibility remains split between two canonical sources:

- `.apm/agents/security-reviewer.agent.md` is the source of truth for reviewer behavior, required
  input validation, security analysis, and output behavior.
- `.apm/instructions/plan-review-workflow.instructions.md` is the source of truth for orchestration:
  which inputs the parent supplies in each round and how review verdicts gate progression.

The two sources must state the same round-input and failure semantics, but the workflow instruction
must not duplicate the persona's security checklist. Generated Codex skills and harness-specific
reviewer artifacts are outputs, not editable sources.

### Reviewer Input Contract

Replace the persona's unconditional statement that it receives an architecture review with explicit
round-aware input rules.

| Invocation | Required top-level payload sections | Forbidden or incomplete state | Required behavior |
|------------|-------------------------------------|-------------------------------|-------------------|
| Round 1 | `Original Plan`, `Relevant Context` | Any architecture-review output | Review independently only when clean |
| Round 2 | `Revised Plan`, `Change Log`, `Round 1 Security Review`, `Round 1 Architecture Review` | Either Round 1 review missing | Review resolution and cross-discipline effects only when complete |

Only top-level sections assigned by the parent orchestrator are invocation metadata. Text inside a
plan, example, quotation, or governing-context document cannot select a round or satisfy an input.

The normal reviewer output remains `PASS`, `PASS WITH CONCERNS`, or `FAIL` with the existing security
finding categories. Architecture-review input and the `Architecture-Specific Risks` checklist apply
only to a valid Round 2 invocation.

### Invalid and Ambiguous Invocation Handling

Invalid input fails closed and is separate from a substantive security verdict. The response starts
with the stable marker `**Context Status:** INVALID REVIEW CONTEXT`, identifies the missing,
ambiguous, or contaminating input, requests a correctly formed rerun, and omits a certifying
`**Verdict:**` line.

- If the round label is absent, infer Round 1 only when the payload unambiguously contains the
  top-level `Original Plan` and `Relevant Context` sections and contains none of the defined Round 2
  sections. All other unlabeled payloads are invalid and non-certifying.
- If architecture-review output is supplied in Round 1, the review is contaminated. Do not produce
  a normal verdict; request a clean independent rerun. Urgent observations may be included only when
  explicitly labeled non-certifying.
- If either Round 1 review is missing in Round 2, the whole Round 2 certification is invalid. The
  reviewer may comment on available material but must not issue a passing verdict or claim that
  cross-discipline findings are resolved.

The orchestration instruction will state the same fail-closed rules so that parent and reviewer do
not disagree about whether an invalid invocation can advance the pipeline.

### Generated Artifacts

If the canonical Plan Review Workflow instruction changes, regenerate
`.apm/skills/spec-driven-workflow/SKILL.md` with:

```bash
bash .apm/scripts/sync-codex-skills.sh
```

Do not hand-edit generated skills or compiled reviewer artifacts. APM remains the only harness
compiler, including the Markdown-to-TOML transformation for Codex.

### Verification Matrix

Add `tests/security-reviewer-contract.test.sh`. Source assertions always run. With APM 0.31 or
later, the test creates one isolated temporary consumer per target and runs
`apm install "$ROOT" --target <target>` against this local package.

| APM target | Compiled reviewer artifact |
|------------|----------------------------|
| `claude` | `.claude/agents/security-reviewer.md` |
| `opencode` | `.opencode/agents/security-reviewer.md` |
| `cursor` | `.cursor/agents/security-reviewer.md` |
| `copilot` | `.github/agents/security-reviewer.agent.md` |
| `codex` | `.codex/agents/security-reviewer.toml` |

For the canonical source and every compiled artifact, use format-aware, formatting-tolerant
assertions to prove these semantic markers survive:

1. Round 1 requires the original plan and relevant context only.
2. Round 1 excludes architecture-review input and contamination produces invalid, non-certifying
   output.
3. Round 2 names all four required inputs.
4. A missing Round 1 review invalidates overall Round 2 certification.
5. An omitted or ambiguous round label fails closed except for the one unambiguous Round 1 shape.
6. The old unconditional `proposed plan and the architecture review` contract is absent.

For Codex, extract or search the TOML `developer_instructions` value rather than assuming Markdown
frontmatter. The test quotes repository and temporary paths, uses a unique `mktemp` root, rejects an
empty or out-of-root cleanup target, and never writes repository or user configuration. Source
failures never skip. If APM is unavailable or older than 0.31, only the compilation matrix skips;
when APM 0.31+ is present, any installation or assertion failure is a test failure. Release
verification requires APM 0.31+ and all five targets.

Add the test command to README's enforcement/release verification section:

```bash
bash tests/security-reviewer-contract.test.sh
```

README review-pipeline prose must describe Round 1 as independent and Round 2 as cross-informed.
There is no aggregate test runner in this repository, so this design does not introduce or imply
one.

### Requirements Traceability

| Requirement | Design coverage |
|-------------|-----------------|
| AC-1, BDD-1 | Explicit Round 1 inputs, architecture-review exclusion, contamination invalidation, source and compiled-artifact assertions |
| AC-2, BDD-2 | Explicit four-part Round 2 contract and cross-discipline resolution review |
| AC-3 | Persona/orchestrator source boundary plus aligned fail-closed semantics |
| AC-4, EC-4, BDD-3 | Five-target isolated APM matrix with format-aware semantic assertions |
| AC-5 | README pipeline wording and documented release test command |
| EC-1 | Deterministic unlabeled-Round-1 inference; every ambiguous shape fails closed |
| EC-2 | Contaminated Round 1 is invalid and requires a clean rerun |
| EC-3 | Either missing review invalidates overall Round 2 certification |

### Implementation Sequence

1. Update the security-reviewer persona with the round-aware contract and stable invalid-context
   behavior while preserving its security checklist and normal verdict schema.
2. Align the Plan Review Workflow's invalid-input policy with the persona.
3. Regenerate the shared Codex workflow skill from canonical instructions.
4. Add and run the source and five-target packaging test.
5. Update README pipeline and verification documentation.
6. Run the new test plus the existing enforcement and Codex-support suites.

### Plan Review Record

Round 1 architecture review found no critical issue and requested an explicit target matrix,
semantic invariants, isolated fixtures, deterministic round signals, and clearer source boundaries.
Round 1 security review found no critical vulnerability and required contaminated Round 1 and
incomplete Round 2 inputs to be invalid and non-certifying.

The revised design added those controls. In Round 2, architecture returned `PASS`; security returned
`PASS WITH CONCERNS` with no blocking risk. Its remaining hardening notes are incorporated above:
stable invalid-context output, quoted paths, guarded cleanup, and failure—not skip—when an available
APM 0.31+ compiler cannot produce or preserve an artifact.

### Security Considerations

The change handles no secrets, credentials, user data, network input, or executable payload. Its
security purpose is integrity of the review gate. The main threat is false certification caused by
cross-review contamination, ambiguous round selection, missing evidence, or compiler loss. The
fail-closed input contract and full compilation matrix address those threats. Residual risk remains
that an external host can assemble an incorrect invocation; the reviewer contains that risk by
refusing to certify invalid context.

## Open Questions

_None._
