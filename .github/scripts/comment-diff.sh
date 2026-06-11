#!/usr/bin/env bash
# Creates or updates the sticky PR comment holding the cac diff for one
# env/workspace pair. The comment is identified by a hidden HTML marker.
#
# Expects env vars: GH_TOKEN, ENV_NAME, WORKSPACE, PR_NUMBER, HEAD_SHA, RUN_URL
# (GITHUB_REPOSITORY is provided by the runner.)
# Optional: METHOD (patch|import, default patch), IS_NEW (true|false, default false)
#           — set by resolve-method.sh to reflect what merging will actually do.
# Expects diff.txt in the working directory (written by `cac diff --out diff.txt`
# on update, or a notice written by resolve-method.sh when the workspace is new).
set -euo pipefail

LIMIT=60000  # GitHub comment hard limit is 65536 chars; leave headroom
METHOD="${METHOD:-patch}"
IS_NEW="${IS_NEW:-false}"
export MARKER="<!-- cac-diff:${ENV_NAME}:${WORKSPACE} -->"

if [ ! -f diff.txt ]; then
  echo "ERROR: diff.txt not found — was 'cac diff --out diff.txt' run?" >&2
  exit 1
fi

diff_content="$(cat diff.txt)"

if [ "$IS_NEW" = "true" ]; then
  # New workspace: there is nothing on the remote to diff against — it will be
  # created wholesale. Make that unmistakable instead of showing a code diff.
  details="> 🆕 **New workspace — will be imported.**
>
> \`${WORKSPACE}\` does not exist on \`${ENV_NAME}\` yet. Merging this PR will
> **import** it, creating it from this repository's configuration."
elif [ -z "$(printf '%s' "$diff_content" | tr -d '[:space:]')" ]; then
  details="_No changes — the live environment already matches this configuration._"
else
  if [ "${#diff_content}" -gt "$LIMIT" ]; then
    diff_content="${diff_content:0:$LIMIT}"
    # drop the (possibly partial) last line so we never cut mid-character
    diff_content="${diff_content%$'\n'*}
... (truncated — full diff in the workflow run)"
  fi
  # 4-backtick fence so ``` inside the diff cannot break out of the code block
  details="<details>
<summary>Show diff</summary>

\`\`\`\`diff
${diff_content}
\`\`\`\`

</details>"
fi

body="${MARKER}
### CAC diff: \`${ENV_NAME}\` / \`${WORKSPACE}\`

${details}

_What \`cac push --method ${METHOD}\` would apply on merge. Commit ${HEAD_SHA} · [workflow run](${RUN_URL})_"

comment_id="$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --paginate --jq '.[] | select(.body | startswith(env.MARKER)) | .id' | sed -n '1p')"

if [ -n "$comment_id" ]; then
  gh api --method PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" \
    -f body="$body" --silent
  echo "Updated comment ${comment_id}"
else
  gh api --method POST "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -f body="$body" --silent
  echo "Created new comment"
fi
