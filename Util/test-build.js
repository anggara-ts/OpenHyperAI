#!/usr/bin/env node
// Integration branch for one test game: every PR in the verify tracker merged onto origin/main.
//
//   node Util/test-build.js [--dry-run] [--no-switch]
//
// 1. git fetch --prune origin (also in --dry-run: updates origin/* and drops deleted remote branches).
// 2. Builds the LOCAL branch `test/next` (never pushed) = origin/main + each tracked PR branch
//    (Util/verify/tracker.json, ascending PR number) merged with `git merge --no-edit --no-ff origin/<branch>`.
//    The merges run in a temporary detached worktree, so your working tree, index and HEAD are not touched
//    while it builds. A PR that conflicts is aborted (`git merge --abort`) and skipped.
// 3. Writes Util/verify/test-build.json: { base, head, builtAt, included, upToDate, conflicts, missing }.
// 4. Switches the working tree to test/next (the game runs the checked-out tree) unless --no-switch.
//    Only Customize/general.lua (the local test lineup) may be modified: it is carried across the switch
//    (stashed and restored on its own if it differs between the branches). Any other modified tracked file
//    stops the switch.
//
// --dry-run   fetch, then report what would merge or conflict (git merge-tree: no commits, no branch, no files).
// --no-switch build test/next but stay on the current branch.
// --with <branch>  also merge this origin branch (repeatable), after the tracked PRs: e.g. a tooling PR that
//             isn't tracked (nothing to see in game) but whose files you need on test/next, such as
//             Util/after-game.js before it reaches main.
//
// Afterwards: play the game, then `node Util/verify.js check <log> --game NNN`. Go back with `git switch <branch>`.
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const ROOT = path.join(__dirname, "..");
const TRACKER = path.join(__dirname, "verify", "tracker.json");
const OUT = path.join(__dirname, "verify", "test-build.json");
const BRANCH = "test/next";
const LINEUP = "Customize/general.lua";

const args = process.argv.slice(2);
const DRY = args.includes("--dry-run");
const NO_SWITCH = args.includes("--no-switch");

function git(a, opts = {}) {
	const r = cp.spawnSync("git", a, { cwd: opts.cwd || ROOT, encoding: "utf8" });
	if (r.status !== 0 && !opts.allowFail) {
		throw new Error(`git ${a.join(" ")} failed (${r.status}):\n${(r.stderr || "") + (r.stdout || "")}`.trim());
	}
	return opts.allowFail ? r : r.stdout.trim();
}

function trackedPrs() {
	let db;
	try {
		db = JSON.parse(fs.readFileSync(TRACKER, "utf8"));
	} catch (e) {
		throw new Error(`cannot read ${path.relative(ROOT, TRACKER)}: ${e.message}`);
	}
	const list = Object.entries(db.prs || {})
		.map(([n, p]) => ({ n: Number(n), branch: p.branch, title: p.title }))
		.filter((p) => p.branch)
		.sort((a, b) => a.n - b.n);
	// --with <branch>: extra branches merged after the tracked PRs (n = the branch name: not a tracked PR).
	for (let i = 0; i < args.length; i++) {
		if (args[i] === "--with" && args[i + 1] && !list.some((p) => p.branch === args[i + 1])) {
			list.push({ n: args[i + 1], branch: args[i + 1], title: `(--with) ${args[i + 1]}` });
		}
	}
	return list;
}

// Modified tracked files other than the test lineup (untracked files are ignored).
function otherChanges() {
	return git(["status", "--porcelain", "--untracked-files=no"], { allowFail: true })
		.stdout.split(/\r?\n/)
		.filter(Boolean)
		.map((l) => l.slice(3).replace(/^"|"$/g, ""))
		.filter((f) => f !== LINEUP);
}

function remoteExists(branch) {
	return git(["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${branch}`], { allowFail: true }).status === 0;
}

function isAncestor(a, b, cwd) {
	return git(["merge-base", "--is-ancestor", a, b], { allowFail: true, cwd }).status === 0;
}

// --dry-run: chain the merges as trees with `git merge-tree --write-tree` (git >= 2.40); nothing is written
// except loose tree/blob objects. The merge base of each step is the base between the PR branch and the
// hypothetical merge of origin/main with every PR merged before it, which is what a real merge would use.
function dryRun(prs, result) {
	let tree = git(["rev-parse", "origin/main^{tree}"]);
	const merged = ["origin/main"];
	for (const p of prs) {
		const ref = `origin/${p.branch}`;
		if (!remoteExists(p.branch)) {
			result.missing.push(p.n);
			console.log(`#${p.n} ${p.branch}: MISSING (no origin/${p.branch})`);
			continue;
		}
		if (merged.some((m) => isAncestor(ref, m))) {
			result.upToDate.push(p.n);
			console.log(`#${p.n} ${p.branch}: already contained (nothing to merge)`);
			continue;
		}
		const base = git(["merge-base", ref, ...merged]).split(/\r?\n/)[0];
		const r = git(["merge-tree", "--write-tree", "--name-only", `--merge-base=${base}`, tree, ref], { allowFail: true });
		if (r.status === 0) {
			tree = r.stdout.trim().split(/\r?\n/)[0];
			merged.push(ref);
			result.included.push(p.n);
			console.log(`#${p.n} ${p.branch}: merges cleanly`);
		} else if (r.status === 1) {
			// output: tree oid, conflicted file names, blank line, messages
			const files = r.stdout.split(/\r?\n\r?\n/)[0].split(/\r?\n/).slice(1).filter(Boolean);
			result.conflicts.push(p.n);
			console.log(`#${p.n} ${p.branch}: CONFLICT (skipped) in ${files.join(", ")}`);
		} else {
			throw new Error(`git merge-tree failed for ${ref}:\n${r.stderr}`);
		}
	}
}

function build(prs, result) {
	const wt = fs.mkdtempSync(path.join(os.tmpdir(), "oha-test-build-"));
	fs.rmdirSync(wt); // git worktree add wants to create it
	try {
		// --no-checkout + reset --hard: a post-checkout hook in the temp tree (pre-commit without its config on
		// origin/main) would otherwise fail the add
		git(["worktree", "add", "--detach", "--no-checkout", "--quiet", wt, "origin/main"]);
		git(["reset", "--hard", "--quiet"], { cwd: wt });
		for (const p of prs) {
			const ref = `origin/${p.branch}`;
			if (!remoteExists(p.branch)) {
				result.missing.push(p.n);
				console.log(`#${p.n} ${p.branch}: MISSING (no origin/${p.branch})`);
				continue;
			}
			if (isAncestor(ref, "HEAD", wt)) {
				result.upToDate.push(p.n);
				console.log(`#${p.n} ${p.branch}: already contained (nothing to merge)`);
				continue;
			}
			const r = git(["merge", "--no-edit", "--no-ff", "-m", `Merge ${ref} (#${p.n}) into ${BRANCH}`, ref], {
				cwd: wt,
				allowFail: true,
			});
			if (r.status === 0) {
				result.included.push(p.n);
				console.log(`#${p.n} ${p.branch}: merged`);
				continue;
			}
			const unmerged = git(["diff", "--name-only", "--diff-filter=U"], { cwd: wt, allowFail: true }).stdout.trim();
			git(["merge", "--abort"], { cwd: wt, allowFail: true });
			if (!unmerged) {
				// not a conflict (signing, hooks, ...): stop rather than silently skipping the PR
				throw new Error(`merging ${ref} failed without a conflict:\n${(r.stderr || "") + (r.stdout || "")}`);
			}
			result.conflicts.push(p.n);
			console.log(`#${p.n} ${p.branch}: CONFLICT (skipped) in ${unmerged.split(/\r?\n/).join(", ")}`);
		}
		result.head = git(["rev-parse", "HEAD"], { cwd: wt });
	} finally {
		git(["worktree", "remove", "--force", wt], { allowFail: true });
		git(["worktree", "prune"], { allowFail: true });
	}
	const current = git(["symbolic-ref", "--quiet", "--short", "HEAD"], { allowFail: true }).stdout.trim();
	if (current === BRANCH) {
		// already on test/next (an earlier build): move it, keeping the local lineup edit
		git(["reset", "--keep", result.head]);
	} else {
		git(["branch", "-f", BRANCH, result.head]);
	}
	return current;
}

// git switch exits non-zero when a post-checkout hook fails although the switch happened: check the branch.
function switchBranch() {
	const r = git(["switch", BRANCH], { allowFail: true });
	if (r.status === 0) return;
	const now = git(["symbolic-ref", "--quiet", "--short", "HEAD"], { allowFail: true }).stdout.trim();
	if (now !== BRANCH) throw new Error(`git switch ${BRANCH} failed:\n${r.stderr}`);
	console.log(`warning: switched, but a post-checkout hook failed:\n${r.stderr.trim()}`);
}

// Switch to test/next carrying Customize/general.lua. Git carries it by itself when the file is the same on
// both commits; otherwise stash that one file, switch, and put the maintainer's version back.
function switchTo() {
	const lineupDirty = git(["status", "--porcelain", "--", LINEUP]).length > 0;
	const same = git(["diff", "--quiet", "HEAD", BRANCH, "--", LINEUP], { allowFail: true }).status === 0;
	if (!lineupDirty || same) {
		switchBranch();
		return;
	}
	const backup = path.join(__dirname, "verify", "general.lua.bak");
	fs.copyFileSync(path.join(ROOT, LINEUP), backup);
	git(["stash", "push", "--quiet", "-m", "test-build: Customize/general.lua", "--", LINEUP]);
	try {
		switchBranch();
	} catch (e) {
		// still on the old branch: put the lineup back before giving up
		if (git(["stash", "pop", "--quiet"], { allowFail: true }).status !== 0) fs.copyFileSync(backup, path.join(ROOT, LINEUP));
		throw e;
	}
	const pop = git(["stash", "pop", "--quiet"], { allowFail: true });
	if (pop.status !== 0) {
		// the branch's version differs: the maintainer's lineup wins, the stash entry is dropped
		git(["checkout", BRANCH, "--", LINEUP]);
		fs.copyFileSync(backup, path.join(ROOT, LINEUP));
		git(["reset", "--quiet", "--", LINEUP]);
		git(["stash", "drop", "--quiet"], { allowFail: true });
	}
	console.log(`(${LINEUP} carried over via stash; copy kept in ${path.relative(ROOT, backup)})`);
}

function main() {
	const others = otherChanges();
	if (others.length) {
		const msg = `modified tracked files besides ${LINEUP}: ${others.join(", ")}`;
		if (!DRY && !NO_SWITCH) throw new Error(`refusing to switch: ${msg}\ncommit or stash them first`);
		console.log(`warning: ${msg} (would refuse without --dry-run / --no-switch)`);
	}
	const prs = trackedPrs();
	if (!prs.length) throw new Error("no PRs in the tracker (node Util/verify.js add <pr>)");
	console.log(`fetching origin ...`);
	git(["fetch", "--quiet", "--prune", "origin"]);
	const result = {
		base: git(["rev-parse", "origin/main"]),
		head: null,
		builtAt: new Date().toISOString(),
		included: [],
		upToDate: [],
		conflicts: [],
		missing: [],
	};
	console.log(`base origin/main ${result.base.slice(0, 10)}; PRs: ${prs.map((p) => `#${p.n}`).join(" ")}`);
	if (DRY) {
		dryRun(prs, result);
		console.log(`\ndry run: would build ${BRANCH} with ${result.included.map((n) => `#${n}`).join(" ") || "nothing"}` +
			(result.conflicts.length ? `; conflicting: ${result.conflicts.map((n) => `#${n}`).join(" ")}` : ""));
		return;
	}
	const current = build(prs, result);
	fs.writeFileSync(OUT, JSON.stringify(result, null, 2) + "\n");
	console.log(`\n${BRANCH} = ${result.head.slice(0, 10)}  included: ${result.included.map((n) => `#${n}`).join(" ") || "none"}` +
		(result.conflicts.length ? `  CONFLICTS: ${result.conflicts.map((n) => `#${n}`).join(" ")}` : "") +
		(result.missing.length ? `  missing: ${result.missing.map((n) => `#${n}`).join(" ")}` : ""));
	console.log(`wrote ${path.relative(ROOT, OUT)}`);
	if (NO_SWITCH || current === BRANCH) {
		console.log(current === BRANCH ? `working tree is on ${BRANCH}` : `staying on ${current || "detached HEAD"} (--no-switch)`);
		return;
	}
	switchTo();
	console.log(`switched to ${BRANCH} (from ${current || "detached HEAD"}); go back with: git switch ${current || "<branch>"}`);
}

try {
	main();
} catch (e) {
	console.error(e.message);
	process.exit(1);
}
