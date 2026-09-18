#!/usr/bin/env bash
# Behavioral and packaging tests for SPEC-1 Codex CLI support.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PASS=0; FAIL=0; SKIP=0
ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  not ok  %s\n' "$1" >&2; }
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s\n' "$1"; }

WORK="$(mktemp -d /tmp/sd-workflow-codex-test.XXXXXX)" || exit 1
cleanup() {
  case "$WORK" in /tmp/sd-workflow-codex-test.*) rm -rf -- "$WORK";; *) echo "unsafe cleanup path: $WORK" >&2;; esac
}
trap cleanup EXIT HUP INT TERM

echo '1. Generated skill contract'
if bash "$ROOT/.apm/scripts/sync-codex-skills.sh" --check; then ok 'committed skills match canonical sources'; else bad 'committed skills are stale'; fi
count=$(find "$ROOT/.apm/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')
[ "$count" = 5 ] && ok 'five Codex skills are declared' || bad "expected five Codex skills, got $count"
if ! rg -n '(^|[[:space:]`(])/(requirements|technical-design|write-tests|frontend-architecture)([[:space:]`)]|$)' "$ROOT/.apm/skills" >/dev/null; then
  ok 'generated skills contain no unsupported workflow slash invocations'
else
  bad 'generated skill retains an unsupported slash invocation'
fi
for skill in requirements technical-design write-tests frontend-architecture spec-driven-workflow; do
  file="$ROOT/.apm/skills/$skill/SKILL.md"
  if [ -f "$file" ] && [ "$(sed -n '2s/^name: //p' "$file")" = "$skill" ] && sed -n '3p' "$file" | grep -q '^description: .'; then
    ok "$skill has valid required metadata"
  else
    bad "$skill metadata is invalid"
  fi
done

echo '2. APM Codex deployment'
if ! command -v apm >/dev/null 2>&1; then
  skip 'apm unavailable; release CI must run this suite with APM 0.31+'
else
  version=$(apm --version 2>/dev/null | sed -n 's/.*version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)
  major=${version%%.*}; rest=${version#*.}; minor=${rest%%.*}
  if [ -z "$version" ] || { [ "$major" -eq 0 ] && [ "$minor" -lt 31 ]; }; then
    skip "APM $version is below the Codex-support minimum; release CI must provide 0.31+"
  else
    consumer="$WORK/consumer"; mkdir -p "$consumer/.codex"
    if ( cd "$consumer" && apm install "$ROOT" --target codex >/dev/null ); then
      deployed=1
      for skill in requirements technical-design write-tests frontend-architecture spec-driven-workflow; do
        [ -f "$consumer/.agents/skills/$skill/SKILL.md" ] || deployed=0
      done
      [ -f "$consumer/.codex/agents/architecture-reviewer.toml" ] || deployed=0
      [ -f "$consumer/.codex/agents/security-reviewer.toml" ] || deployed=0
      [ "$deployed" -eq 1 ] && ok 'APM deploys all skills and reviewer agents' || bad 'APM Codex deployment is incomplete'

      script=$(find "$consumer/apm_modules" -path '*/.apm/scripts/init-and-wire.sh' | head -1)
      if APM_PROJECT_DIR="$consumer" bash "$script" >/dev/null; then ok 'explicit setup succeeds for Codex'; else bad 'explicit setup failed for Codex'; fi
      if rg -q '\.agents/skills/spec-driven-workflow/SKILL.md' "$consumer/AGENTS.md"; then ok 'seeded AGENTS.md requires shared workflow rules'; else bad 'seeded AGENTS.md lacks shared workflow rule'; fi

      jq '.agents["architecture-reviewer"].model.codex="gpt-test-a"' "$consumer/.spec-workflow/config.json" > "$consumer/.spec-workflow/config.next"
      mv "$consumer/.spec-workflow/config.next" "$consumer/.spec-workflow/config.json"
      APM_PROJECT_DIR="$consumer" bash "$script" >/dev/null
      first=$(sha256sum "$consumer/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
      APM_PROJECT_DIR="$consumer" bash "$script" >/dev/null
      second=$(sha256sum "$consumer/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
      [ "$first" = "$second" ] && ok 'same-model setup is byte-stable' || bad 'same-model setup rewrote reviewer agent'

      jq '.agents["architecture-reviewer"].model.codex="gpt-test-b"' "$consumer/.spec-workflow/config.json" > "$consumer/.spec-workflow/config.next"
      mv "$consumer/.spec-workflow/config.next" "$consumer/.spec-workflow/config.json"
      APM_PROJECT_DIR="$consumer" bash "$script" >/dev/null
      if grep -q '^model = "gpt-test-b"$' "$consumer/.codex/agents/architecture-reviewer.toml"; then ok 'known package transformation permits model A to B'; else bad 'model A to B failed'; fi

      printf '\n# user drift\n' >> "$consumer/.codex/agents/architecture-reviewer.toml"
      drifted=$(sha256sum "$consumer/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
      jq '.agents["architecture-reviewer"].model.codex="gpt-test-c"' "$consumer/.spec-workflow/config.json" > "$consumer/.spec-workflow/config.next"
      mv "$consumer/.spec-workflow/config.next" "$consumer/.spec-workflow/config.json"
      APM_PROJECT_DIR="$consumer" bash "$script" >/dev/null
      after=$(sha256sum "$consumer/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
      [ "$drifted" = "$after" ] && ok 'drifted reviewer agent fails closed' || bad 'drifted reviewer agent was modified'
    else
      bad 'local APM Codex installation failed'
    fi

    collision="$WORK/collision"; mkdir -p "$collision/.codex/agents" "$collision/.agents/skills/requirements"
    printf '%s\n' 'USER-SKILL-SENTINEL' > "$collision/.agents/skills/requirements/SKILL.md"
    printf '%s\n' 'USER-AGENT-SENTINEL' > "$collision/.codex/agents/architecture-reviewer.toml"
    before=$(sha256sum "$collision/.agents/skills/requirements/SKILL.md" | awk '{print $1}')
    agent_before=$(sha256sum "$collision/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
    ( cd "$collision" && apm install "$ROOT" --target codex >/dev/null 2>&1 ); rc=$?
    after=$(sha256sum "$collision/.agents/skills/requirements/SKILL.md" | awk '{print $1}')
    agent_after=$(sha256sum "$collision/.codex/agents/architecture-reviewer.toml" | awk '{print $1}')
    if [ "$before" = "$after" ]; then ok 'skill collision is skipped without overwriting user data'; else bad 'skill collision overwrote user data'; fi
    if [ "$agent_before" = "$agent_after" ]; then ok 'reviewer-agent collision is skipped without overwriting user data'; else bad 'reviewer-agent collision overwrote user data'; fi

    preserve="$WORK/preserve"; mkdir -p "$preserve/.codex/agents" "$preserve/.agents/skills/user-skill"
    printf '%s\n' 'USER-AGENTS-SENTINEL' > "$preserve/AGENTS.md"
    printf '%s\n' 'USER-OVERRIDE-SENTINEL' > "$preserve/AGENTS.override.md"
    printf '%s\n' 'model = "user-choice"' > "$preserve/.codex/config.toml"
    printf '%s\n' 'USER-AGENT-SENTINEL' > "$preserve/.codex/agents/user-agent.toml"
    printf '%s\n' 'USER-SKILL-SENTINEL' > "$preserve/.agents/skills/user-skill/SKILL.md"
    before=$(find "$preserve" -type f -print0 | sort -z | xargs -0 sha256sum)
    if ( cd "$preserve" && apm install "$ROOT" --target codex >/dev/null ); then
      script=$(find "$preserve/apm_modules" -path '*/.apm/scripts/init-and-wire.sh' | head -1)
      APM_PROJECT_DIR="$preserve" bash "$script" >/dev/null
      preserved=1
      grep -q '^USER-AGENTS-SENTINEL$' "$preserve/AGENTS.md" || preserved=0
      grep -q '^USER-OVERRIDE-SENTINEL$' "$preserve/AGENTS.override.md" || preserved=0
      grep -q '^model = "user-choice"$' "$preserve/.codex/config.toml" || preserved=0
      grep -q '^USER-AGENT-SENTINEL$' "$preserve/.codex/agents/user-agent.toml" || preserved=0
      grep -q '^USER-SKILL-SENTINEL$' "$preserve/.agents/skills/user-skill/SKILL.md" || preserved=0
      [ "$preserved" -eq 1 ] && ok 'setup preserves existing Codex and instruction data' || bad 'setup changed existing user data'
      if rg -q 'AGENTS.md exists without the workflow section' "$preserve/.spec-workflow/MANUAL-STEPS.md"; then ok 'unmerged AGENTS.md produces an actionable manual step'; else bad 'existing AGENTS.md was not reported'; fi
    else
      bad 'preservation fixture installation failed'
    fi

    mixed="$WORK/mixed"; mkdir -p "$mixed/.codex" "$mixed/.claude"
    if ( cd "$mixed" && apm install "$ROOT" --target codex,claude >/dev/null ); then
      if [ -f "$mixed/.agents/skills/requirements/SKILL.md" ] && [ -n "$(find "$mixed/.claude" -type f -print -quit)" ]; then
        ok 'mixed Codex and legacy harness deployment succeeds'
      else
        bad 'mixed harness deployment omitted expected artifacts'
      fi
    else
      bad 'mixed Codex and legacy harness installation failed'
    fi
  fi
fi

echo '3. Installer path safety'
host="$WORK/outside"; fixture="$WORK/symlink-fixture"; mkdir -p "$host" "$fixture"
ln -s "$host" "$fixture/.spec-workflow"
if APM_PROJECT_DIR="$fixture" bash "$ROOT/.apm/scripts/init-and-wire.sh" >/dev/null 2>&1; then
  bad 'symlinked .spec-workflow was accepted'
elif [ -z "$(find "$host" -mindepth 1 -print -quit)" ]; then
  ok 'symlinked managed directory fails before outside writes'
else
  bad 'symlink preflight wrote outside the fixture'
fi

old="$WORK/old-apm"; fakebin="$WORK/fakebin"; mkdir -p "$old/.codex/agents" "$fakebin"
printf '%s\n' 'name = "architecture-reviewer"' > "$old/.codex/agents/architecture-reviewer.toml"
printf '%s\n' '#!/bin/sh' 'echo "Agent Package Manager (APM) CLI version 0.30.9"' > "$fakebin/apm"
chmod +x "$fakebin/apm"
if PATH="$fakebin:$PATH" APM_PROJECT_DIR="$old" bash "$ROOT/.apm/scripts/init-and-wire.sh" >/dev/null 2>&1; then
  bad 'APM below 0.31 was accepted for Codex'
elif [ ! -e "$old/.spec-workflow" ]; then
  ok 'unsupported APM version fails before setup writes'
else
  bad 'unsupported APM version wrote setup data before failing'
fi

echo '4. Existing regression suite'
if bash "$ROOT/tests/enforcement.test.sh" >/dev/null; then ok 'existing enforcement suite remains green'; else bad 'existing enforcement suite regressed'; fi

printf '\nCodex support: %s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
