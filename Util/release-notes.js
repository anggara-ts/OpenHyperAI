#!/usr/bin/env node
// Release notes draft (/release): what changed on origin/main since the last release tag, from the merged PRs.
//
//   node Util/release-notes.js [--from <tag>] [--to <ref>] [--version vX.Y] [--json]
//
// Reads `git log <from>..<to>` (default: the newest v* tag .. origin/main), takes each squash-merged PR number from
// the subject ("... (#123)"), and reads the PR with gh (title, labels, body). From the PR body it takes the change-log
// entries (AGENTS.md format: "- **What changed** (type) - **Before:** ... **Now:** ...").
//
// Kept out of the notes (listed at the end of the draft with the reason, so a person can check):
//   - a PR reverted later in the same range (a "Revert" commit naming it, or one that names its PR number);
//   - a PR whose change-log entries are all `cleanup` (logs, diagnostics, tests, refactors: no in-game effect),
//     and chore / test / ci / style / refactor PRs without a non-cleanup entry;
// Docs and tooling PRs go into one short "Project" section.
//
// Sections: "Patch 7.42" for PRs that name a patch (7.4x) in the title or labels, then "New", "Fixes", "Project".
// One line per PR: the PR title without its conventional prefix, plus the change-log entry headings (the bold part,
// which is already a short player-facing phrase). The draft is meant to be tidied by hand / by the skill.
"use strict";
const cp = require("child_process");

const argv = process.argv.slice(2);
const option = (name) => (argv.indexOf(name) >= 0 ? argv[argv.indexOf(name) + 1] : undefined);
const sh = (cmd, args) => cp.execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
const GH = process.platform === "win32" ? "C:/Program Files/GitHub CLI/gh.exe" : "gh";

function lastTag() {
	const tags = sh("git", ["tag", "--list", "v*", "--sort=-v:refname"]).split("\n").filter(Boolean);
	return tags[0] || null;
}
function nextVersion(tag) {
	const m = tag && tag.match(/^v(\d+)\.(\d+)$/);
	return m ? `v${m[1]}.${Number(m[2]) + 1}` : "v0.1";
}

// "fix(heroes): something" -> { type: "fix", scope: "heroes", text: "something" }
function parseTitle(title) {
	const m = title.match(/^(\w+)(?:\(([^)]*)\))?!?:\s*(.*)$/);
	return m ? { type: m[1].toLowerCase(), scope: m[2] || "", text: m[3] } : { type: "", scope: "", text: title };
}

// Change-log entries: "- **Heading** (type) - ..." anywhere in the body (also nested under group headings).
function parseEntries(body) {
	const entries = [];
	for (const line of (body || "").split("\n")) {
		const m = line.match(/^\s*[-*]\s+\*\*(.+?)\*\*\s*\((crash|mechanic|behaviour|behavior|cleanup)[^)]*\)/i);
		if (m) entries.push({ heading: m[1].replace(/\s+/g, " ").trim(), type: m[2].toLowerCase().replace("behavior", "behaviour") });
	}
	return entries;
}

function main() {
	const from = option("--from") || lastTag();
	const to = option("--to") || "origin/main";
	const version = option("--version") || nextVersion(from);
	const range = from ? `${from}..${to}` : to;
	const log = sh("git", ["log", "--reverse", "--format=%H%x09%s", range]).split("\n").filter(Boolean);
	const commits = log.map((line) => {
		const [sha, subject] = line.split("\t");
		const pr = (subject.match(/\(#(\d+)\)\s*$/) || [])[1];
		return { sha, subject, pr: pr ? Number(pr) : null };
	});
	// Reverts in range: "Revert ..." commits, by PR number or by the reverted subject.
	const reverted = new Set();
	for (const c of commits) {
		if (!/^revert/i.test(c.subject)) continue;
		for (const m of c.subject.matchAll(/#(\d+)/g)) reverted.add(Number(m[1]));
		const quoted = (c.subject.match(/"(.+)"/) || [])[1];
		if (quoted) for (const other of commits) if (other.subject.startsWith(quoted) && other.pr) reverted.add(other.pr);
	}

	const kept = { patch: [], feat: [], fix: [], project: [] };
	const dropped = [];
	for (const c of commits) {
		if (/^revert/i.test(c.subject)) {
			dropped.push({ ref: c.sha.slice(0, 7), title: c.subject, why: "a revert" });
			continue;
		}
		if (!c.pr) {
			dropped.push({ ref: c.sha.slice(0, 7), title: c.subject, why: "no PR (direct commit)" });
			continue;
		}
		let pr;
		try {
			pr = JSON.parse(sh(GH, ["pr", "view", String(c.pr), "--json", "number,title,body,labels,url"]));
		} catch (e) {
			dropped.push({ ref: `#${c.pr}`, title: c.subject, why: "PR not readable with gh" });
			continue;
		}
		const t = parseTitle(pr.title);
		const entries = parseEntries(pr.body);
		const labels = (pr.labels || []).map((l) => l.name);
		const effect = entries.filter((e) => e.type !== "cleanup");
		// Entry headings for the draft: no repeats, no bare "pos N" headings, nothing marked as a test-only step,
		// at most five (a PR with many per-hero entries is summed up by its title).
		const headings = [];
		for (const e of effect) {
			const h = e.heading;
			if (/^pos \d/i.test(h) || /for testing|test only|temporary/i.test(h) || headings.includes(h)) continue;
			headings.push(h);
		}
		const item = {
			number: pr.number,
			url: pr.url,
			type: t.type,
			scope: t.scope,
			text: t.text,
			entries: headings.length > 5 ? [...headings.slice(0, 5), `... and ${headings.length - 5} more`] : headings,
		};
		if (reverted.has(pr.number)) {
			dropped.push({ ref: `#${pr.number}`, title: pr.title, why: "reverted later in this range" });
		} else if (t.type === "docs" || (["chore", "ci", "build"].includes(t.type) && effect.length === 0 && /tool|skill|workflow|util|script/i.test(pr.title))) {
			kept.project.push(item);
		} else if (entries.length > 0 && effect.length === 0) {
			dropped.push({ ref: `#${pr.number}`, title: pr.title, why: "only cleanup entries (logs, tests, no in-game effect)" });
		} else if (["chore", "test", "ci", "style", "refactor", "perf", "build"].includes(t.type) && effect.length === 0) {
			dropped.push({ ref: `#${pr.number}`, title: pr.title, why: `${t.type} without an in-game change` });
		} else if (/\b7\.4\d\b/.test(pr.title) || labels.some((l) => /7\.4\d/.test(l))) {
			kept.patch.push(item);
		} else if (t.type === "feat") {
			kept.feat.push(item);
		} else {
			kept.fix.push(item);
		}
	}

	if (argv.includes("--json")) {
		console.log(JSON.stringify({ version, from, to, kept, dropped }, null, 2));
		return;
	}
	const line = (item) => {
		const head = `- ${item.text.charAt(0).toUpperCase()}${item.text.slice(1)} ([#${item.number}](${item.url}))`;
		return item.entries.length ? `${head}\n${item.entries.map((e) => `  - ${e}`).join("\n")}` : head;
	};
	const out = [`# ${version}`, "", `Changes since ${from || "the start"} (draft from Util/release-notes.js; tidy before publishing).`, ""];
	const section = (title, list) => {
		if (!list.length) return;
		out.push(`## ${title}`, "", ...list.map(line), "");
	};
	section("Patch 7.42", kept.patch);
	section("New", kept.feat);
	section("Fixes", kept.fix);
	section("Project", kept.project);
	out.push("<!-- Left out:", ...dropped.map((d) => `  ${d.ref} ${d.title} -- ${d.why}`), "-->");
	console.log(out.join("\n"));
}

main();
