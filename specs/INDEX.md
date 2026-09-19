# Spec Index

> Central tracking for all specs. Status is set at each workflow step — `requirements`
> (In Planning), `technical-design` (Planned), implementation on the spec's branch
> (In Progress), and close-out (Validated) — and kept in lockstep with each spec's own
> `**Status:**` header by the shared `.spec-workflow/hooks/check-status-sync.sh` check (a git
> pre-commit hook). Cutting the branch does not by itself make a spec `In Progress` — set that when
> implementation actually starts. Branch names are yours to choose; nothing here reads them.

## Status Legend
- **🔵 In Planning** — requirements being written (the WHAT); spec not yet complete
- **🟣 Planned** — tech design done (the HOW); ready to implement
- **🟡 In Progress** — implementation underway on the spec's branch
- **🟠 In Review** — verification / QA underway (tests being written & run against the ACs)
- **🟢 Validated** — acceptance criteria met, tests green, complete
- **⚫ Deprecated** — spec dropped / superseded; kept as a tombstone (not rewritten) so its
  history stays traceable. Skipped in the build order below.

## Spec Versioning
Each spec carries a `**Version:**` (`v1`, `v2`, …) and an inline `## Changelog` — the **source of
truth** for how it evolved. Once a spec is Planned or later, any substantive change (or a
deprecation) must bump the version + add a changelog row naming the driving `SPEC-N`. The `Version`
column below is a convenience mirror the workflow commands keep updated; it is **not** hook-enforced
(only the spec's own header + changelog are).

## Backlog

A spec may live under `specs/backlog/SPEC-N-name/` instead of `specs/SPEC-N-name/` while it is parked.
The enforcement checks resolve the main tree first, then backlog, so a backlogged spec is held to the
same status, version and acceptance-criteria rules as any other.

## Specs

<!-- Column ORDER is load-bearing: the status-sync check reads Status as the 5th pipe-delimited
     field. Keep the 7 columns in this order (Status stays field $5). -->
| ID | Spec | Priority | Status | Version | File | Created |
|----|------|----------|--------|---------|------|---------|
| SPEC-1 | Codex CLI Support | P0 (MVP) | Validated | v1 | [Spec](SPEC-1-codex-support/spec.md) | 2026-09-17 |
| SPEC-2 | Security Reviewer Round Contract | P0 (MVP) | Validated | v1 | [Spec](SPEC-2-security-reviewer-round-contract/spec.md) | 2026-09-17 |

<!-- Add specs above this line -->

## Next Available ID: SPEC-3


## Recommended Build Order (MVP)

```
SPEC-1  Codex CLI Support                 (no deps)
SPEC-2  Security Reviewer Round Contract  (no deps; may proceed independently)
```
