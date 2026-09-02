#!/usr/bin/env bash
# Give Codex the same useful at-a-glance information as the Claude status line:
# the thread's task-shaped title and remaining context.
set -euo pipefail

codex_config_dir="${1:-${CODEX_HOME:-$HOME/.codex}}"
config_file="$codex_config_dir/config.toml"
status_line='status_line = ["thread-title", "context-remaining"]'

mkdir -p "$codex_config_dir"

if [[ ! -e "$config_file" ]]; then
    printf '[tui]\n%s\n' "$status_line" > "$config_file"
    exit 0
fi

# Respect an existing choice, whether it uses a root dotted key or a [tui]
# table. This keeps rerunning setup idempotent and avoids replacing Codex's
# machine-generated settings.
if grep -Eq '^[[:space:]]*(tui\.)?status_line[[:space:]]*=' "$config_file"; then
    exit 0
fi

if grep -Eq '^[[:space:]]*\[tui\][[:space:]]*(#.*)?$' "$config_file"; then
    temp_file=$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")
    trap 'rm -f "$temp_file"' EXIT
    awk -v setting="$status_line" '
        { print }
        !added && $0 ~ /^[[:space:]]*\[tui\][[:space:]]*(#.*)?$/ {
            print setting
            added = 1
        }
    ' "$config_file" > "$temp_file"
    cp "$temp_file" "$config_file"
else
    printf '\n[tui]\n%s\n' "$status_line" >> "$config_file"
fi
