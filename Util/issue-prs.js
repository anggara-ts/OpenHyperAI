#!/usr/bin/env node
// Starts work on issues (WIP) and keeps the PRs' priority labels in step with their issues.
//
//   node Util/issue-prs.js            priority sync only: each open PR gets its issue's priority label, and
//                                     untriaged issues (no P1-P4 label) are listed. Creates nothing.
//   node Util/issue-prs.js 12 34      start work on issues #12 and #34 (also: issues labelled "wip")
//   node Util/issue-prs.js --dry-run  show what would happen
//
// Filing an issue does not open a PR: an empty draft PR per issue only clutters the PR list. A branch and draft
// PR are made when work starts. For each started issue without a PR (matched by "Refs #N" / "Closes #N" in a
// PR body or "issue-N" in the branch):
//   - branch  <prefix>/issue-<N>-<slug>  from origin/main  (prefix: feat for "enhancement", docs for
//     "documentation", chore for "chore", otherwise fix)
//   - one signed empty commit (git commit-tree -S, so no checkout and no working-tree change),
//   - a draft PR titled "<prefix>: <issue title> (#N)" with the PR template and "Refs #N".
//     Never "Closes #N": merging a PR must not close the issue. The issue is closed by hand when every
//     task item in it is ticked (an issue card can need several PRs or games).
// Every open PR that refers to an issue gets the issue's priority label (P1 critical .. P4 low), and issues
// without one are listed as untriaged.
// Issues labelled "no-pr" are skipped. Runs locally (not as a GitHub Action) because the branch rules require
// commits signed with the maintainer's key.
"use strict";
const cp = require("child_process");
const path = require("path");
const fs = require("fs");

const DRY = process.argv.includes("--dry-run");
const START = new Set(
	process.argv
		.slice(2)
		.map((a) => a.replace(/^#/, ""))
		.filter((a) => /^\d+$/.test(a))
		.map(Number)
);
const GH = process.env.GH || (process.platform === "win32" ? "C:\\Program Files\\GitHub CLI\\gh.exe" : "gh");
const ROOT = path.join(__dirname, "..");

const gh = (args) => cp.execFileSync(GH, args, { encoding: "utf8", cwd: ROOT });
const git = (args) => cp.execFileSync("git", args, { encoding: "utf8", cwd: ROOT }).trim();

function prefixFor(labels) {
	if (labels.includes("enhancement")) return "feat";
	if (labels.includes("documentation")) return "docs";
	if (labels.includes("chore")) return "chore";
	return "fix";
}
function slug(title) {
	return title
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 40)
		.replace(/-+$/, "");
}

const issues = JSON.parse(gh(["issue", "list", "--state", "open", "--limit", "200", "--json", "number,title,labels,url"]));
const prs = JSON.parse(
	gh(["pr", "list", "--state", "all", "--limit", "300", "--json", "number,headRefName,body,state,labels"])
);
const PRIORITY = ["P1 critical", "P2 high", "P3 medium", "P4 low"];
const covered = new Set();
// Only an OPEN PR covers an issue. A closed draft or a merged batch must not stop new work on the card
// (the goodnight run of 2026-11-18 found #34 "covered" by its closed empty draft #35).
for (const pr of prs) {
	if (pr.state !== "OPEN") continue;
	for (const m of (pr.body || "").matchAll(/(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?|refs?|related to|part of)\s+#(\d+)/gi)) covered.add(Number(m[1]));
	const b = pr.headRefName.match(/issue-(\d+)/);
	if (b) covered.add(Number(b[1]));
}

const template = fs.readFileSync(path.join(ROOT, ".github", "pull_request_template.md"), "utf8");
git(["fetch", "-q", "origin", "main"]);
const baseSha = git(["rev-parse", "origin/main"]);
const baseTree = git(["rev-parse", "origin/main^{tree}"]);

let made = 0;
for (const issue of issues) {
	const labels = issue.labels.map((l) => l.name);
	if (covered.has(issue.number) || labels.includes("no-pr")) continue;
	if (!START.has(issue.number) && !labels.includes("wip")) continue;
	const prefix = prefixFor(labels);
	// A merged or closed earlier PR may have used the name: add -2, -3, ... until the branch is free.
	const baseBranch = `${prefix}/issue-${issue.number}-${slug(issue.title)}`;
	const taken = (name) => git(["ls-remote", "--heads", "origin", name]) !== "";
	let branch = baseBranch;
	for (let n = 2; taken(branch) && n < 20; n++) branch = `${baseBranch}-${n}`;
	const title = `${prefix}: ${issue.title} (#${issue.number})`;
	console.log(`#${issue.number} -> ${branch}`);
	if (DRY) continue;
	const sha = git(["commit-tree", "-S", baseTree, "-p", baseSha, "-m", `chore: start work on #${issue.number}\n\n${issue.title}`]);
	git(["push", "-q", "origin", `${sha}:refs/heads/${branch}`]);
	const body = `Refs #${issue.number}\n\n` + template;
	const out = gh(["pr", "create", "--draft", "--base", "main", "--head", branch, "--title", title, "--body", body]);
	console.log("   " + out.trim());
	made++;
}
console.log(DRY ? "dry run, nothing created" : `${made} draft PR(s) created${START.size ? "" : " (start work with: node Util/issue-prs.js <issue numbers>)"}`);

// Priority: the issue decides, its open PRs follow. Untriaged issues are listed so they get a label.
const untriaged = [];
const prsNow = DRY ? prs : JSON.parse(gh(["pr", "list", "--state", "open", "--limit", "300", "--json", "number,headRefName,body,labels"]));
for (const issue of issues) {
	const prio = issue.labels.map((l) => l.name).find((n) => PRIORITY.includes(n));
	if (!prio) {
		if (issue.labels.some((l) => l.name === "icebox")) continue; // parked on purpose: no priority
		untriaged.push(issue.number);
		continue;
	}
	for (const pr of prsNow) {
		const refs = [...(pr.body || "").matchAll(/(?:refs?|related to|part of)\s+#(\d+)/gi)].map((m) => Number(m[1]));
		const b = pr.headRefName.match(/issue-(\d+)/);
		if (!refs.includes(issue.number) && !(b && Number(b[1]) === issue.number)) continue;
		const has = (pr.labels || []).map((l) => l.name);
		if (has.includes(prio) && !has.some((n) => PRIORITY.includes(n) && n !== prio)) continue;
		const args = ["pr", "edit", String(pr.number), "--add-label", prio];
		for (const other of PRIORITY) if (other !== prio && has.includes(other)) args.push("--remove-label", other);
		console.log(`PR #${pr.number}: priority ${prio} (from issue #${issue.number})`);
		if (!DRY) gh(args);
	}
}
if (untriaged.length) console.log(`untriaged issues (add P1 critical / P2 high / P3 medium / P4 low): ${untriaged.map((n) => "#" + n).join(" ")}`);
