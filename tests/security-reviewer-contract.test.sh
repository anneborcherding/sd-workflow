#!/usr/bin/env bash
# Contract and packaging tests for SPEC-2 security-reviewer round handling.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PASS=0; FAIL=0; SKIP=0
ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1" >&2; }
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s\n' "$1"; }

WORK="$(mktemp -d /tmp/sd-workflow-reviewer-contract.XXXXXX)" || exit 1
cleanup() {
  case "$WORK" in
    /tmp/sd-workflow-reviewer-contract.?*) [ -d "$WORK" ] && rm -rf -- "$WORK" ;;
    *) echo "unsafe cleanup path: $WORK" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

source="$ROOT/.apm/agents/security-reviewer.agent.md"
workflow="$ROOT/.apm/instructions/plan-review-workflow.instructions.md"

contains() { rg -F -q -- "$2" "$1"; }
absent() { ! rg -F -q -- "$2" "$1"; }

assert_contract() { # <artifact> <label>
  local artifact="$1" label="$2" valid=1
  [ -f "$artifact" ] || { bad "$label reviewer artifact exists"; return; }
  contains "$artifact" 'Round 1 receives only' || valid=0
  contains "$artifact" '`Original Plan`' || valid=0
  contains "$artifact" '`Relevant Context`' || valid=0
  contains "$artifact" 'It must not receive, assume, or' || valid=0
  contains "$artifact" 'rely on any architecture review.' || valid=0
  contains "$artifact" 'Round 2 receives the `Revised Plan`, `Change Log`, `Round 1 Security Review`' || valid=0
  contains "$artifact" 'Architecture Review`' || valid=0
  contains "$artifact" '**Context Status:** INVALID REVIEW CONTEXT' || valid=0
  contains "$artifact" 'If either Round 1 review is missing in Round 2' || valid=0
  contains "$artifact" 'do not issue a certifying Round 2 verdict' || valid=0
  contains "$artifact" 'If the round label is absent, infer Round 1 only' || valid=0
  absent "$artifact" 'You will receive the proposed plan and the architecture review.' || valid=0
  [ "$valid" -eq 1 ] && ok "$label preserves the round contract" || bad "$label loses or contradicts the round contract"
}

echo '1. Canonical contract'
assert_contract "$source" 'shared security reviewer'
if contains "$workflow" 'Do not include either review in the other agent' \
  && contains "$workflow" 'Label both invocations `Round 2`' \
  && contains "$workflow" 'it must not' \
  && contains "$workflow" 'issue a certifying verdict or claim cross-discipline findings are resolved.'; then
  ok 'plan-review workflow aligns with the reviewer contract'
else
  bad 'plan-review workflow contradicts or omits the reviewer contract'
fi

echo '2. Compiled reviewer matrix'
if ! command -v apm >/dev/null 2>&1; then
  skip 'apm unavailable; release CI must run the five-target matrix with APM 0.31+'
else
  version="$(apm --version 2>/dev/null | sed -n 's/.*version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)"
  major=${version%%.*}; remainder=${version#*.}; minor=${remainder%%.*}
  if [ -z "$version" ] || { [ "$major" -eq 0 ] && [ "$minor" -lt 31 ]; }; then
    skip "APM $version is below the five-target verification minimum"
  else
    target_matrix='claude:.claude/agents/security-reviewer.md
opencode:.opencode/agents/security-reviewer.md
cursor:.cursor/agents/security-reviewer.md
copilot:.github/agents/security-reviewer.agent.md
codex:.codex/agents/security-reviewer.toml'
    while IFS=: read -r target artifact; do
      fixture="$WORK/$target"
      mkdir -p "$fixture" || { bad "$target fixture creation"; continue; }
      if (cd "$fixture" && apm install "$ROOT" --target "$target" >/dev/null); then
        assert_contract "$fixture/$artifact" "$target compiled reviewer"
      else
        bad "$target compilation succeeds"
      fi
    done <<EOF
$target_matrix
EOF
  fi
fi

printf '\nSecurity reviewer contract: %s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
