# Bundled review principles

This is the **general layer** of the layered corpus the `ark:polish` corpus
reviewer checks a branch diff against. Two more layers may exist and are read
with it:

- **Machine** — `~/.claude/review-principles/`: personal, cross-repo rules
  specific to one machine or account.
- **Repo** — `.claude/review-principles/` at the target repo's root:
  repo-specific rules, check items, evidence, and overrides.

A file with the same name in more than one layer is the *same principle*:
deeper layers (repo > machine > bundled) augment the rule with local
specifics and win outright where they conflict. A repo file may narrow,
extend, or explicitly suspend a bundled rule.

## Provenance

Initial corpus synthesized 2026-07-26 from the a17k monorepo's PR review
history — the 36 PRs with ≥5 automated review rounds in the prior 3 months
(of 135 multi-round PRs, 260 total). The "From the history" sections cite
that repo's PRs; they're evidence the principle earns its place, and the
concrete narratives ground the reviewer agent even outside the origin repo.
Extended 2026-09-02 from the same repo's PRs #430–#457 (27 merged PRs,
median 3 review rounds, four PRs accounting for 41 of ~94 rounds), which
produced the two structural principles: restate-a-guard-on-its-second-finding
and keep-one-implementation-per-rule.

## File structure

One file per principle, kebab-case filename that states the rule
(`fix-the-class-not-the-instance.md`). Keep each under ~60 lines:

```markdown
# <Imperative rule statement>

<2–4 sentences: what the rule is and why it exists. Written for a reviewer
agent deciding whether a diff violates it.>

## Check

<Concrete, mechanical questions the reviewer should ask of the diff.>

## From the history

**Violation — PR #NNN:** <what happened, with file/round specifics>

**Done right — PR #NNN:** <a real example of the principle being followed,
when one exists; omit the section rather than inventing one>
```

Ground rules:

- **Every principle must cite real PR history.** A rule without a real-world
  example is an opinion; it doesn't go in.
- **The rule and checks must be repo-agnostic.** Rules that only make sense
  in one repo belong in that repo's `.claude/review-principles/` layer —
  evidence may cite specific repos, the rule itself may not depend on one.
- **Principles are about avoiding review rounds**, not style. Style belongs
  to linters. If a rule wouldn't have saved an actual round of feedback, it
  doesn't go in.
- **Prefer editing an existing principle** (adding a new example) over
  adding a near-duplicate file.
- Principles may be deleted when tooling makes them obsolete (e.g. a lint
  rule now catches it).
