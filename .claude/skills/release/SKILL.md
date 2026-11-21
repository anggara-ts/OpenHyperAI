---
name: release
description: Prepare or publish an OpenHyperAI release - next version number, release notes from the PRs merged into main since the last release, version files, tag and GitHub release. Dry run by default; "/release publish" publishes. Use when the maintainer asks for a release, a version, a tag or release notes.
---

# Release

A release is a git tag `vX.Y` on `main` plus a GitHub release with notes. Rules: `AGENTS.md` (Commits: the version
files are bumped by hand only for a release; Branches; Things not to do).

**Default is a dry run**: steps 1-4, then stop and show the result. Publish (steps 5-8) only when the maintainer
says so in this conversation ("/release publish", "publish it", "go"). Publishing is outward-facing: never publish
on an earlier or general approval.

## 1. Range and version
- `git fetch origin --tags`. The last release is the newest `v*` tag (`git tag --list "v*" --sort=-v:refname`).
- Next version: minor + 1 (`v0.2` -> `v0.3`) unless the maintainer names another (a major bump for a big change).
- Version files (bumped only in the release PR):
  - `Customize/version.lua`, `number = "YYYY.MM.DD-NNN"`: the release date, and NNN = the previous NNN plus the
    number of commits on main since the last tag (`git rev-list --count <tag>..origin/main`), zero-padded to 3.
  - `FuncLib/systems/version.lua`, `Version.number = "0.<game patch> - YYYY/MM/DD"`: the Dota patch the release is
    for (e.g. `0.7.42`) and the release date.

## 2. Draft
`node Util/release-notes.js` prints a draft: one line per merged PR since the last tag (title without its
conventional prefix, plus the change-log entry headings from the PR body), in the sections Patch, New, Fixes,
Project, and a hidden "Left out" list: reverts, PRs reverted later in the range, and PRs whose change-log entries
are all `cleanup` (logs, diagnostics, tests). `--json` gives the same data.

## 3. Tidy the notes (the part that matters)
Write the notes for players and server hosts, not for us:
- **Brief.** One line per change a player can notice, in plain words; group related PRs into one line (all Kez
  fixes, all lotus / rune fixes). Aim for 15-30 lines in total.
- **No noise.** Leave out: debug and log-only changes, diagnostics, tests, performance probes, tooling for
  ourselves, steps that were reverted or switched off before the release (also inside a PR: a "temporary" or
  "for testing" entry, an entry undone by a later entry of the same PR), internal game numbers ("game 051"),
  issue-card wording. Check the "Left out" list: pull an item back only if players notice it (e.g. a real FPS gain).
- **Sections** (skip an empty one): **Patch <version>** (what the release does for the new Dota patch),
  **Heroes**, **Items and builds**, **Team play** (laning, fights, retreat, objectives), **Fixes**,
  **Known limitations** (new entries of the main post of discussion #50 in the range, one line each, with the
  link), **Project** (one line: docs / install changes, if any).
- Each line ends with the PR links: `(#130, #115)`. Name heroes and items as the game does.
- End with `**Full changelog**: https://github.com/<owner>/<repo>/compare/<last tag>...<new tag>`.

## 4. Dry run output
Show the maintainer: the new version and the two version-file values, the tidied notes, and the "Left out" list
in one line each. Stop here unless publishing was asked for.

## 5. Ready to publish?
- `main` CI is green (`gh run list --branch main --limit 3`), and a game on a build of `main` alone ran clean
  (no freeze, no `[OHA-ERROR]`): if not, say so and stop.
- No open PR the maintainer named as part of this release is still open.

## 6. Release PR
- Branch `chore/release-vX.Y` from `origin/main` (own worktree; never commit on main). Bump the two version files
  (step 1), signed commit `chore(release): vX.Y`, push, PR with the notes as description, CI green,
  squash-merge (`gh pr merge --squash --delete-branch`).

## 7. Tag and release
- `git fetch origin`; tag the merge commit: `git tag -s vX.Y -m "vX.Y" origin/main` (signed, like the commits),
  `git push origin vX.Y`.
- `gh release create vX.Y --title "vX.Y" --notes-file <notes.md> --verify-tag`.

## 8. Report
The release URL, the version, and what is not in it (open PRs that wait for the next release).
