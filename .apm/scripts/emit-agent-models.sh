#!/usr/bin/env bash
# emit-agent-models.sh — the PER-AGENT MODEL STAMPER.
#
# Writes each agent's configured model into the *deployed* agent file of every PRESENT harness that
# has an emitter. Runs on EVERY install/update, which is the point: APM tracks deployed agent files
# in apm.lock and overwrites them on `apm update`, so a model stamped last time is gone by the time
# this runs. Re-stamping from .spec-workflow/config.json repairs that automatically.
#
# Model values are written VERBATIM — the package never translates them, so any model the harness
# understands works (including local ones like ollama/qwen2.5-coder). An empty value means "leave
# this agent's frontmatter alone" (it inherits the harness default).
#
# Usage: emit-agent-models.sh <ROOT> <PKG> <CONFIG>
#   ROOT   = consumer project root
#   PKG    = the deployed .apm dir (agents/ lives here — the list of agents to stamp)
#   CONFIG = path to .spec-workflow/config.json
set -uo pipefail
ROOT="$1"
PKG="$2"
CONFIG="$3"

SELF="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=/dev/null
. "$SELF/config-lib.sh"   # config accessors + notice_add (feeds the installer's MANUAL-STEPS sink)

log() { printf '  [models] %s\n' "$1"; }

# Set `model:` inside the frontmatter of <file>, idempotently: replace an existing model line,
# else insert right after the description line. Leaves the file alone if it has no frontmatter.
stamp_model() {   # <file> <value>
  local file="$1" value="$2" tmp
  tmp=$(mktemp "$(dirname "$file")/.agent-model.XXXXXX") || { log "WARNING: secure temporary creation failed"; return 0; }

  head -1 "$file" 2>/dev/null | grep -q '^---[[:space:]]*$' || {
    log "WARNING: $(basename "$file") has no YAML frontmatter — not stamping."
    notice_add "Agent file $(basename "$file") has no YAML frontmatter — its configured model was not applied; it inherits the harness default."
    return 0
  }
  # Already correct? Don't rewrite (keeps runs idempotent and diffs clean).
  if awk 'NR>1 && /^---[[:space:]]*$/{exit} NR>1' "$file" | grep -q "^model:[[:space:]]*${value}[[:space:]]*$"; then
    return 0
  fi

  awk -v val="$value" '
    NR == 1 { print; next }                      # opening ---
    !done && /^---[[:space:]]*$/ {               # closing --- : insert before it if not yet placed
      if (!placed) { print "model: " val; placed = 1 }
      done = 1; print; next
    }
    !done && /^model:/ {                          # replace an existing model line
      if (!placed) { print "model: " val; placed = 1 }
      next
    }
    !done && /^description:/ { print; if (!placed) { print "model: " val; placed = 1 } next }
    { print }
  ' "$file" > "$tmp" && [ -s "$tmp" ] || { rm -f "$tmp"; log "WARNING: failed to stamp $(basename "$file")"; notice_add "Failed to stamp the model into $(basename "$file") — it inherits the harness default; check the file's frontmatter."; return 0; }
  mv "$tmp" "$file"
  return 1   # 1 = "changed", for the caller's counter
}

# emit <harness-key> <agents-dir> <extension>
emit() {
  local harness="$1" dir="$2" ext="$3" src stem value file changed=0 skipped=0
  for src in "$PKG"/agents/*.agent.md; do
    [ -e "$src" ] || continue
    stem="$(basename "$src" .agent.md)"
    value="$(config_model_for "$stem" "$harness")"
    [ -n "$value" ] || { skipped=$((skipped + 1)); continue; }
    file="$dir/$stem$ext"
    [ -f "$file" ] || { log "WARNING: $harness agent $stem$ext not deployed — skipping."; notice_add "$harness agent '$stem' is configured with a model but its file ($stem$ext) is not deployed — run 'apm install' to deploy it, then re-run this installer to stamp the model."; continue; }
    stamp_model "$file" "$value" || changed=$((changed + 1))
  done
  if [ "$changed" -gt 0 ]; then
    log "$harness: stamped $changed agent file(s) from config.json"
  elif [ "$skipped" -gt 0 ]; then
    log "$harness: $skipped agent(s) have no model set — inheriting the harness default"
  else
    log "$harness: already up to date"
  fi
}

emit_unsupported() {   # <harness> <why>
  log "$1 detected but has no model emitter yet — its agents inherit the harness default."
  notice_add "$1 detected — the installer cannot stamp reviewer models for it ($2). Its agents inherit the harness default; set models manually there if you need non-default ones."
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else return 1
  fi
}

# Return the unique APM content hash for an exact deployed path. The lockfile is repository trust
# metadata, not a cryptographic authority; strict shape/count checks prevent accidental adoption.
lock_hash_for() { # <relative-path>
  local lock="$ROOT/apm.lock.yaml" rel="$1" hashes count dep_owner deployment
  [ -f "$lock" ] && [ ! -L "$lock" ] || return 1
  grep -q "^lockfile_version: ['\"]\{0,1\}1['\"]\{0,1\}$" "$lock" || return 1
  hashes=$(awk -v rel="$rel" '
    /^- repo_url:/ { dep=0; files=0 }
    /^  name: spec-driven-workflow[[:space:]]*$/ { dep=1 }
    dep && /^  deployed_file_hashes:/ { files=1; next }
    files && /^    [^ ]/ {
      line=$0; sub(/^    /,"",line)
      key=line; sub(/:.*/,"",key)
      if (key==rel) { sub(/^[^:]*:[[:space:]]*sha256:/,"",line); print line }
      next
    }
    files && !/^    / { files=0 }
  ' "$lock")
  count=$(printf '%s\n' "$hashes" | awk 'NF{n++} END{print n+0}')
  [ "$count" -eq 1 ] || return 1
  hashes=$(printf '%s\n' "$hashes" | awk 'NF{print; exit}')
  printf '%s\n' "$hashes" | grep -Eq '^[0-9a-f]{64}$' || return 1
  dep_owner=$(awk '
    /^- repo_url:/ {
      if (wanted) { print (local != "" ? local : repo); exit }
      repo=$0; sub(/^- repo_url:[[:space:]]*/,"",repo); local=""; wanted=0; next
    }
    /^  name: spec-driven-workflow[[:space:]]*$/ { wanted=1; next }
    wanted && /^  local_path:/ { local=$0; sub(/^  local_path:[[:space:]]*/,"",local); next }
    /^deployments:/ && wanted { print (local != "" ? local : repo); exit }
  ' "$lock")
  [ -n "$dep_owner" ] || return 1
  deployment=$(awk -v rel="$rel" -v owner="$dep_owner" '
    /^- kind:/ { if (inblock && target=="codex" && value==rel && active==owner) print hash; inblock=1; target=""; value=""; active=""; hash=""; next }
    inblock && /^  target:/ { target=$0; sub(/^  target:[[:space:]]*/,"",target) }
    inblock && /^  value:/ { value=$0; sub(/^  value:[[:space:]]*/,"",value) }
    inblock && /^  active_owner:/ { active=$0; sub(/^  active_owner:[[:space:]]*/,"",active) }
    inblock && /^  content_hash: sha256:/ { hash=$0; sub(/^  content_hash: sha256:/,"",hash) }
    END { if (inblock && target=="codex" && value==rel && active==owner) print hash }
  ' "$lock")
  [ "$(printf '%s\n' "$deployment" | awk 'NF{n++} END{print n+0}')" -eq 1 ] || return 1
  [ "$deployment" = "$hashes" ] || return 1
  printf '%s\n' "$hashes"
}

validate_codex_agent() { # <file> <stem>
  local file="$1" stem="$2"
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  [ "$(grep -c '^name = ' "$file" 2>/dev/null)" -eq 1 ] || return 1
  [ "$(grep -c '^description = ' "$file" 2>/dev/null)" -eq 1 ] || return 1
  [ "$(grep -c '^developer_instructions = ' "$file" 2>/dev/null)" -eq 1 ] || return 1
  [ "$(grep -c '^model = ' "$file" 2>/dev/null || true)" -le 1 ] || return 1
  grep -q "^name = \"$stem\"$" "$file" || return 1
  grep -q '^\[' "$file" && return 1
  return 0
}

non_model_hash() { # <file>
  local tmp
  tmp=$(mktemp "$(dirname "$1")/.model-content.XXXXXX") || return 1
  sed '/^model = /d' "$1" > "$tmp" || { rm -f "$tmp"; return 1; }
  sha256_file "$tmp"; local rc=$?
  rm -f "$tmp"; return "$rc"
}

codex_state_valid() { # <state> <stem> <rel> <baseline> <current> <nonmodel>
  jq -e --arg s "$2" --arg p "$3" --arg b "$4" --arg c "$5" --arg n "$6" '
    .schemaVersion == 1 and .generatorVersion == 1
    and ((.agents // {}) | type == "object")
    and ([.agents[] | .path] | length == (unique | length))
    and (.agents[$s] | type == "object")
    and (.agents[$s] | keys | sort == ["baselineHash","dependency","model","nonModelHash","path","postHash"])
    and .agents[$s].dependency == "spec-driven-workflow"
    and .agents[$s].path == $p
    and .agents[$s].baselineHash == $b
    and .agents[$s].postHash == $c
    and .agents[$s].nonModelHash == $n
    and (.agents[$s].model | type == "string")
  ' "$1" >/dev/null 2>&1
}

write_codex_state() { # <state> <stem> <rel> <baseline> <model> <post> <nonmodel>
  local state="$1" tmp
  mkdir -p "$(dirname "$state")"
  tmp=$(mktemp "$(dirname "$state")/.agent-model-state.XXXXXX") || return 1
  if [ -f "$state" ]; then
    [ ! -L "$state" ] || { rm -f "$tmp"; return 1; }
    jq -e '.schemaVersion == 1 and .generatorVersion == 1 and ((.agents // {}) | type == "object")' "$state" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
    jq --arg s "$2" --arg p "$3" --arg b "$4" --arg m "$5" --arg h "$6" --arg n "$7" '
      .agents[$s] = {dependency:"spec-driven-workflow",path:$p,baselineHash:$b,model:$m,postHash:$h,nonModelHash:$n}
    ' "$state" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    jq -n --arg s "$2" --arg p "$3" --arg b "$4" --arg m "$5" --arg h "$6" --arg n "$7" '
      {schemaVersion:1,generatorVersion:1,agents:{($s):{dependency:"spec-driven-workflow",path:$p,baselineHash:$b,model:$m,postHash:$h,nonModelHash:$n}}}
    ' > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  chmod 600 "$tmp" && mv "$tmp" "$state"
}

stamp_codex_model() { # <file> <stem> <model>
  local file="$1" stem="$2" value="$3" rel baseline current nonmodel state prior encoded tmp post
  rel=".codex/agents/$stem.toml"
  state="$ROOT/.spec-workflow/agent-model-state.json"
  validate_codex_agent "$file" "$stem" || return 1
  case "$value" in *$'\n'*|*$'\r'*) return 1;; esac
  if printf '%s' "$value" | tr -d '\t' | LC_ALL=C grep -q '[[:cntrl:]]'; then return 1; fi
  baseline=$(lock_hash_for "$rel") || return 1
  current=$(sha256_file "$file") || return 1
  nonmodel=$(non_model_hash "$file") || return 1

  if [ "$current" != "$baseline" ]; then
    [ -f "$state" ] && [ ! -L "$state" ] || return 1
    codex_state_valid "$state" "$stem" "$rel" "$baseline" "$current" "$nonmodel" || return 1
    prior=$(jq -r --arg s "$stem" '.agents[$s].model' "$state")
    [ "$prior" != "$value" ] || return 2
  fi

  encoded=$(jq -Rn --arg v "$value" '$v') || return 1
  tmp=$(mktemp "$(dirname "$file")/.${stem}.XXXXXX") || return 1
  awk -v model="$encoded" '
    /^model = / { if (!placed) { print "model = " model; placed=1 }; next }
    /^developer_instructions = / && !placed { print "model = " model; placed=1 }
    { print }
    END { if (!placed) exit 1 }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  validate_codex_agent "$tmp" "$stem" || { rm -f "$tmp"; return 1; }
  post=$(sha256_file "$tmp") || { rm -f "$tmp"; return 1; }
  chmod --reference="$file" "$tmp" 2>/dev/null || chmod 600 "$tmp"
  mv "$tmp" "$file" || return 1
  if ! write_codex_state "$state" "$stem" "$rel" "$baseline" "$value" "$post" "$nonmodel"; then
    notice_add "Codex reviewer $stem was stamped but its provenance record failed; restore it with apm install/update, then rerun setup."
    return 1
  fi
  return 0
}

emit_codex() {
  local src stem value file changed=0 skipped=0
  for src in "$PKG"/agents/*.agent.md; do
    [ -e "$src" ] || continue
    stem="$(basename "$src" .agent.md)"
    value="$(config_model_for "$stem" codex)"
    [ -n "$value" ] || { skipped=$((skipped + 1)); continue; }
    file="$ROOT/.codex/agents/$stem.toml"
    [ -f "$file" ] || { notice_add "Codex agent '$stem' is configured but not deployed; run apm install and setup again."; continue; }
    stamp_codex_model "$file" "$stem" "$value"; rc=$?
    case "$rc" in
      0) changed=$((changed + 1));;
      2) ;;
      *) notice_add "Codex agent '$stem' was not changed because package ownership or TOML safety could not be proven.";;
    esac
  done
  [ "$changed" -eq 0 ] || log "codex: stamped $changed agent file(s) from config.json"
  [ "$changed" -ne 0 ] || [ "$skipped" -eq 0 ] || log "codex: $skipped agent(s) have no model set — inheriting the harness default"
}

[ -f "$CONFIG" ] || { log "no config.json found; skipping model stamping"; exit 0; }
command -v jq >/dev/null 2>&1 || { log "jq unavailable; skipping model stamping"; exit 0; }

[ -d "$ROOT/.claude/agents" ]   && emit claude   "$ROOT/.claude/agents"   ".md"
[ -d "$ROOT/.opencode/agents" ] && emit opencode "$ROOT/.opencode/agents" ".md"
# Copilot's `model:` is a YAML *list* of UI display names, not a string — needs a list-shaped
# config value before we can stamp it safely.
[ -d "$ROOT/.github/agents" ]   && emit_unsupported "Copilot" "its model: is a YAML list of UI display names, not a string"
[ -d "$ROOT/.codex/agents" ]    && emit_codex
exit 0
