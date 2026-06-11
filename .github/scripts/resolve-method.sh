#!/usr/bin/env bash
# Decides whether merging a workspace's config will CREATE it or UPDATE it on
# the live environment, by probing the remote with `cac diff`.
#
#   diff succeeds            -> workspace exists remotely -> method=patch
#   diff fails with 404      -> workspace is new          -> method=import
#   diff fails for any other -> real error, propagate (exit 1)
#
# `patch` merges the repo config onto the existing workspace; `import` creates
# the workspace from the repo config. Importing is only safe (and only needed)
# when the workspace does not exist yet — hence the existence probe.
#
# Side effects:
#   - Writes the diff to diff.txt on success, or a "will be imported" notice
#     when the workspace is new, so the caller can post it on a PR.
#   - Emits to $GITHUB_OUTPUT (when set):  method=patch|import  is_new=true|false
#
# Requires: /tmp/cac present, CAC client secret + TENANT_ID in the environment.
# Must be run from the repository root.
#
# Usage: resolve-method.sh <env> <workspace>     # env: dev | prod
set -uo pipefail

ENV_NAME="${1:?usage: resolve-method.sh <env> <workspace>}"
WORKSPACE="${2:?usage: resolve-method.sh <env> <workspace>}"

# The active environment's client config is supplied via env vars (<env>/.env);
# there is no cac profile to select.

emit() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1=$2" >> "$GITHUB_OUTPUT"; }

# Probe the remote. --only-present/--no-volatile mirror the PR diff so a
# successful probe doubles as the diff we post. Capture stderr too: the
# not-found signal arrives as an error, not on stdout.
out=$(/tmp/cac diff --config config.yaml --no-volatile --only-present \
  --workspace "$WORKSPACE" \
  --source merged --target remote --colors=false --out diff.txt 2>&1)
code=$?

if [ "$code" -eq 0 ]; then
  echo "Workspace '$WORKSPACE' exists on '$ENV_NAME' -> method=patch"
  emit method patch
  emit is_new false
  exit 0
fi

# Only the export-not-found error means "new". Anything else (auth, network,
# validation) is a genuine failure and must not be mistaken for a new workspace.
if printf '%s' "$out" | grep -qiE 'exportWorkspaceConfigNotFound|"status_code":404|server not found'; then
  echo "Workspace '$WORKSPACE' not found on '$ENV_NAME' -> NEW, method=import"
  emit method import
  emit is_new true
  # The failed read may have left diff.txt empty/stale; replace it with a notice.
  printf '%s\n' \
    "This workspace does not exist on ${ENV_NAME} yet." \
    "Merging will IMPORT it — creating it from this repository's configuration." \
    > diff.txt
  exit 0
fi

echo "cac diff failed for '$WORKSPACE' on '$ENV_NAME' (exit $code):" >&2
printf '%s\n' "$out" >&2
exit 1
