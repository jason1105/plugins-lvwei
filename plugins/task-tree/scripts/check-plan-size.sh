#!/usr/bin/env bash
# task-tree plugin PostToolUse hook.
#
# Fires after every Write/Edit tool call. If the touched file is a
# 00-实施计划.md, count the nodes in its status-tracking diagram (falling
# back to counting step headers if there's no mermaid block yet) and, if it
# exceeds the task-tree skill's fan-out threshold, surface a reminder.
#
# Fails open: any unexpected condition (missing jq/python3, unparsable
# input, missing file) exits 0 silently rather than blocking the Write/Edit
# that already completed.
#
# NOTE ON THE EXIT-2 MECHANISM: this uses exit code 2 + a stderr message,
# mirroring the documented PreToolUse block-with-reason pattern. Whether
# PostToolUse's exit-2 actually surfaces the stderr text to Claude (as
# opposed to only being visible to the human operator) has NOT been
# independently confirmed as of writing this script — verify empirically
# with `claude --plugin-dir <path to plugins/task-tree>` before relying on
# it, and adjust the signaling mechanism if the message doesn't reach the
# model.

input="$(cat 2>/dev/null)"
[ -z "$input" ] && exit 0

file_path=""
if command -v jq >/dev/null 2>&1; then
  file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  file_path="$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")
' 2>/dev/null)"
fi

[ -z "$file_path" ] && exit 0

case "$file_path" in
  */00-实施计划.md) ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

node_count="$(python3 - "$file_path" 2>/dev/null <<'PYEOF'
import re, sys
try:
    text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
except Exception:
    print(0)
    sys.exit(0)
m = re.search(r'```mermaid\n(.*?)```', text, re.S)
if m:
    body = m.group(1)
    # Not anchored to line-start: a single line can define multiple nodes,
    # e.g. N1[N1] --> N2[N2]. Anchoring to ^ would miss every node after
    # the first on such lines (bug caught by testing against a real Write output).
    ids = set(re.findall(r'\b([A-Za-z_]\w*)\s*[\[\{]', body))
    print(len(ids))
else:
    print(len(re.findall(r'^#{2,3}\s+\S', text, re.M)))
PYEOF
)"

# Sanitize: keep only digits, default to 0 if empty/garbage.
node_count="$(printf '%s' "$node_count" | tr -cd '0-9')"
node_count="${node_count:-0}"

threshold=5

if [ "$node_count" -gt "$threshold" ] 2>/dev/null; then
  {
    echo "[task-tree] $file_path 的状态跟踪图/步骤数现在有 ${node_count} 个,超过递归阈值(${threshold})。"
    echo "请依据 task-tree skill 评估:这些节点里有没有该扇出成独立子任务的(纵向信号:跨会话/需要独立证据链),"
    echo "还是只是横向条目多、彼此独立轻量,该用表格折叠而不是拆文件夹。"
  } >&2
  exit 2
fi

exit 0
