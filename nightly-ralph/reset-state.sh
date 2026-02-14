#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/state}"

QUEUE_FILE="$STATE_DIR/topic-queue.txt"
SIGNATURE_FILE="$STATE_DIR/topic-signatures.sha256"
DONE_FILE="$STATE_DIR/topic-done.jsonl"
SKIP_FILE="$STATE_DIR/topic-skip.jsonl"

mkdir -p "$STATE_DIR"

confirm="${1:-}"
if [ "$confirm" != "--yes" ]; then
  echo "[WARN] state 파일을 초기화합니다: $STATE_DIR"
  echo "[INFO] 실행하려면 아래처럼 입력하세요."
  echo "       ./nightly-ralph/reset-state.sh --yes"
  exit 1
fi

: > "$QUEUE_FILE"
: > "$SIGNATURE_FILE"
: > "$DONE_FILE"
: > "$SKIP_FILE"

echo "[INFO] nightly state reset complete: $STATE_DIR"
