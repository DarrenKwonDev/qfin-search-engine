#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ] || [ -n "${POSIXLY_CORRECT:-}" ]; then
  unset POSIXLY_CORRECT 2>/dev/null || true
  exec bash "$0" "$@"
fi

set +o posix 2>/dev/null || true

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
MISSION_FILE="${1:-$ROOT_DIR/nightly-mission.json}"
LOG_BASE_DIR="${LOG_BASE_DIR:-$ROOT_DIR/logs}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/state}"

MODEL="${MODEL:-openai/gpt-5.3-codex}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-15}"

mkdir -p "$LOG_BASE_DIR" "$STATE_DIR"

QUEUE_FILE="$STATE_DIR/topic-queue.txt"
SIGNATURE_FILE="$STATE_DIR/topic-signatures.sha256"
DONE_FILE="$STATE_DIR/topic-done.jsonl"
SKIP_FILE="$STATE_DIR/topic-skip.jsonl"

touch "$QUEUE_FILE" "$SIGNATURE_FILE" "$DONE_FILE" "$SKIP_FILE"

LOCK_FILE="$LOG_BASE_DIR/nightly.lock"
LOCK_DIR="$LOG_BASE_DIR/nightly.lock.d"

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "[ERROR] another nightly run is already active: $LOCK_FILE"
    exit 1
  fi
else
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[ERROR] another nightly run is already active: $LOCK_DIR"
    exit 1
  fi
  trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM
fi

if [[ ! -f "$MISSION_FILE" ]]; then
  echo "[ERROR] mission file not found: $MISSION_FILE"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 is required"
  exit 1
fi

json_get() {
  local code="$1"
  python3 - "$MISSION_FILE" "$code" <<'PY'
import json
import sys

path = sys.argv[1]
code = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

namespace = {"data": data}
result = eval(code, {}, namespace)
if result is None:
    print("")
elif isinstance(result, (dict, list)):
    print(json.dumps(result, ensure_ascii=False))
else:
    print(result)
PY
}

GOAL="$(json_get 'data.get("goal", "").strip()')"
if [[ -z "$GOAL" ]]; then
  echo "[ERROR] mission.goal is required"
  exit 1
fi

FORBIDDEN_JSON="$(json_get 'data.get("constraints", {}).get("forbidden_keywords", [])')"
REQUIRED_JSON="$(json_get 'data.get("constraints", {}).get("required_keywords", [])')"

BATCH_SIZE="$(json_get 'data.get("generation", {}).get("batch_size", 5)')"
LOW_WATERMARK="$(json_get 'data.get("generation", {}).get("low_watermark", 2)')"

MAX_ROUNDS="$(json_get 'data.get("stop", {}).get("max_rounds", 6)')"
MAX_TOPICS="$(json_get 'data.get("stop", {}).get("max_topics", 30)')"
MIN_NEW_TOPIC_RATIO="$(json_get 'data.get("stop", {}).get("min_new_topic_ratio", 0.2)')"

LOOKBACK="$(json_get 'data.get("idea", {}).get("lookback", 10)')"
STYLE="$(json_get 'data.get("idea", {}).get("style", "balanced")')"
MAX_IDEAS="$(json_get 'data.get("idea", {}).get("max_ideas", 3)')"
IDEA_MAX_RETRIES="$(json_get 'data.get("idea", {}).get("max_retries", 5)')"
IDEA_RETRY_DELAY="$(json_get 'data.get("idea", {}).get("retry_delay_seconds", 5)')"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$LOG_BASE_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

echo "[INFO] nightly run started: $RUN_ID"
echo "[INFO] mission file: $MISSION_FILE"
echo "[INFO] logs: $RUN_DIR"
echo "[INFO] state: $STATE_DIR"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

slugify() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "$s" | tr ' ' '-' | tr -cd 'a-z0-9-_')"
  if [[ -z "$s" ]]; then
    s="topic"
  fi
  printf '%s' "$s"
}

normalize_topic() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "$s" | tr -s '[:space:]' ' ')"
  s="$(trim "$s")"
  printf '%s' "$s"
}

topic_signature() {
  local normalized="$1"
  printf '%s' "$normalized" | shasum -a 256 | awk '{print $1}'
}

queue_count() {
  wc -l < "$QUEUE_FILE" | tr -d '[:space:]'
}

enqueue_topic() {
  local topic="$1"
  local normalized
  local sig

  normalized="$(normalize_topic "$topic")"
  if [[ -z "$normalized" ]]; then
    return 1
  fi

  sig="$(topic_signature "$normalized")"
  if grep -qx "$sig" "$SIGNATURE_FILE"; then
    return 1
  fi

  printf '%s\n' "$topic" >> "$QUEUE_FILE"
  printf '%s\n' "$sig" >> "$SIGNATURE_FILE"
  return 0
}

pop_topic() {
  if ! IFS= read -r CURRENT_TOPIC < "$QUEUE_FILE"; then
    return 1
  fi

  awk 'NR > 1 {print}' "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
  mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
  return 0
}

generate_candidates() {
  local round="$1"
  python3 - "$GOAL" "$REQUIRED_JSON" "$FORBIDDEN_JSON" "$round" <<'PY'
import json
import sys

goal = sys.argv[1].strip()
required = json.loads(sys.argv[2])
forbidden = [x.lower() for x in json.loads(sys.argv[3])]
round_n = int(sys.argv[4])

axes = [
    "order flow imbalance signal design and execution rules",
    "bid-ask spread dynamics and liquidity taking timing",
    "limit order book imbalance and queue position edge",
    "opening/closing auction microstructure behavior",
    "funding window and liquidation cluster interactions",
    "cross-venue latency and liquidity fragmentation effects",
    "trade size slicing and market impact mitigation",
    "maker-taker fee regime effects on fill quality",
    "volatility regime split and microstructure edge durability",
    "slippage decomposition by spread, impact, and delay",
    "execution guardrails under thin-liquidity episodes",
    "failure modes during news shocks and rapid repricing",
]

templates = [
    "{goal} | focus: {axis}",
    "{goal} | practical test: {axis}",
    "{goal} | failure-case review: {axis}",
]

if round_n >= 2:
    templates.append("{goal} | stress condition: {axis}")
if round_n >= 3:
    templates.append("{goal} | market transferability check: {axis}")

candidates = []
for axis in axes:
    for t in templates:
        candidates.append(t.format(goal=goal, axis=axis))

for key in required:
    key = str(key).strip()
    if not key:
        continue
    candidates.append(f"{goal} | required keyword deep-dive: {key}")
    for axis in axes[:6]:
        candidates.append(f"{goal} | {key} + {axis}")

seen = set()
for c in candidates:
    normalized = " ".join(c.lower().split())
    if not normalized or normalized in seen:
        continue
    if any(word in normalized for word in forbidden):
        continue
    seen.add(normalized)
    print(c)
PY
}

write_skip() {
  local topic="$1"
  local reason="$2"
  python3 - "$SKIP_FILE" "$topic" "$reason" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, topic, reason = sys.argv[1], sys.argv[2], sys.argv[3]
record = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "topic": topic,
    "reason": reason,
}
with open(path, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")
PY
}

write_done() {
  local topic="$1"
  local status="$2"
  local failed_stage="$3"
  python3 - "$DONE_FILE" "$topic" "$status" "$failed_stage" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, topic, status, failed_stage = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
record = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "topic": topic,
    "status": status,
    "failed_stage": failed_stage if failed_stage else None,
}
with open(path, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")
PY
}

LAST_GEN_TOTAL=0
LAST_GEN_NEW=0

replenish_queue() {
  local round="$1"
  local total=0
  local added=0
  local candidate=""

  while IFS= read -r candidate || [[ -n "$candidate" ]]; do
    candidate="$(trim "$candidate")"
    [[ -z "$candidate" ]] && continue
    total=$((total + 1))
    if enqueue_topic "$candidate"; then
      added=$((added + 1))
    else
      write_skip "$candidate" "duplicate"
    fi
    if [[ $added -ge $BATCH_SIZE ]]; then
      break
    fi
  done < <(generate_candidates "$round")

  LAST_GEN_TOTAL="$total"
  LAST_GEN_NEW="$added"
  echo "[INFO] replenish round=$round generated=$total added=$added queue=$(queue_count)"
}

run_step() {
  local step_name="$1"
  local log_file="$2"
  local session_id="${3:-}"
  shift 2

  if [[ -n "$session_id" && "$session_id" != --* ]]; then
    shift 1
  else
    session_id=""
  fi

  echo "[INFO] step=$step_name"
  if [[ -n "$session_id" ]]; then
    if (cd "$PROJECT_DIR" && opencode run --session "$session_id" "$@" --model "$MODEL") >"$log_file" 2>&1; then
      echo "[INFO] step=$step_name done"
      return 0
    fi
  elif (cd "$PROJECT_DIR" && opencode run "$@" --model "$MODEL") >"$log_file" 2>&1; then
    echo "[INFO] step=$step_name done"
    return 0
  fi

  echo "[WARN] step=$step_name failed (see $log_file)"
  return 1
}

run_ask_step() {
  local log_file="$1"
  shift 1

  local session_id=""

  echo "[INFO] step=ask"
  if ! (cd "$PROJECT_DIR" && opencode run "$@" --model "$MODEL" --format json) >"$log_file" 2>&1; then
    echo "[WARN] step=ask failed (see $log_file)"
    return 1
  fi

  session_id="$(python3 - "$log_file" <<'PY'
import json
import sys

path = sys.argv[1]
session_id = ""

with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        val = obj.get("sessionID")
        if isinstance(val, str) and val.startswith("ses_"):
            session_id = val
            break

print(session_id)
PY
)"

  if [[ -z "$session_id" ]]; then
    echo "[WARN] step=ask failed (session id missing in $log_file)"
    return 1
  fi

  echo "[INFO] step=ask done session=$session_id"
  ASK_SESSION_ID="$session_id"
  return 0
}

verify_idea_output() {
  local log_file="$1"
  local verify_msg=""

  verify_msg="$(python3 - "$PROJECT_DIR" "$ROOT_DIR" "$log_file" <<'PY'
import os
import re
import sys

project_dir = sys.argv[1]
root_dir = sys.argv[2]
log_path = sys.argv[3]

def fail(msg: str):
    print(msg)
    sys.exit(1)

bases = []
for base in (root_dir, project_dir):
    base = os.path.abspath(base)
    if base not in bases:
        bases.append(base)

try:
    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()
except OSError as e:
    fail(f"log read error: {e}")

if "[IDEAS]" not in text:
    fail("[IDEAS] section missing in log")

path_candidates = set(re.findall(r"data/ideas/[^\s'\")]+(?:idea\.md|meta\.json|ideas-\d{4}-\d{2}\.jsonl)", text))
if path_candidates:
    concrete_paths = {
        p for p in path_candidates
        if "*" not in p and "{" not in p and "}" not in p
    }
    for rel in concrete_paths:
        if any(os.path.exists(os.path.join(base, rel)) for base in bases):
            print(f"ok: artifact path found ({rel})")
            sys.exit(0)

if "data/ideas/" in text:
    for base in bases:
        ideas_root = os.path.join(base, "data", "ideas")
        if os.path.isdir(ideas_root):
            print(f"ok: ideas root found ({ideas_root})")
            sys.exit(0)

for base in bases:
    ideas_root = os.path.join(base, "data", "ideas")
    if not os.path.isdir(ideas_root):
        continue

    idea_dirs = [
        d for d in os.listdir(ideas_root)
        if d.startswith("idea-") and os.path.isdir(os.path.join(ideas_root, d))
    ]
    for d in idea_dirs:
        idea_dir = os.path.join(ideas_root, d)
        if os.path.exists(os.path.join(idea_dir, "idea.md")) or os.path.exists(os.path.join(idea_dir, "meta.json")):
            print(f"ok: idea artifact found ({idea_dir})")
            sys.exit(0)

    index_dir = os.path.join(ideas_root, "index")
    if os.path.isdir(index_dir):
        for name in os.listdir(index_dir):
            if re.match(r"ideas-\d{4}-\d{2}\.jsonl$", name):
                print(f"ok: idea index shard found ({name})")
                sys.exit(0)

fail("no persisted idea artifacts found under data/ideas")
PY
  )"
  local verify_status=$?
  VERIFY_IDEA_REASON="$(trim "$verify_msg")"
  return "$verify_status"
}

run_idea_with_retry() {
  local topic="$1"
  local topic_dir="$2"
  local session_id="$3"

  local attempt=1
  local log_file=""

  while [[ $attempt -le $IDEA_MAX_RETRIES ]]; do
    log_file="$topic_dir/idea-attempt-$attempt.log"

    if run_step \
      "idea(attempt=$attempt/$IDEA_MAX_RETRIES)" \
      "$log_file" \
      "$session_id" \
      --command idea \
      "topic=$topic" \
      "lookback=$LOOKBACK" \
      "style=$STYLE" \
      "max_ideas=$MAX_IDEAS"; then

      if verify_idea_output "$log_file"; then
        cp "$log_file" "$topic_dir/idea.log"
        echo "[INFO] step=idea saved attempt=$attempt"
        return 0
      fi
      if [[ -n "${VERIFY_IDEA_REASON:-}" ]]; then
        echo "[WARN] step=idea output verification failed attempt=$attempt reason=$VERIFY_IDEA_REASON (see $log_file)"
      else
        echo "[WARN] step=idea output verification failed attempt=$attempt (see $log_file)"
      fi
    fi

    attempt=$((attempt + 1))
    if [[ $attempt -le $IDEA_MAX_RETRIES ]]; then
      sleep "$IDEA_RETRY_DELAY"
    fi
  done

  echo "[ERROR] step=idea failed after retries=$IDEA_MAX_RETRIES"
  return 1
}

processed=0
round=0

if [[ $(queue_count) -eq 0 ]]; then
  round=$((round + 1))
  replenish_queue "$round"
fi

while true; do
  if [[ $processed -ge $MAX_TOPICS ]]; then
    echo "[INFO] stop: reached max_topics=$MAX_TOPICS"
    break
  fi

  if [[ $(queue_count) -lt $LOW_WATERMARK && $round -lt $MAX_ROUNDS ]]; then
    round=$((round + 1))
    replenish_queue "$round"

    if ! python3 - "$LAST_GEN_NEW" "$LAST_GEN_TOTAL" "$MIN_NEW_TOPIC_RATIO" <<'PY'
import sys
new = int(sys.argv[1])
total = int(sys.argv[2])
threshold = float(sys.argv[3])
ratio = (new / total) if total > 0 else 0.0
sys.exit(0 if ratio >= threshold else 1)
PY
    then
      echo "[INFO] stop: new topic ratio below threshold ($MIN_NEW_TOPIC_RATIO)"
      break
    fi
  fi

  if ! pop_topic; then
    if [[ $round -ge $MAX_ROUNDS ]]; then
      echo "[INFO] stop: queue empty and max rounds reached"
      break
    fi
    round=$((round + 1))
    replenish_queue "$round"
    if ! pop_topic; then
      echo "[INFO] stop: queue empty after replenish"
      break
    fi
  fi

  topic="$CURRENT_TOPIC"
  processed=$((processed + 1))

  slug="$(slugify "$topic")"
  topic_dir="$RUN_DIR/$(printf '%02d' "$processed")-$slug"
  mkdir -p "$topic_dir"

  ask_input="$topic"
  echo "[INFO] topic[$processed]=$topic"

  ASK_SESSION_ID=""
  if ! run_ask_step "$topic_dir/ask.log" --command ask "$ask_input"; then
    write_done "$topic" "failed" "ask"
    continue
  fi

  if ! run_step "research" "$topic_dir/research.log" "$ASK_SESSION_ID" --command research; then
    write_done "$topic" "failed" "research"
    continue
  fi

  if ! run_idea_with_retry "$topic" "$topic_dir" "$ASK_SESSION_ID"; then
    write_done "$topic" "failed" "idea_output"
    echo "[ERROR] stop: idea output is not persisted, aborting nightly run"
    break
  fi

  write_done "$topic" "success" ""
  sleep "$SLEEP_BETWEEN"
done

echo "[INFO] nightly run finished: $RUN_ID"
