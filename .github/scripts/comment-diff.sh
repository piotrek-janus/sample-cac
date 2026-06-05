#!/usr/bin/env bash
# Creates or updates the sticky PR comment holding the cac diff for one
# env/workspace pair. The comment is identified by a hidden HTML marker.
#
# Expects env vars: GH_TOKEN, ENV_NAME, WORKSPACE, PR_NUMBER, HEAD_SHA, RUN_URL
# (GITHUB_REPOSITORY is provided by the runner.)
# Expects diff.txt in the working directory (written by `cac diff --out diff.txt`).
set -euo pipefail

LIMIT=60000  # GitHub comment hard limit is 65536 chars; leave headroom
export MARKER="<!-- cac-diff:${ENV_NAME}:${WORKSPACE} -->"

diff_content="$(cat diff.txt)"

if [ -z "$(printf '%s' "$diff_content" | tr -d '[:space:]')" ]; then
  details="_No changes — the live environment already matches this configuration._"
else
  if [ "${#diff_content}" -gt "$LIMIT" ]; then
    diff_content="${diff_content:0:$LIMIT}
... (truncated — full diff in the workflow run)"
  fi
  details="<details>
<summary>Show diff</summary>

\`\`\`diff
${diff_content}
\`\`\`

</details>"
fi

body="${MARKER}
### CAC diff: \`${ENV_NAME}\` / \`${WORKSPACE}\`

${details}

_What \`cac push --method patch\` would apply on merge. Commit ${HEAD_SHA} · [workflow run](${RUN_URL})_"

comment_id="$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --paginate --jq '.[] | select(.body | startswith(env.MARKER)) | .id' | head -n1)"

if [ -n "$comment_id" ]; then
  gh api --method PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" \
    -f body="$body" --silent
  echo "Updated comment ${comment_id}"
else
  gh api --method POST "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -f body="$body" --silent
  echo "Created new comment"
fi
