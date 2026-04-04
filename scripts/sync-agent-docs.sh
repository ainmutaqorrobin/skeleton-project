#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rules_root="$repo_root/.ai/rules"

pairs=(
  "root.md:"
  "api.md:apps/api"
  "frontend.md:apps/frontend"
  "common.md:apps/common"
  "docker.md:apps/docker"
  "packages.md:apps/packages"
)

render_doc() {
  local title="$1"
  local body="$2"
  cat <<EOF
# ${title}

This file is generated from \`.ai/rules\`. Edit the source templates there, then run \`scripts/sync-agent-docs.ps1\` or \`scripts/sync-agent-docs.sh\`.

${body}
EOF
}

for pair in "${pairs[@]}"; do
  rule="${pair%%:*}"
  rel_dir="${pair#*:}"
  rule_path="$rules_root/$rule"
  raw_body="$(cat "$rule_path")"

  for doc_name in AGENTS.md CLAUDE.md; do
    body="${raw_body//\{\{DOC_NAME\}\}/$doc_name}"
    if [[ -n "$rel_dir" ]]; then
      out_dir="$repo_root/$rel_dir"
    else
      out_dir="$repo_root"
    fi
    render_doc "$doc_name" "$body" > "$out_dir/$doc_name"
  done
done

echo "Synced AGENTS.md and CLAUDE.md files from .ai/rules"
