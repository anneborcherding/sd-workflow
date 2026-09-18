---
name: spec-driven-workflow
description: Load the mandatory spec-driven workflow, engineering, testing, security, versioning, and review rules before working in this repository.
---

<!-- GENERATED FILE — DO NOT EDIT DIRECTLY.
     Edit the canonical sources listed in .apm/scripts/codex-primitives.tsv, then run
     bash .apm/scripts/sync-codex-skills.sh to regenerate this file. -->

<!-- source: .apm/instructions/code-hygiene.instructions.md -->


# Code Hygiene

After finishing and testing a change, leave the codebase clean:

- **No zombie code.** Remove dead branches, unused helpers, commented-out blocks, and workarounds the
  change has superseded. A change is not done while its predecessor is still lying around.
- **Keep the architecture source of truth true.** If the change makes the project's architecture
  documentation inconsistent with the codebase, fix it: update it in place when the context map
  (`.spec-workflow/context-map.md`, `kind=architecture`; default `ARCHITECTURE.md`) resolves it to a
  repo file; when it resolves to an external tool or provider you cannot edit, flag the drift for a
  human. Honor the map's `context-schema:` front-matter — this core supports `1`; on an unsupported
  value note `context schema N unsupported` and fall back to the default.
- **Keep documentation true.** Update user documentation and specs whenever a change makes them
  outdated — including specs other than the one you are implementing.

<!-- source: .apm/instructions/engineering-practices.instructions.md -->


# Engineering Practices

These rules are stack-agnostic and apply to every change, inside or outside the spec workflow.

## Discovery First

Read the codebase before proposing anything. Match the patterns already established — component
structure, layering, naming, error handling, and folder conventions come from what the project
actually does, not from what is idiomatic elsewhere.

Never assume a framework, library, test runner, or convention the project has not established. If you
cannot find the pattern, discover it or ask — do not invent it.

If a deviation from an existing pattern is warranted, say why, and apply it consistently: either
migrate the existing code too, or flag the remainder explicitly as tech debt. A half-migrated pattern
is worse than either end state.

## Design Principles

KISS, DRY, YAGNI. Solve the problem in front of you at the simplest level that will hold.

- **No premature abstractions.** Three similar lines beat a generic wrapper nobody asked for.
- **No unnecessary dependencies.** Justify every addition — the stack stays lean by default.
- **No catch-all files.** No `utils`, `helpers`, or `types` dumping grounds; colocate code with its
  consumers and export when it is genuinely reused.

## Push Back

If a requested change would introduce a pattern that conflicts with existing code, say so and propose
the better alternative. Do not silently accept an approach you can see is wrong.

<!-- source: .apm/instructions/interaction-mode.instructions.md -->


# Interaction Mode

Several commands are written to interview a human: `$requirements` clarifies scope and edge cases,
`$technical-design` asks before it guesses, the plan-review pipeline escalates unresolved critical
findings. None of that works when nobody is at the terminal.

**Interaction mode** decides where those questions go. Read it before the first question you would
ask, from `.spec-workflow/config.json`:

```json
{ "interaction": { "mode": "ask" } }
```

- **`ask`** (the default, and what applies when the file or key is absent) — interview the user in the
  terminal, using your harness's single/multiple-choice questions where it supports them.
- **`file`** — do not ask. Record the question in the artifact you own, record the answer you
  **assumed**, and carry on.

## The Open Questions block

One format, three homes — `docs/PRD.md` (project-level questions, `$requirements` Init Mode),
`specs/SPEC-N-*/spec.md` (contract questions, `$requirements` Spec Mode), and
`specs/SPEC-N-*/tech-design.md` (design questions, `$technical-design` and the plan-review pipeline).
Always a `## Open Questions` section — `##`, never `###`, even in `tech-design.md` where the
surrounding headings are `###`; the version check strips sections by `##` boundary and cannot exempt
a `###` one.

```markdown
## Open Questions

### Q-1: Which compression codec is the default?
- (a) snappy — faster writes, ~30% larger files
- (b) zstd — ~2× slower, ~50% smaller
**Assumed:** (b) zstd — AC-2 prioritises storage cost over write latency.
**Answer:**
```

- IDs are `Q-1`, `Q-2`, … numbered per file, like `US-N` / `AC-N` / `EC-N`. Never renumber; a Q-ID
  gets cited in commits and changelog rows.
- Give **concrete options** with their trade-offs, exactly as you would in the terminal. A question
  with no options is a question a human cannot answer quickly.
- **`**Assumed:**`** is mandatory in `file` mode and states what you actually built on, plus the
  one-line reason. Never leave it blank and never invent an assumption you did not use.
- **`**Answer:**`** is the human's line. Leave it **empty**. They write their choice, or `confirmed`
  to accept your assumption.
- **Answered questions stay in the file.** This section is a ledger, not a queue — it is the only
  place the workflow records *why* a decision went the way it did.

## Working in `file` mode

1. **Never block.** Choose the most defensible option, record it as `**Assumed:**`, and finish your
   own artifact on that basis. A command that stops half-done is worse than one that documents a
   guess.
2. **Never silently guess.** Every decision you would have asked about becomes a `Q-N`. If you find
   yourself writing "I'll assume…" anywhere, that is a question.
3. **Skip the approval step.** Where a command says "present for approval" / "wait for Approved",
   write the artifact and hand off instead. Say plainly in your summary how many questions you left
   open and where.
4. **Do not answer your own questions later.** Only a human fills in `**Answer:**`. Reading your own
   `**Assumed:**` back as if it were settled is the one failure mode this whole mechanism exists to
   prevent.

## The gate: an open question stops the next phase

This holds in **both** modes — a question is unanswered no matter how it got there, and a human may
add one by hand to park a spec.

| Unanswered question in | The spec may not advance past |
|---|---|
| `docs/PRD.md` | `🔵 In Planning` — for **every** spec |
| `specs/SPEC-N-*/spec.md` | `🔵 In Planning` |
| `specs/SPEC-N-*/tech-design.md` | `🟣 Planned` |

So `$technical-design` must **refuse to run** on a spec whose `spec.md` still has an unanswered
question, and implementation must not start while `tech-design.md` has one. Check before you start,
and say which `Q-N` is blocking.

`.spec-workflow/hooks/check-open-questions.sh` enforces this as a git pre-commit check, so an agent
that skips the courtesy check is still stopped at commit time. Resolve a block by answering the
question, or by rolling the status back — never by deleting a question you raised.

An open question is a *ceiling*, and nothing imposes a conflicting floor: you may sit on the spec's
branch at `🔵 In Planning` for as long as the question is open, and discuss it freely. No hook fires
while you are talking it through — they run only when you commit.

Writing or answering a question is **not** a substantive change: `check-spec-version.sh` exempts the
whole `## Open Questions` section, so a spec at `🟣 Planned` or later needs no version bump for it.
Whatever the answer then changes in the contract or design *is* substantive and follows the normal
spec-versioning rules — cite the `Q-N` in the changelog row.

## Scope

`$write-tests` asks nothing and is unaffected. `$frontend-architecture` produces a conversational plan
rather than a file it owns, so it has nowhere to park a question — it stays interactive in both modes;
if it needs a decision under `file` mode and the work belongs to a spec, record it in that spec's
`tech-design.md`.

<!-- source: .apm/instructions/plan-review-workflow.instructions.md -->


# Plan Review Workflow

Before presenting any plan to the user, run the full iterative review pipeline below.
Do not skip, abbreviate, or present the plan before the pipeline completes.

A "plan" includes: proposed architecture, new features, API design, data model changes,
infrastructure changes, and any change touching auth, data storage, or external services.
For small isolated changes (typo fixes, renaming, minor refactors) this is optional.

The two reviewer agents (`architecture-reviewer` and `security-reviewer`) are deployed with this
package; invoke them the way your harness invokes subagents (from its agents directory).

---

## Assemble review context

Before Round 1, gather the **relevant codebase context** you will hand to both reviewers. Consult
`.spec-workflow/context-map.md` if it exists: for `kind=architecture`, `kind=security`, and `kind=adr`, query a
listed MCP context provider — scoped to the services the plan touches — if its tool is connected, else
read the listed source(s), else fall back to the codebase. This is what lets the security reviewer see
your org's real security governance whether it lives in a repo file or in Confluence. Include the
result in the "relevant codebase context" passed to both agents below. Honor the map's
`context-schema:` front-matter — this core supports `1`; on an unsupported value note
`context schema N unsupported` and run on discovery alone.

---

## Round 1 — Independent Review

Run both agents in parallel on the original plan:

- **Task A — Architecture Review** — agent `architecture-reviewer`, input: the full proposed plan +
  relevant codebase context.
- **Task B — Security Review** — agent `security-reviewer`, input: the full proposed plan + relevant
  codebase context.

Do not pass either agent's output to the other in Round 1. Independence is the point.

---

## Refinement — Revise the Plan

Once both Round 1 reviews are complete:

1. Collect all critical issues and concerns from both reviews.
2. Revise the plan to address them — cross-discipline first:
   - Apply security fixes that affect architectural decisions.
   - Apply architectural changes that have security implications.
   - Then address remaining single-discipline issues.
3. Note every change made and which finding it resolves.
4. Note any issues you chose not to address and why.

This produces a **Revised Plan** and a **Change Log**.

---

## Round 2 — Cross-Informed Review

Run both agents again on the Revised Plan, with full context from Round 1:

- **Task C — Architecture Review (Round 2)** — input: revised plan + change log + Round 1
  architecture review + Round 1 security review. Focus: do the security-driven changes introduce
  architectural problems? Are Round 1 architecture concerns resolved?
- **Task D — Security Review (Round 2)** — input: revised plan + change log + Round 1 security review
  + Round 1 architecture review. Focus: do the architecture-driven changes introduce security
  problems? Are Round 1 security concerns resolved?

---

## Evaluate Round 2 Verdicts

| State | Action |
|---|---|
| Both Round 2 verdicts PASS or PASS WITH CONCERNS, all critical issues resolved | Proceed to Present — clean |
| PASS WITH CONCERNS remain but no critical issues | Proceed to Present — flag concerns to user |
| Any Round 2 FAIL, or any Round 1 critical issue unresolved after revision | **Stop — escalate to the user before proceeding** (see below for `interaction.mode: "file"`) |

An issue counts as "resolved" only if the reviewing agent in Round 2 explicitly confirms it. Do not
self-certify resolution.

---

## Present to User

**If the pipeline completed cleanly:** present the revised plan in full; a brief change log tied to
the findings that drove each change; any open concerns (not critical) with your recommendation on
each; and a recommendation (proceed / proceed with caveats / needs further design).

**If the pipeline has unresolved critical issues:** **Stop.** Present the unresolved issues clearly.
Do not present the plan as ready. Ask the user how they want to proceed — redesign, accept the risk
explicitly, or descope the change. Do not bury failures in a long summary; lead with the blocker.

**Under `interaction.mode: "file"`** (see the interaction-mode rule) there is nobody to escalate to,
and an escalation that evaporates with the conversation is worse than no pipeline at all. Record each
unresolved critical issue as a `Q-N` under `## Open Questions` in the spec's `tech-design.md` — the
finding, the reviewer that raised it, and the three options (redesign / accept the risk explicitly /
descope) — with `**Assumed:** redesign` unless the design already reflects a different call. Still
lead with the blocker in your summary. This holds the spec at 🟣 Planned, so implementation cannot
start on an unreviewed risk: the accepting decision has to be written down by a human.

<!-- source: .apm/instructions/security.instructions.md -->


# Security Rules

Consult `.spec-workflow/context-map.md` for `kind=security` to find this project's security rules:
query the listed MCP context provider if one is connected, else read the listed security source, else
discover the project's own security conventions from the codebase. Honor its `context-schema:`
front-matter — this core supports `1`; on an unsupported value note `context schema N unsupported` and
run on discovery alone. **Default:** `docs/SECURITY-RULES.md` — seeded once into the consumer project
and owned by it — used when the context map is absent or lists no `security` row.

This scoped instruction is what makes your harness auto-inject the security rules when you touch
`.env*` files or files under `**/api/**`; the context map is what decides *where* those rules actually
live — a repo file, a Confluence/Notion page, or a provider.

<!-- source: .apm/instructions/spec-driven-workflow.instructions.md -->


# Spec-Driven Development Workflow

All implementation work follows this sequence per spec. Each step also advances the spec's
**status**, which must be kept identical in the spec's `**Status:**` header **and** its
`specs/INDEX.md` row. The five states are `In Planning → Planned → In Progress → In Review →
Validated`, plus a terminal `Deprecated` reachable from any state (see the legend in
`specs/INDEX.md`). Each spec is also **versioned** — see the spec-versioning rules.

1. **Spec** (`$requirements`) — defines WHAT (user stories, acceptance criteria, edge cases, BDD scenarios). Cuts the spec's branch first, if you are still on the repo's default branch. → status **🔵 In Planning**
2. **Technical Design** (`$technical-design SPEC-X`) — defines HOW (DB schema, API contracts, components). → status **🟣 Planned**
3. **Technical Design Refinement** — execute the Plan Review Workflow for the tech design. (stays **Planned**)
4. **Implementation** — code against the tech design, on the spec's branch. Stay on the branch step 1 cut; only cut one now if you are somehow still on the default branch. → set status to **🟡 In Progress** in both the spec header and `specs/INDEX.md`. If your implementation changes another spec that is already **Planned or later** (a shared schema, API, or contract), update that spec too — bump its version + add a changelog row, or deprecate it if its feature no longer exists.
5. **Verification** — write/run tests against the acceptance criteria and BDD scenarios (via `$write-tests`), results written to `audit-trail.md` in the spec folder, from `.spec-workflow/templates/audit-trail.template.md`. → status **🟠 In Review**
6. **Close-out** — in `spec.md`, tick every satisfied acceptance-criterion checkbox (`- [x] AC-N`), mark any intentionally-skipped one `DESCOPED` with a reason (leave it `- [ ]`), complete `audit-trail.md`, then set status to **🟢 Validated** in **both** the `spec.md` header and `specs/INDEX.md`.

The audit trail is the spec's verification record, and the only place the **AC → evidence** and
**BDD → evidence** mappings exist: `spec.md` says a criterion is met or a scenario holds,
`audit-trail.md` says what proves it. `check-ac-closeout.sh` blocks the commit if any AC ticked in
`spec.md` is never cited there, and `check-bdd-closeout.sh` blocks it if any declared `BDD-N` scenario
(not marked DESCOPED) is never cited. Read the mechanical facts out of
git rather than from memory — `git branch --show-current`, `git merge-base <default-branch> HEAD`,
`git log --oneline <base>..HEAD`, `git diff --name-only <base>..HEAD` — and record the test run as
observed, including skips and failures. Do not create the file before there is real evidence for it: its mere existence pushes the
status floor to **In Review**.

Five checks enforce this — the shared scripts in `.spec-workflow/hooks/` (`check-ac-closeout.sh`:
every AC ticked or DESCOPED once a close-out section exists, and every ticked AC cited in the trail;
`check-bdd-closeout.sh`: once the trail exists, every declared `BDD-N` scenario (not marked DESCOPED)
cited in it; `check-status-sync.sh`: spec header and INDEX row agree, use a legal status word, and
match reality; `check-spec-version.sh`: a Planned-or-later spec that changed substantively — or was
deprecated — must bump its version + add a changelog row; `check-open-questions.sh`: an unanswered
`## Open Questions` entry holds the spec at the phase that raised it). They run as a git `pre-commit`
hook — blocking a drifted commit from any
tool or human; bypass a single commit with `git commit --no-verify`. That commit boundary is the only
one they run at: no session-end hook is installed, because no harness has an event that means "the
next workflow step was invoked".

How they pick which spec to judge: the ones your change **touches** — any file under a spec folder,
or a changed `specs/INDEX.md` row. Never the branch name. So a commit of pure source code is silent,
drift is caught wherever it happens (including on the default branch), and a commit spanning two
specs is judged for both.

Note what `check-status-sync.sh` does **not** claim: having cut the branch is not evidence that
implementation has started. Cutting it early — to plan on it, or to work through an open question —
is fine, and the spec may legitimately still be `In Planning`. Only artifacts in the spec folder (an
`audit-trail.md`) push the status floor up.

When implementing a spec, always read these files first:
- The spec folder `specs/SPEC-X-*/`: `spec.md` (the contract) and `tech-design.md` (the HOW)
- `.spec-workflow/context-map.md` to locate the architecture & security sources (`kind=architecture` /
  `kind=security`): query a connected provider, else read the listed file, else discover from the
  codebase — defaults to `ARCHITECTURE.md` and `docs/SECURITY-RULES.md`. Honor its `context-schema:`
  front-matter — this core supports `1`; on an unsupported value note `context schema N unsupported`
  and run on discovery alone
- `specs/INDEX.md` for dependency order

Never start implementing a spec that has no `tech-design.md`. Run `$technical-design SPEC-X` first.

## Branches

Spec work belongs on a branch, never the repo's default branch (`main`, `master`, whatever
`git symbolic-ref refs/remotes/origin/HEAD` reports). `$requirements` checks this and offers to cut
one before it writes anything; if you arrive at a later phase still on the default branch, cut one
first. Everything for a spec — `spec.md`, `tech-design.md`, the code, `audit-trail.md` — belongs on
that one branch.

**The name is yours.** Nothing in this workflow reads it: no command parses it and no check is gated
on it, so `SPEC-4-glossary`, `userstory-1928`, a ticket key or a release-train name all behave
identically. Use whatever your project's development process requires, and record project-specific
branch-naming rules in `.spec-workflow/spec-workflow.supplemental.md`. Because the name carries no
meaning to the tooling, record the branch you actually used in `audit-trail.md` — that line is the
only durable link from a spec back to the work that closed it.

## Related rules

This rule covers the workflow only. Deployed alongside it, in the same rules directory:

- **spec-versioning** — when to bump a spec's `**Version:**`, what counts as substantive, deprecation.
- **plan-review-workflow** — the two-round architecture + security review to run before presenting a plan.
- **interaction-mode** — where a command's questions go (terminal, or a `## Open Questions` block in
  the spec for unattended runs) and the status ceiling an unanswered one imposes on the next step.
- **testing** — universal testing rules (step 5 produces the evidence; these rules govern how).
- **code-hygiene** — what "done" means for a change: no zombie code, docs and the architecture source kept true.
- **engineering-practices** — discovery before assumption, KISS/DRY/YAGNI, what not to introduce.
- **security** — when you touch `.env*` or `**/api/**`, injects the security rules located via `.spec-workflow/context-map.md` (`kind=security`; defaults to `docs/SECURITY-RULES.md`).

The workflow is stack- and design-agnostic. Optional stack/design profiles
(`.spec-workflow/profiles/`), and the **context map** (`.spec-workflow/context-map.md`) that says where
your governing context lives (architecture, security, business, ADRs, UX — repo files or external
tools/providers), are extension points the commands consult when present. Full contract:
<https://github.com/mode41/sd-workflow/blob/main/docs/extending-with-bundles.md>

<!-- source: .apm/instructions/spec-versioning.instructions.md -->


# Spec Versioning & Changelog

Every spec carries a `**Version:**` (`v1`, `v2`, …) and an inline `## Changelog` table
(`| Version | Date | Change | Driver |`). This keeps each spec reflecting what is actually built,
and makes its evolution traceable inline. The rules:

- A spec is a folder: `spec.md` (the contract, which carries `**Version:**` and `## Changelog`),
  `tech-design.md` (the HOW), `audit-trail.md` (the verification record), plus any attachments.
- A spec starts at `v1`. While it is still `🔵 In Planning`, edits are free drafting — no bump.
- Once a spec is `🟣 Planned` or later, **any substantive change** to its `spec.md` or
  `tech-design.md` must bump `**Version:**` and add a `## Changelog` row — both live in `spec.md`, so
  a change to `tech-design.md` is still recorded by bumping `spec.md`. Substantive = changes to
  overview, user stories, acceptance-criteria *text*, edge cases, or tech-design contracts. **Not**
  version-gated (no bump): advancing status, editing the changelog, editing `## Open Questions`
  (raising or answering a question is bookkeeping — but whatever the answer then *changes* in the
  contract or design is substantive, so cite the `Q-N` in that changelog row), ticking ACs,
  `audit-trail.md` (the verification record), and attachments (`mockups/`, `source/`, …) — so the normal
  implement → verify → close-out flow needs no bumps.
- The **Driver** column names *why*: the `SPEC-N` whose work drove the change (especially when
  another spec's design/implementation forced this one to change), or `self` for an in-spec
  revision, or `—` for the initial row.
- **Deprecation (drop, don't rewrite):** when a change makes a spec's feature no longer exist,
  deprecate it — set `⚫ Deprecated` in both the spec header and its INDEX row, bump its version +
  add a changelog row citing the obsoleting `SPEC-N`, append a short `## Deprecation` note to
  `spec.md`, and **keep the spec folder as a tombstone** (never delete it). Deprecated specs are
  frozen: the AC-closeout and status-floor checks no longer apply to them.
- `specs/INDEX.md` mirrors each spec's version in a `Version` column for at-a-glance visibility
  (kept updated by the workflow steps; not itself hook-enforced — the spec header + changelog are
  the source of truth).

The shared `.spec-workflow/hooks/check-spec-version.sh` (run as a git pre-commit check) blocks
committing when a Planned-or-later spec changed substantively — or was deprecated — without a version
bump + a new changelog row.

**Git still holds implementation history:** the inline changelog records *spec-level* evolution; code
-level detail lives in git commits (`git log --grep="SPEC-1"`). There is no separate changelog file —
the changelog is inline, per spec.

<!-- source: .apm/instructions/testing.instructions.md -->


# Testing

Stack-agnostic rules. The concrete framework, runner, and fixtures come from the project itself — see
Discovery First in the engineering-practices rules.

- **Write tests whenever introducing new logic, features, or significant changes.** Tests accompany the
  implementation; they are never deferred to "later".
- **Prefer what the project already has** — existing fixtures, sample data, base classes, and helpers —
  over ad-hoc ones you invent.
- **Test names describe behavior, not implementation** (`rejectsLoginWithEmptyPassword`, not `testLogin`).
- **Integration tests must exercise the real thing.** Never mock the database. Never substitute an
  in-memory engine for the production one when the production engine has features the substitute lacks.
  Never wrap test methods in framework-wide auto-rollback transactions — they hide lazy-loading and
  transaction-boundary bugs.
- **Do mock third-party external services** (payment gateways, identity providers, upstream APIs) —
  they are not yours to control in tests.
- **Never skip integration tests because "unit tests cover it."** They test different things.
- **Verify secrets and credentials are never included in API responses.**

The `$write-tests` command carries the full procedure — stack discovery, per-layer test targets, and
the pitfall checklist for integration tests.

