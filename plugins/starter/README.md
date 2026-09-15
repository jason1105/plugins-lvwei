# starter

A minimal scaffold plugin demonstrating the four core Claude Code plugin
component types. Copy any of these as a starting point for real components.

| Component | File | Invocation |
|---|---|---|
| Command | `commands/hello.md` | `/starter:hello` |
| Skill | `skills/greeter/SKILL.md` | auto-triggered by description, or `/starter:greeter` |
| Agent | `agents/example-reviewer.md` | via the `Agent` tool, name `example-reviewer` |
| Hook | `hooks/hooks.json` + `scripts/notify.sh` | fires automatically on `PostToolUse` for `Write`/`Edit` |

## Layout

```
starter/
├── .claude-plugin/plugin.json   # manifest (name, version, metadata)
├── commands/hello.md
├── skills/greeter/SKILL.md
├── agents/example-reviewer.md
├── hooks/hooks.json
├── scripts/notify.sh             # referenced by hooks.json via ${CLAUDE_PLUGIN_ROOT}
└── README.md
```

## Developing locally

```bash
# Load this plugin without installing it
claude --plugin-dir ./plugins/starter

# Validate the manifest and structure
claude plugin validate ./plugins/starter --strict
```
