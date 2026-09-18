#!/usr/bin/env bash
# Generate the committed Codex/Agent Skills collection from canonical APM primitives.
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$SELF/../.." && pwd -P)"
MANIFEST="$SELF/codex-primitives.tsv"
OUT="$ROOT/.apm/skills"
MODE="${1:-write}"

case "$MODE" in
  write|--check) ;;
  *) echo "usage: $0 [write|--check]" >&2; exit 2 ;;
esac

[ -f "$MANIFEST" ] && [ ! -L "$MANIFEST" ] || {
  echo "sync-codex-skills: manifest must be a regular non-symlink file" >&2
  exit 1
}

stage="$(mktemp -d "/tmp/sd-workflow-skills.XXXXXX")" || exit 1
case "$(cd "$stage/.." && pwd -P)/$(basename "$stage")" in
  /tmp/sd-workflow-skills.*) ;;
  *) echo "sync-codex-skills: unsafe temporary directory" >&2; exit 1 ;;
esac
trap 'case "$stage" in /tmp/sd-workflow-skills.*) rm -rf -- "$stage";; esac' EXIT HUP INT TERM
chmod 700 "$stage"

strip_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { front = 1; next }
    front && $0 == "---" { front = 0; next }
    !front { print }
  ' "$1"
}

codex_invocations() {
  sed \
    -e 's#/requirements#$requirements#g' \
    -e 's#/technical-design#$technical-design#g' \
    -e 's#/write-tests#$write-tests#g' \
    -e 's#/frontend-architecture#$frontend-architecture#g'
}

validate_name() {
  case "$1" in
    ''|*[!a-z0-9-]*|-*|*-) return 1 ;;
  esac
}

seen='|'
tab="$(printf '\t')"
while IFS="$tab" read -r name description kind sources extra; do
  case "$name" in ''|'#'*) continue;; esac
  [ -z "${extra:-}" ] || { echo "sync-codex-skills: malformed manifest row for $name" >&2; exit 1; }
  validate_name "$name" || { echo "sync-codex-skills: invalid skill name: $name" >&2; exit 1; }
  case "$seen" in *"|$name|"*) echo "sync-codex-skills: duplicate skill: $name" >&2; exit 1;; esac
  seen="$seen$name|"
  case "$description" in ''|*$'\n'*|*$'\r'*) echo "sync-codex-skills: invalid description for $name" >&2; exit 1;; esac
  dest="$stage/$name"
  mkdir -p "$dest"
  {
    echo '---'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$description"
    echo '---'
    echo
    case "$kind" in
      prompt)
        case "$sources" in .apm/prompts/*.prompt.md) ;; *) echo "invalid prompt source: $sources" >&2; exit 1;; esac
        src="$ROOT/$sources"
        [ -f "$src" ] && [ ! -L "$src" ] || { echo "missing regular source: $sources" >&2; exit 1; }
        strip_frontmatter "$src" | codex_invocations
        ;;
      instructions)
        oldifs="$IFS"; IFS=','
        for source in $sources; do
          IFS="$oldifs"
          case "$source" in .apm/instructions/*.instructions.md) ;; *) echo "invalid instruction source: $source" >&2; exit 1;; esac
          src="$ROOT/$source"
          [ -f "$src" ] && [ ! -L "$src" ] || { echo "missing regular source: $source" >&2; exit 1; }
          printf '<!-- source: %s -->\n\n' "$source"
          strip_frontmatter "$src" | codex_invocations
          echo
          IFS=','
        done
        IFS="$oldifs"
        ;;
      *) echo "sync-codex-skills: invalid source kind for $name: $kind" >&2; exit 1;;
    esac
  } > "$dest/SKILL.md"

  if rg -n '(^|[[:space:]`(])/(requirements|technical-design|write-tests|frontend-architecture)([[:space:]`)]|$)' "$dest/SKILL.md" >/dev/null; then
    echo "sync-codex-skills: unsupported slash invocation remains in $name" >&2
    exit 1
  fi
done < "$MANIFEST"

for required in requirements technical-design write-tests frontend-architecture spec-driven-workflow; do
  [ -f "$stage/$required/SKILL.md" ] || { echo "sync-codex-skills: missing manifest entry: $required" >&2; exit 1; }
done

if [ "$MODE" = "--check" ]; then
  stale=0
  for generated in "$stage"/*/SKILL.md; do
    name="$(basename "$(dirname "$generated")")"
    if [ ! -f "$OUT/$name/SKILL.md" ] || ! cmp -s "$generated" "$OUT/$name/SKILL.md"; then
      echo "sync-codex-skills: stale skill: $name" >&2
      stale=1
    fi
  done
  for existing in "$OUT"/*/SKILL.md; do
    [ -e "$existing" ] || continue
    name="$(basename "$(dirname "$existing")")"
    [ -f "$stage/$name/SKILL.md" ] || { echo "sync-codex-skills: undeclared skill: $name" >&2; stale=1; }
  done
  exit "$stale"
fi

mkdir -p "$OUT"
for generated in "$stage"/*/SKILL.md; do
  name="$(basename "$(dirname "$generated")")"
  target="$OUT/$name"
  [ ! -L "$target" ] || { echo "sync-codex-skills: refusing symlink target: $target" >&2; exit 1; }
  mkdir -p "$target"
  [ ! -L "$target/SKILL.md" ] || { echo "sync-codex-skills: refusing symlink file: $target/SKILL.md" >&2; exit 1; }
  mv "$generated" "$target/SKILL.md"
done
chmod 755 "$SELF/sync-codex-skills.sh"
