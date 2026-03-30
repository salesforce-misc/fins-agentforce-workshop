#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: tools/preview-markdown.sh /absolute/path/to/file.md [port]"
  exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
fi

MD_FILE="$1"
PORT="${2:-8080}"

if [ ! -f "$MD_FILE" ]; then
  echo "Markdown file not found: $MD_FILE" >&2
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid port: $PORT (expected an integer)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="${SCRIPT_DIR}/markdown-preview/server.mjs"

MD_ABS="$(cd "$(dirname "$MD_FILE")" && pwd)/$(basename "$MD_FILE")"

echo "Markdown preview running at: http://localhost:${PORT}"
echo "Serving markdown: ${MD_ABS}"
echo "Press Ctrl-C to stop."

node "${SERVER_FILE}" --md "${MD_ABS}" --port "${PORT}"

