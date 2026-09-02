# dotclaude

[![Validate marketplace](https://github.com/kurrik/dotclaude/actions/workflows/validate.yml/badge.svg)](https://github.com/kurrik/dotclaude/actions/workflows/validate.yml)

A personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins) — a single Git repo holding skills shared across Claude Code, [OpenAI Codex](https://developers.openai.com/codex/plugins), and Grok Build. See [Using with Codex](#using-with-codex) and [Using with Grok](#using-with-grok).

## Quick start

**Claude Code** — add the marketplace, then install a plugin:

```
/plugin marketplace add kurrik/dotclaude
/plugin install ark@dotclaude
```

Or share it across **all** your instances declaratively (recommended) — see [Share across every instance](#share-across-every-instance) below.

**Codex CLI** — same two steps, from a shell:

```
codex plugin marketplace add kurrik/dotclaude
codex plugin add ark@dotclaude
```

**Grok Build** — add the same marketplace and install the plugin:

```
grok plugin marketplace add kurrik/dotclaude
grok plugin install ark --trust
```

## What's in here

| Plugin | Provides | Invoke as |
| --- | --- | --- |
| **`ark`** | Git & GitHub workflow skills | Claude Code and Grok: `/ark:pr`, `/ark:review`, `/ark:reset-worktree`, `/ark:polish`, `/ark:improve-polish` · Codex: the same names via `$` mention (e.g. `$ark:pr`) or `/skills` |

- **`/ark:polish`** — frontload the PR review cycle before pushing: run up to three reviewers in parallel subagents (the current host's native reviewer, a preferred cross-agent CLI review if installed, and a check against a layered review-principles corpus), read the branch as a whole and choose structural fixes over behavior patches, triage and fix findings without expanding scope, commit each round with the audit trail in the message, and stop after at most two rounds — a full review round, then a cheaper verification round without the cross-agent leg. `/ark:polish --quick` runs a single round with only the native and corpus reviewers, no cross-agent CLI, for a cheap first look. Claude Code pairs its native review with [Codex CLI](https://github.com/openai/codex); Codex pairs its native review with Claude CLI; Grok pairs its native review with Codex CLI, falling back to Claude CLI only when Codex is unavailable or fails before reviewing. This avoids redundant nested same-agent sessions. **Opt-in:** it runs only when you invoke it, or when `/ark:pr` sizes a large or sensitive unreviewed diff (or `/ark:review` finds its fixes reshaped the PR), offers a single pass, and you accept — never on every PR. The corpus has three layers: general principles bundled with the skill ([`plugins/ark/skills/polish/principles/`](plugins/ark/skills/polish/principles/)), machine-specific rules in `~/.claude/review-principles/`, and repo-specific rules in the repo's `.claude/review-principles/` — same-named files are the same principle, with the more specific layer winning on conflict.
- **`/ark:improve-polish`** — upstream review-cycle lessons from the current session back into the bundled corpus: diagnose this session's polish rounds, PR review feedback, and human corrections for generalizable lessons (errors and feedback to anticipate, better fix patterns), draft principle updates with real positive and negative examples, and — after you approve the draft — open a PR against this repo entirely through `gh api`, so it works from any machine that installed the marketplace with no local checkout of `kurrik/dotclaude`.
- **`/ark:pr`** — stage, commit, push the current branch, and open a GitHub PR with an auto-generated description that follows the repo's PR template. Sizes the unreviewed diff first and, when it is large or touches a sensitive area (auth, secrets, migrations, infra, concurrency), asks once whether to run `/ark:polish` (full or `--quick`) before pushing; small diffs push straight away. Pushes only through [`push-branch.sh`](plugins/ark/scripts/push-branch.sh), which scans every commit it would publish (paths, added lines, commit messages) and refuses on a hit.
- **`/ark:review`** — fetch PR review comments, address them, push fixes, and reply to each thread through a single pending review. Reviews its own fixes holistically before pushing; offers `/ark:polish` only when the fixes reshaped the PR.
- **`/ark:reset-worktree`** — reset the current git worktree's branch back to the base branch, or the primary clone back to a clean `main` checkout. Asks before discarding uncommitted work.

> **Requirements:** `/ark:pr` and `/ark:review` use the [GitHub CLI (`gh`)](https://cli.github.com) signed in to your account. No `gh` extensions needed — `/ark:review` talks to GitHub's GraphQL API directly via `gh api`. `/ark:reset-worktree` needs only `git`. `/ark:polish` needs only `git` for its always-on native and principles legs; its optional cross-agent leg uses `codex` from Claude Code, `claude` from Codex, and prefers `codex` with a `claude` fallback from Grok. General principles ship with the skill, augmented by `~/.claude/review-principles/` and the repo's `.claude/review-principles/` when those exist. `/ark:improve-polish` needs `gh` signed in to an account that can push to (or fork) `kurrik/dotclaude`.

### `/ark:reset-worktree`

For a throwaway-worktree workflow: each worktree directory owns the branch `worktree/<directory-name>`, and resetting means "throw away everything and start again from `main`".

```
~/workspace/a17k        # primary clone, sits on main
~/workspace/a17k-01     # worktree on branch worktree/a17k-01
~/workspace/a17k-02     # worktree on branch worktree/a17k-02
```

Run from `~/workspace/a17k-01`, it fetches `main` from `origin`, checks out `worktree/a17k-01` (creating it if needed), hard-resets it to `main`, and unsets its upstream so a later bare `git push` can't update a remote copy.

Run from the primary clone, there is no scratch branch to throw away, so the equivalent end state is `main` itself: it fetches `main`, checks it out, and hard-resets it to the fetched tip. The upstream is kept (`main` is supposed to track `origin/main`), `--prefix` is ignored, and the branch you were on is left in place — you're just no longer on it.

The logic lives in [`plugins/ark/skills/reset-worktree/scripts/reset-worktree.sh`](plugins/ark/skills/reset-worktree/scripts/reset-worktree.sh) and is runnable on its own:

```
bash reset-worktree.sh [--force] [--base <branch>] [--prefix <ns>] [--dry-run]
```

The skill wrapper exists so the script is distributed with the plugin and so the agent can handle the one case the script won't decide alone: it exits `3` on a dirty worktree, and the skill then asks you before re-running with `--force`.

- `--base` sets the base branch (default `main`).
- `--prefix` changes the namespace (default `worktree`); `--prefix ''` gives a bare `a17k-01`. A prefix **cannot** be an existing branch name — git stores refs as filesystem paths, so with a `main` branch present the ref `main/a17k-01` is impossible (`cannot lock ref 'refs/heads/main/a17k-01': 'refs/heads/main' exists`). That's why the namespace is `worktree/` rather than `main/`; the script rejects a colliding prefix up front.
- If `main` is already checked out — in another worktree, or in the primary clone you're running from — `git fetch origin main:main` can't fast-forward it; the script falls back to fetching and resetting to `origin/main`.
- `reset --hard` leaves untracked files alone. The script lists any that survive rather than deleting them.

[`reset-worktree.test.sh`](plugins/ark/skills/reset-worktree/scripts/reset-worktree.test.sh) covers these paths against a throwaway repo and runs in CI.

## How naming / prefixes work

This trips people up, so to be explicit:

- The **marketplace name** (`dotclaude`) only appears when configuring or installing — `/plugin install <plugin>@dotclaude` (Claude Code), `codex plugin add <plugin>@dotclaude` (Codex), or `grok plugin marketplace add ...` followed by `grok plugin install <plugin>` (Grok) — and as the key in settings. It does **not** prefix anything.
- The **plugin name** is the prefix. A skill `foo` in the `ark` plugin is `ark:foo` in all three tools — `/ark:foo` in Claude Code and Grok, `$ark:foo` as a Codex mention.

So when you add a skill, the directory name determines the suffix and the plugin name determines the prefix:

```
plugins/ark/skills/pr/SKILL.md      ->  ark:pr
plugins/ark/skills/triage/SKILL.md  ->  ark:triage
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
│       ├── scripts/             # Mechanics shared by pr / review / polish, each with a test run in CI
│       │   ├── resolve-base.sh      # fetch + print origin/<default branch>
│       │   ├── polish-state.sh      # has this tip been polished, and what did polish say?
│       │   ├── polish-record.sh     # write a polish run's verdict as commit trailers
│       │   ├── scan-secrets.sh      # every commit's paths, added lines, and message
│       │   ├── push-branch.sh       # scan, then push — the only way a skill pushes
│       │   ├── polish-state.test.sh
│       │   └── scan-secrets.test.sh
│       └── skills/              # Skills (one directory per skill)
│           ├── improve-polish/
│           │   └── SKILL.md     # Upstreams session review lessons into polish's corpus
│           ├── polish/
│           │   ├── SKILL.md
│           │   └── principles/  # Bundled general layer of the review-principles corpus
│           ├── pr/
│           │   └── SKILL.md
│           ├── reset-worktree/
│           │   ├── SKILL.md
│           │   └── scripts/     # Helper scripts, referenced relative to the skill dir
│           │       ├── reset-worktree.sh
│           │       └── reset-worktree.test.sh
│           └── review/
│               └── SKILL.md
├── README.md
└── LICENSE
```

Component directories (`skills/`, `commands/`, `agents/`, `hooks/`, `.mcp.json`) live at the **plugin root** — only `plugin.json` goes inside `.claude-plugin/`.

The `ark` skills follow one rule: **skills state policy, scripts do mechanics.** Anything three skills would otherwise each restate — how the base is resolved, whether a tip has been polished, what a push checks — is a script in `plugins/ark/scripts/` with a test, and the SKILL.md files call it. That is what keeps `ark:pr`, `ark:review`, and `ark:polish` from drifting apart.

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

## Using with Codex

The [Codex CLI](https://developers.openai.com/codex/cli/features) reads this repo directly as a plugin marketplace — it accepts the `.claude-plugin/marketplace.json` catalog and the `.claude-plugin/plugin.json` manifest as legacy-compatible locations, and discovers the same `skills/` directories. No Codex-specific files are needed.

```
codex plugin marketplace add kurrik/dotclaude
codex plugin add ark@dotclaude
```

Then start a **new** Codex session (plugins load at session start). The skills surface under the same names as in Claude Code — `ark:pr`, `ark:review`, `ark:reset-worktree`, `ark:polish`, `ark:improve-polish` — invoked by typing `$` to mention one, via `/skills`, or implicitly by description.

To pick up a new version later:

```
codex plugin marketplace upgrade dotclaude
codex plugin add ark@dotclaude
```

## Using with Grok

Grok accepts this repo's `.claude-plugin/marketplace.json` and plugin manifest as compatibility locations and discovers the same `skills/` directories. No Grok-specific copy of the plugin is needed.

```
grok plugin marketplace add kurrik/dotclaude
grok plugin install ark --trust
```

The skills surface under their plugin-qualified slash names, including `/ark:polish`. To pick up a new version later:

```
grok plugin marketplace update dotclaude
grok plugin update ark
```

Cross-agent caveats:

- `ark:polish` uses the active host's native subagents and never shells out to that same host: Claude Code runs native Claude + `codex review`; Codex runs native Codex + `claude -p`; Grok runs native Grok + `codex review`, using `claude -p` only when Codex is unavailable or fails before reviewing. If no selected external CLI is installed, polish proceeds with its native and principles legs and reports the skip.
- Claude frontmatter such as `allowed-tools` and `argument-hint` is ignored by Codex but supported by Grok. Codex invocations still work; they simply lack the pre-approved tool list and argument autocomplete.

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
2. Add skills under `plugins/<name>/skills/<skill>/SKILL.md`.
3. Register it in `.claude-plugin/marketplace.json` by appending to the `plugins` array:
   ```json
   { "name": "<name>", "description": "…", "source": "./plugins/<name>" }
   ```
4. Validate, commit, push:
   ```
   claude plugin validate .
   ```
5. On each instance, `/plugin marketplace update dotclaude` (or restart) picks up the change.

> CI ([`.github/workflows/validate.yml`](.github/workflows/validate.yml)) re-runs `claude plugin validate` on the marketplace and every plugin for each push and PR, so a broken manifest can't land on `main`. It also runs every `plugins/*/scripts/*.test.sh` and `plugins/*/skills/*/scripts/*.test.sh`, so name a script's test suite that way and CI picks it up.

### Why everything is a skill (not a slash command)

Everything in this repo ships as a `skills/<name>/SKILL.md` directory because Claude Code, Codex, and Grok all discover skills natively. In Claude Code and Grok a skill is user-invocable as `/<plugin>:<name>` (with `argument-hint`, `allowed-tools`, and `disable-model-invocation` frontmatter all supported) *and* model-invocable from its `description` — so a skill loses nothing compared to a `commands/*.md` slash command.

Claude-only `commands/*.md` files, by contrast, only reach Codex through its automatic command→skill migration, which is unreliable: it silently skips any command file over ~4 KB or containing `$ARGUMENTS`, and the migrated names come out as `<plugin>:source-command-<name>`.

To keep a skill portable across all three tools:

- Reference bundled files relative to the skill directory ("`scripts/foo.sh` inside this skill's directory") — `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` only expand in Claude Code.
- Don't rely on `$ARGUMENTS` substitution (Claude-only); phrase argument handling in prose. Claude Code appends unmatched arguments as `ARGUMENTS: <value>`, Codex arguments follow the `$` mention, and Grok arguments follow the slash command.
- Claude frontmatter (`allowed-tools`, `argument-hint`, `disable-model-invocation`) is supported by Grok and ignored by Codex, so it's safe to keep.

## Versioning

Each plugin's `plugin.json` carries an explicit `version`. Bump it when you change a plugin so instances see an update is available. (Omit `version` entirely and Claude Code falls back to the git commit SHA — every commit becomes a new version.)
