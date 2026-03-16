#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/README.md.tpl"
OUTPUT="$REPO_ROOT/README.md"

# Format star count: 0 → "—", 1-999 → exact, 1000-1099 → "1k", 1100+ → "X.Yk" (truncated)
# Output is right-aligned to 4 chars using &nbsp; for fixed-width display in <code> blocks
format_stars() {
  local count="$1"
  local value
  if [ "$count" -eq 0 ]; then
    value="—"
  elif [ "$count" -lt 1000 ]; then
    value="$count"
  elif [ "$count" -lt 1100 ]; then
    value="1k"
  else
    local major=$((count / 1000))
    local minor=$(( (count % 1000) / 100 ))
    value="${major}.${minor}k"
  fi
  # Right-align to 4 characters, padding with &nbsp;
  local len=${#value}
  local pad=$((4 - len))
  local prefix=""
  for ((i = 0; i < pad; i++)); do
    prefix="${prefix}&nbsp;"
  done
  echo "${prefix}${value}"
}

# Read template
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: Template not found: $TEMPLATE" >&2
  exit 1
fi

content="$(cat "$TEMPLATE")"

# Find all {{STARS:owner/repo}} placeholders and replace them
placeholders="$(grep -oE '\{\{STARS:[^}]+\}\}' "$TEMPLATE" | sort -u)"

for placeholder in $placeholders; do
  # Extract owner/repo from {{STARS:owner/repo}}
  repo="${placeholder#\{\{STARS:}"
  repo="${repo%\}\}}"

  echo "Fetching stars for $repo..." >&2
  star_count="$(gh api "repos/$repo" --jq '.stargazers_count')" || {
    echo "ERROR: Failed to fetch stars for $repo" >&2
    exit 1
  }

  formatted="$(format_stars "$star_count")"
  echo "  $repo: $star_count → $formatted" >&2

  # Escape & for sed replacement (& means "matched text" in sed)
  escaped="${formatted//&/\\&}"
  content="$(echo "$content" | sed "s|{{STARS:$repo}}|$escaped|g")"
done

echo "$content" > "$OUTPUT"
echo "README.md updated successfully." >&2
