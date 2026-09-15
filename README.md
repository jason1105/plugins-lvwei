# plugins-lvwei

A personal [Claude Code](https://code.claude.com) plugin marketplace.

## Install this marketplace

```bash
/plugin marketplace add jason1105/plugins-lvwei
```

Then install any plugin listed below:

```bash
/plugin install starter@plugins-lvwei
```

## Plugins

| Plugin | Description |
|---|---|
| [`starter`](./plugins/starter) | Minimal scaffold demonstrating a command, a skill, an agent, and a hook. |

## Repository layout

```
.
├── .claude-plugin/marketplace.json   # marketplace manifest
├── plugins/
│   └── starter/                      # one directory per plugin
└── README.md
```

## Developing a plugin locally

```bash
# Load a plugin directly from disk, no install needed
claude --plugin-dir ./plugins/<plugin-name>

# Validate a plugin's manifest and structure before publishing
claude plugin validate ./plugins/<plugin-name> --strict
```

## Contributing

Changes land via pull request against `main` — see individual plugin
READMEs for details on each plugin's components.
