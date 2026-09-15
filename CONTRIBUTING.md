# Contributing to plugins-lvwei

This repo is a [Claude Code](https://code.claude.com) plugin **marketplace**:
the root `.claude-plugin/marketplace.json` lists one or more plugins, each
living in its own `plugins/<name>/` directory.

Plugin development has two loops. You'll spend almost all your time in the
**inner loop** — it's local, fast, and touches no git state at all. The
**outer loop** is how work leaves your machine and reaches other users.

## Repository layout

```
.
├── .claude-plugin/marketplace.json   # lists every plugin below
└── plugins/
    └── <name>/
        ├── .claude-plugin/plugin.json
        ├── commands/*.md
        ├── skills/<skill-name>/SKILL.md
        ├── agents/*.md
        ├── hooks/hooks.json
        └── scripts/*                 # referenced by hooks.json via ${CLAUDE_PLUGIN_ROOT}
```

One plugin = one directory under `plugins/` + one entry in
`.claude-plugin/marketplace.json`'s `plugins` array.

## Adding a new plugin

The easiest path is to copy `plugins/starter/` and rename things:

```bash
cp -r plugins/starter plugins/<your-plugin-name>
```

Then add an entry for it in `.claude-plugin/marketplace.json`.

> **Gotcha:** `claude plugin init <name>` does **not** scaffold into this
> repo — it always creates `~/.claude/skills/<name>/`, a personal,
> machine-local skill. It's the wrong tool for adding a plugin here; use the
> copy-and-rename approach above instead.

## Inner loop: develop and test locally

Load a plugin straight from disk — no install, no git involved:

```bash
claude --plugin-dir ./plugins/<name>
```

Inside that session, edit files and run `/reload-plugins` to pick up
changes without restarting.

Check what actually got registered, and at what token cost:

```bash
claude --plugin-dir ./plugins/<name> plugin details <name>
```

**Keep skill `description` fields short.** Every skill's description is
loaded into *every session's* context, whether or not the skill ever fires
— `plugin details` reports this as "always-on" cost. Write just enough for
the model to know when to trigger it; put the long version in the skill
body instead.

## Outer loop: validate, commit, publish

### Validate before you push

`claude plugin validate` only checks the path you give it — it does **not**
recurse into subdirectories on its own. Run it against each of these
separately:

```bash
# 1. The marketplace manifest itself, plus every plugin it lists
claude plugin validate . --strict

# 2. Each plugin's own manifest
claude plugin validate ./plugins/<name> --strict

# 3. Each component directory inside that plugin
claude plugin validate ./plugins/<name>/skills --strict
claude plugin validate ./plugins/<name>/agents --strict
claude plugin validate ./plugins/<name>/commands --strict
```

CI runs this same set of checks on every pull request (see
`.github/workflows/validate-plugins.yml`) — running it locally first saves
a round trip.

### Commit and open a PR

- `main` is protected by convention: **no direct commits or pushes**, only
  pull requests.
- Branch name: `feat/<name>-plugin` (or `fix/...`, `docs/...` as
  appropriate).
- Commit/PR titles follow [Conventional Commits](https://www.conventionalcommits.org/):
  `type(scope): description`, e.g. `feat(starter): add a new command`.

### Version bumps are not optional

**If you change a plugin's behavior, bump `version` in its `plugin.json`
(semver).** Per the official plugin docs, users only receive updates when
this field changes — ship a fix without bumping it, and everyone who
already installed the plugin silently keeps the old, broken version until
they happen to bump it themselves.

### After merge

Merging to `main` does not push changes to anyone who already added this
marketplace. They need to refresh it themselves:

```bash
/plugin marketplace update plugins-lvwei
```

## Optional: evaluating a plugin's actual effect

`claude plugin validate` only checks that a plugin's files are
well-formed — it says nothing about whether the plugin is actually useful.
For that, `claude plugin eval` runs scored test cases (from an `evals/`
directory under the plugin) against the plugin, and — by default — also
against a no-plugin baseline, reporting the score delta (this is an
**ablation**: remove the plugin, see how much the score drops). See
`claude plugin eval --help` for the case file format. Not yet set up for
any plugin in this repo; consider it for plugins where "does this actually
help" isn't obvious just from reading it.
