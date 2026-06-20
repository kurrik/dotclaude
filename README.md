# dotclaude

A personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins) — a single Git repo holding skills and slash commands, shared across every Claude Code instance I use.

## Quick start

Add the marketplace, then install a plugin:

```
/plugin marketplace add kurrik/dotclaude
/plugin install ark@dotclaude
```

Or share it across **all** your instances declaratively (recommended) — see [Share across every instance](#share-across-every-instance) below.

## What's in here

| Plugin | Provides | Invoke as |
| --- | --- | --- |
| **`ark`** | Git & GitHub PR workflow commands | `/ark:pr`, `/ark:review` |

- **`/ark:pr`** — stage, commit, push the current branch, and open a GitHub PR with an auto-generated description that follows the repo's PR template.
- **`/ark:review`** — fetch PR review comments, address them, push fixes, and reply to each thread through a single pending review.

> **Dependency:** `/ark:review` uses the [`gh-pr-review`](https://github.com/your/gh-pr-review) GitHub CLI extension. Install the `gh` CLI and that extension for it to work.

## How naming / prefixes work

This trips people up, so to be explicit:

- The **marketplace name** (`dotclaude`) only appears when installing — `/plugin install <plugin>@dotclaude` — and as the key in settings. It does **not** prefix anything.
- The **plugin name** is the prefix. The `ark` plugin's commands become `/ark:pr` and `/ark:review`; a skill `foo` in the `ark` plugin would be `ark:foo`.

So when you add a command, the path determines the suffix and the plugin name determines the prefix:

```
plugins/ark/commands/pr.md          ->  /ark:pr
plugins/ark/commands/deploy/web.md  ->  /ark:deploy:web
plugins/ark/skills/triage/SKILL.md  ->  ark:triage   (model-invocable skill)
```

## Repository layout

```
dotclaude/
├── .claude-plugin/
│   └── marketplace.json        # Catalog: lists every plugin + its source path
├── plugins/
│   └── ark/
│       ├── .claude-plugin/
│       │   └── plugin.json      # Plugin manifest (name, version, metadata)
│       └── commands/            # Slash commands  (flat .md files)
│           ├── pr.md
│           └── review.md
├── README.md
└── LICENSE
```

Component directories (`commands/`, `skills/`, `agents/`, `hooks/`, `.mcp.json`) live at the **plugin root** — only `plugin.json` goes inside `.claude-plugin/`.

## Share across every instance

To make a plugin load automatically on every machine without running `/plugin install` each time, add two keys to your **user** settings at `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "dotclaude": {
      "source": { "source": "github", "repo": "kurrik/dotclaude" }
    }
  },
  "enabledPlugins": {
    "ark@dotclaude": true
  }
}
```

- `extraKnownMarketplaces` registers the marketplace automatically.
- `enabledPlugins` enables specific plugins by default (`"<plugin>@<marketplace>": true`).

Replicate those two blocks in any machine's `~/.claude/settings.json` (or a project's `.claude/settings.json` to scope it to one repo) and the plugin is there on next launch.

## Adding a new plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with at least `{ "name": "<name>" }`.
2. Add commands under `plugins/<name>/commands/*.md` and/or skills under `plugins/<name>/skills/<skill>/SKILL.md`.
3. Register it in `.claude-plugin/marketplace.json` by appending to the `plugins` array:
   ```json
   { "name": "<name>", "description": "…", "source": "./plugins/<name>" }
   ```
4. Validate, commit, push:
   ```
   claude plugin validate .
   ```
5. On each instance, `/plugin marketplace update dotclaude` (or restart) picks up the change.

### Adding a command vs. a skill

- **Slash command** — a flat `.md` file in `commands/` with a `description:` frontmatter field. User-invoked via `/<plugin>:<file>`.
- **Skill** — a `skills/<name>/SKILL.md` directory, for model-invocable capabilities that may bundle scripts/references. Auto-triggered by its `description`.

## Versioning

Each plugin's `plugin.json` carries an explicit `version`. Bump it when you change a plugin so instances see an update is available. (Omit `version` entirely and Claude Code falls back to the git commit SHA — every commit becomes a new version.)
