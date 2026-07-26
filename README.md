# dotclaude

[![Validate marketplace](https://github.com/kurrik/dotclaude/actions/workflows/validate.yml/badge.svg)](https://github.com/kurrik/dotclaude/actions/workflows/validate.yml)

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
| **`ark`** | Git & GitHub workflow commands | `/ark:pr`, `/ark:review`, `/ark:reset-worktree` |

- **`/ark:pr`** — stage, commit, push the current branch, and open a GitHub PR with an auto-generated description that follows the repo's PR template.
- **`/ark:review`** — fetch PR review comments, address them, push fixes, and reply to each thread through a single pending review.
- **`/ark:reset-worktree`** — reset the current git worktree's branch back to the base branch, or the primary clone back to a clean `main` checkout. Asks before discarding uncommitted work.

> **Requirements:** `/ark:pr` and `/ark:review` use the [GitHub CLI (`gh`)](https://cli.github.com) signed in to your account. No `gh` extensions needed — `/ark:review` talks to GitHub's GraphQL API directly via `gh api`. `/ark:reset-worktree` needs only `git`.

### `/ark:reset-worktree`

For a throwaway-worktree workflow: each worktree directory owns the branch `worktree/<directory-name>`, and resetting means "throw away everything and start again from `main`".

```
~/workspace/a17k        # primary clone, sits on main
~/workspace/a17k-01     # worktree on branch worktree/a17k-01
~/workspace/a17k-02     # worktree on branch worktree/a17k-02
```

Run from `~/workspace/a17k-01`, it fetches `main` from `origin`, checks out `worktree/a17k-01` (creating it if needed), hard-resets it to `main`, and unsets its upstream so a later bare `git push` can't update a remote copy.

Run from the primary clone, there is no scratch branch to throw away, so the equivalent end state is `main` itself: it fetches `main`, checks it out, and hard-resets it to the fetched tip. The upstream is kept (`main` is supposed to track `origin/main`), `--prefix` is ignored, and the branch you were on is left in place — you're just no longer on it.

The logic lives in [`plugins/ark/scripts/reset-worktree.sh`](plugins/ark/scripts/reset-worktree.sh) and is runnable on its own:

```
bash reset-worktree.sh [--force] [--base <branch>] [--prefix <ns>] [--dry-run]
```

The command wrapper exists so the script is distributed with the plugin and so Claude can handle the one case the script won't decide alone: it exits `3` on a dirty worktree, and the command then asks you before re-running with `--force`.

- `--base` sets the base branch (default `main`).
- `--prefix` changes the namespace (default `worktree`); `--prefix ''` gives a bare `a17k-01`. A prefix **cannot** be an existing branch name — git stores refs as filesystem paths, so with a `main` branch present the ref `main/a17k-01` is impossible (`cannot lock ref 'refs/heads/main/a17k-01': 'refs/heads/main' exists`). That's why the namespace is `worktree/` rather than `main/`; the script rejects a colliding prefix up front.
- If `main` is already checked out — in another worktree, or in the primary clone you're running from — `git fetch origin main:main` can't fast-forward it; the script falls back to fetching and resetting to `origin/main`.
- `reset --hard` leaves untracked files alone. The script lists any that survive rather than deleting them.

[`reset-worktree.test.sh`](plugins/ark/scripts/reset-worktree.test.sh) covers these paths against a throwaway repo and runs in CI.

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
│       ├── commands/            # Slash commands  (flat .md files)
│       │   ├── pr.md
│       │   ├── reset-worktree.md
│       │   └── review.md
│       └── scripts/             # Helper scripts, reached via ${CLAUDE_PLUGIN_ROOT}
│           ├── reset-worktree.sh
│           └── reset-worktree.test.sh
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

## Using `ark` in a cloud environment

Claude's cloud environments — [Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web) and scheduled [Routines](https://code.claude.com/docs/en/routines) — preinstall `git` but **not** the `gh` CLI, and `gh`'s API calls need an explicit token. To use the `ark` commands there:

1. In the environment's **Setup script**, install `gh` (setup-script installs are snapshotted and reused across sessions, so this runs once — not every session):
   ```bash
   #!/bin/bash
   apt-get update && apt-get install -y gh
   ```
2. Add a least-privilege token as an **environment variable** so `gh api` is authenticated without `gh auth login`:
   ```
   GH_TOKEN=<your token>
   ```
3. No network change needed — `github.com` is in the default "Trusted" egress allowlist.

Because `/ark:review` uses `gh api` directly (no `gh` extensions), that's the whole list — there's nothing else to provision.

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

> CI ([`.github/workflows/validate.yml`](.github/workflows/validate.yml)) re-runs `claude plugin validate` on the marketplace and every plugin for each push and PR, so a broken manifest can't land on `main`. It also runs every `plugins/*/scripts/*.test.sh`, so name a script's test suite that way and CI picks it up.

### Adding a command vs. a skill

- **Slash command** — a flat `.md` file in `commands/`, invoked as `/<plugin>:<file>`. Model-invocable by default (Claude may trigger it from its `description`) as well as user-invocable; add `disable-model-invocation: true` to the frontmatter to make it manual-only.
- **Skill** — a `skills/<name>/SKILL.md` directory, for capabilities that may bundle scripts/references, auto-triggered by its `description`.

## Versioning

Each plugin's `plugin.json` carries an explicit `version`. Bump it when you change a plugin so instances see an update is available. (Omit `version` entirely and Claude Code falls back to the git commit SHA — every commit becomes a new version.)
