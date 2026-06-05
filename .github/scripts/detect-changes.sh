#!/usr/bin/env bash
# Maps changed files to the {env, workspace} pairs they affect.
#
# Usage:
#   git diff --name-only <range> | detect-changes.sh   # detect from changed files
#   detect-changes.sh --all                            # every env x workspace on disk
#
# Prints GitHub Actions outputs:
#   matrix=<JSON array of {"env","workspace"} objects for a matrix include>
#   any=<true|false>
#
# Mapping:
#   dev/workspaces/<ws>/**   -> dev x ws
#   prod/workspaces/<ws>/**  -> prod x ws
#   base/workspaces/<ws>/**  -> dev x ws AND prod x ws  (base is layered under both)
#   config.yaml, vars.yaml   -> all envs x all workspaces found on disk
set -euo pipefail

ENVS="dev prod"
PAIRS=""

add_pair() {
  PAIRS="${PAIRS}${1} ${2}
"
}

add_all() {
  local env ws
  for env in $ENVS; do
    [ -d "$env/workspaces" ] || continue
    for ws in "$env"/workspaces/*/; do
      [ -d "$ws" ] || continue
      add_pair "$env" "$(basename "$ws")"
    done
  done
}

if [ "${1:-}" = "--all" ]; then
  add_all
else
  while IFS= read -r file; do
    case "$file" in
      config.yaml|vars.yaml)
        add_all ;;
      dev/workspaces/*/*)
        add_pair dev "$(echo "$file" | cut -d/ -f3)" ;;
      prod/workspaces/*/*)
        add_pair prod "$(echo "$file" | cut -d/ -f3)" ;;
      base/workspaces/*/*)
        ws="$(echo "$file" | cut -d/ -f3)"
        add_pair dev "$ws"
        add_pair prod "$ws" ;;
    esac
  done
fi

matrix=$(printf '%s' "$PAIRS" | sort -u | while read -r env ws; do
  [ -n "$env" ] || continue
  printf '{"env":"%s","workspace":"%s"}\n' "$env" "$ws"
done | jq -sc '.')

if [ "$matrix" = "[]" ]; then
  any=false
else
  any=true
fi

echo "matrix=$matrix"
echo "any=$any"
