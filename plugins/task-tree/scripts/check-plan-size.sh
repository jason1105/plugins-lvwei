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
# mirroring the documented PreToolUse block-with-reason pattern. Confirmed
# via `claude --plugin-dir plugins/task-tree` end-to-end testing: a real
# Write to a 00-实施计划.md triggered this hook, and the Claude session
# literally quoted the stderr reminder text back — PostToolUse's exit-2 +
# stderr does reach the model, not only the human operator.

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

case "$(basename -- "$file_path")" in
  00-实施计划.md) ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

node_count=$(python3 - "$file_path" 2>/dev/null <<'PYEOF'
import re, sys
try:
    text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
except Exception:
    print(0)
    sys.exit(0)

# Prefer the mermaid block inside the "状态跟踪图" section (SKILL.md's
# mandated location for the real, current diagram); fall back to the LAST
# mermaid block in the file otherwise — a doc that quotes an earlier example
# from SKILL.md/reference.md before its own diagram is more plausible than
# the reverse, so "last" is a safer default than "first".
section = re.search(r'^#{1,6}\s*状态跟踪图\s*$(.*?)(?=^#{1,6}\s|\Z)', text, re.M | re.S)
search_scope = section.group(1) if section else text
blocks = re.findall(r'```mermaid\n(.*?)```', search_scope, re.S)
if not blocks and section:
    # Heading found but no mermaid inside it yet — don't silently fall
    # through to some unrelated block elsewhere in the file.
    blocks = []
elif not blocks:
    blocks = re.findall(r'```mermaid\n(.*?)```', text, re.S)

if blocks:
    body = blocks[-1]

    # Node declarations. Not anchored to line-start: a single line can
    # define multiple nodes, e.g. N1[N1] --> N2[N2]. Anchoring to ^ would
    # miss every node after the first on such lines (bug caught by testing
    # against a real Write output). Only "[...]" rectangle nodes count as
    # real work items — "{...}" diamond/decision ("闸") nodes are excluded
    # per SKILL.md ("判定节点/闸不计入这个计数,它们是瞬时判断不是工作项").
    all_ids = set(re.findall(r'\b([A-Za-z_]\w*)\s*\[', body))

    # subgraph <id> ... end: <id> is the CURRENT node (this diagram's own
    # subject), not one of its children — exclude it. Track each
    # subgraph's body so ids declared inside it (real children, connected
    # by containment) take priority over the dashed-line heuristic below,
    # even if a child also happens to appear on some unrelated dashed line.
    subgraph_ids = set()
    inside_ids = set()
    depth = 0
    body_lines = []
    for line in body.splitlines():
        opened = re.match(r'\s*subgraph\s+([A-Za-z_]\w*)', line)
        if opened:
            if depth == 0:
                subgraph_ids.add(opened.group(1))
                body_lines = []
            depth += 1
            continue
        if re.match(r'\s*end\s*$', line):
            if depth > 0:
                depth -= 1
                if depth == 0:
                    inside_ids |= set(re.findall(r'\b([A-Za-z_]\w*)\s*\[', '\n'.join(body_lines)))
            continue
        if depth > 0:
            body_lines.append(line)

    if inside_ids:
        children = inside_ids
    else:
        # No subgraph: fall back to "declared, not dashed-only". Dashed
        # edges (mermaid "-.text.->" / "-.->" / "-.-") mark cross-cutting
        # "acts-on" relationships to OTHER tasks (SKILL.md "横切任务"),
        # not children of the current node.
        dashed_ids = set()
        for line in body.splitlines():
            if '-.' in line:
                dashed_ids.update(re.findall(r'\b([A-Za-z_]\w*)\b', line))
        dashed_ids &= all_ids
        children = all_ids - subgraph_ids - dashed_ids

    print(len(children))
else:
    print(len(re.findall(r'^#{2,3}\s+\S', text, re.M)))
PYEOF
)

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
