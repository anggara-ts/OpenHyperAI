#!/usr/bin/env node
// Copies only the bot scripts of this repo into Dota's bot folder (game/dota/scripts/vscripts/bots) (#177).
//
//   node Util/export-bots.js                 Workshop copy: origin/main exactly as committed
//   node Util/export-bots.js --test-game     test-game copy: HEAD + the working-tree Customize/general.lua
//                                            (the local test lineup) + Customize/build_info.lua for that commit
//   options: --ref <rev>        export another commit (default origin/main; HEAD with --test-game)
//            --dest <dir>       another target folder (default: the Dota install found through Steam)
//            --dota <dir>       the "dota 2 beta/game/dota" folder, when it is not found automatically
//            --dry-run          only report what would change
//            --remove           delete the copy this tool wrote (and the folder, when nothing else is in it)
//            --force            take over a folder this tool did not write (deletes the files already in it)
//   node Util/export-bots.js --self-test     checks the file selection, the require check and the folder rules
//
// What is a bot script: tracked .lua files at the repo root and under BotsLib/, FuncLib/ and Customize/, read
// from git (never the working tree, so .git, .env, match logs, tests, tools, docs and uncommitted edits never get
// in). Before writing, every literal require / dofile target must be in the copy.
// Folder rules: never write through a symlink or junction (the dev setup may link vscripts/bots to the clone),
// never write inside a worktree of this repo or into a folder with .git, and only delete files this tool wrote
// there before. That list lives outside the folder (in .git, so it is never uploaded or committed).
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const ROOT = path.join(__dirname, "..");
const RUNTIME_DIRS = ["BotsLib/", "FuncLib/", "Customize/"];
const LINEUP_FILE = "Customize/general.lua";
const BUILD_INFO_FILE = "Customize/build_info.lua";
// Literal targets that may be absent: Customize/version.lua loads build_info with pcall.
const OPTIONAL_TARGETS = new Set(["Customize/build_info"]);
const SCRIPT_REQUIRE = /\b(?:require|dofile)\s*(?:\(\s*|,\s*)GetScriptDirectory\(\)\s*\.\.\s*"\/([^"]+)"(\s*\.\.)?/g;
const BOTS_REQUIRE = /\brequire\s*\(?\s*"bots[./]([^"]+)"/g;
const IS_WINDOWS = process.platform === "win32";

function git(args, options = {}) {
	return cp.execFileSync("git", ["--no-optional-locks", ...args], {
		cwd: ROOT,
		maxBuffer: 1 << 30,
		...options,
	});
}

function gitText(args) {
	return git(args, { encoding: "utf8" }).trim();
}

// ---------------------------------------------------------------- what goes in

function isBotScript(file) {
	if (!file.endsWith(".lua")) return false;
	if (!file.includes("/")) return true;
	return RUNTIME_DIRS.some((dir) => file.startsWith(dir));
}

// Reads the bot scripts of one commit: Map(path -> Buffer), plus the counts of what was left out.
function collect(ref) {
	const commit = gitText(["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);
	const entries = git(["ls-tree", "-r", "-z", "--full-tree", commit], { encoding: "utf8" })
		.split("\0")
		.filter(Boolean)
		.map((line) => {
			const tab = line.indexOf("\t");
			const [mode, type, sha] = line.slice(0, tab).split(" ");
			return { mode, type, sha, file: line.slice(tab + 1) };
		});
	const selected = [];
	const leftOut = {};
	for (const entry of entries) {
		if (isBotScript(entry.file)) {
			if (entry.type !== "blob" || entry.mode === "120000") {
				throw new Error(`${entry.file} is a ${entry.mode === "120000" ? "symlink" : entry.type}, not a file`);
			}
			selected.push(entry);
		} else {
			const top = entry.file.includes("/") ? entry.file.split("/")[0] + "/" : "(root files)";
			leftOut[top] = (leftOut[top] || 0) + 1;
		}
	}
	const blobs = readBlobs(selected.map((entry) => entry.sha));
	const files = new Map();
	selected.forEach((entry, i) => files.set(entry.file, blobs[i]));
	return { commit, files, leftOut };
}

// One "git cat-file --batch" for all blobs: "<sha> blob <size>\n<content>\n" each.
function readBlobs(shas) {
	if (shas.length === 0) return [];
	const out = git(["cat-file", "--batch"], { input: shas.join("\n") + "\n" });
	const blobs = [];
	let pos = 0;
	for (const sha of shas) {
		const newline = out.indexOf(10, pos);
		const header = out.toString("utf8", pos, newline).split(" ");
		if (header[0] !== sha || header[1] !== "blob") throw new Error(`git cat-file: unexpected "${header.join(" ")}"`);
		const size = Number(header[2]);
		blobs.push(out.subarray(newline + 1, newline + 1 + size));
		pos = newline + 1 + size + 1;
	}
	return blobs;
}

// Literal require / dofile targets that are not in the copy: [{ file, target }].
// Paths built at run time ("/BotsLib/" .. heroFile) are skipped, as in Tests/test_requires.lua.
function missingRequires(files) {
	const missing = [];
	for (const [file, content] of files) {
		if (!file.endsWith(".lua")) continue;
		const source = content.toString("utf8");
		const targets = [];
		for (const match of source.matchAll(SCRIPT_REQUIRE)) {
			if (!match[2]) targets.push(match[1]);
		}
		for (const match of source.matchAll(BOTS_REQUIRE)) targets.push(match[1].replace(/\./g, "/"));
		for (const raw of targets) {
			const target = raw.replace(/\.lua$/, "");
			if (!files.has(target + ".lua") && !OPTIONAL_TARGETS.has(target)) missing.push({ file, target });
		}
	}
	return missing;
}

// ---------------------------------------------------------------- where it goes

function steamRoots() {
	const roots = [];
	if (IS_WINDOWS) {
		try {
			const out = cp.execFileSync("reg", ["query", "HKCU\\Software\\Valve\\Steam", "/v", "SteamPath"], {
				encoding: "utf8",
				stdio: ["ignore", "pipe", "ignore"],
			});
			const match = out.match(/SteamPath\s+REG_SZ\s+(.+)/);
			if (match) roots.push(match[1].trim());
		} catch {
			// no Steam key: fall back to the default folder
		}
		roots.push("C:/Program Files (x86)/Steam");
	} else if (process.platform === "darwin") {
		roots.push(path.join(os.homedir(), "Library/Application Support/Steam"));
	} else {
		roots.push(path.join(os.homedir(), ".local/share/Steam"), path.join(os.homedir(), ".steam/steam"));
	}
	return roots;
}

// The "dota 2 beta/game/dota" folder, from Steam's library list.
function findDota() {
	const libraries = [];
	for (const root of steamRoots()) {
		libraries.push(root);
		try {
			const vdf = fs.readFileSync(path.join(root, "steamapps", "libraryfolders.vdf"), "utf8");
			for (const match of vdf.matchAll(/"path"\s+"([^"]+)"/g)) libraries.push(match[1].replace(/\\\\/g, "\\"));
		} catch {
			// no library list in this root
		}
	}
	for (const library of libraries) {
		const dota = path.join(library, "steamapps", "common", "dota 2 beta", "game", "dota");
		if (fs.existsSync(dota)) return dota;
	}
	return null;
}

function samePathKey(p) {
	return IS_WINDOWS ? path.resolve(p).toLowerCase() : path.resolve(p);
}

function isInside(child, parent) {
	const relative = path.relative(samePathKey(parent), samePathKey(child));
	return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

// The real path of a folder that may not exist yet: realpath of the nearest existing parent plus the rest.
function realPathOf(p) {
	let existing = path.resolve(p);
	const rest = [];
	while (!fs.existsSync(existing)) {
		rest.unshift(path.basename(existing));
		const parent = path.dirname(existing);
		if (parent === existing) break;
		existing = parent;
	}
	return path.join(fs.realpathSync.native(existing), ...rest);
}

function worktreeRoots() {
	return gitText(["worktree", "list", "--porcelain"])
		.split(/\r?\n/)
		.filter((line) => line.startsWith("worktree "))
		.map((line) => line.slice("worktree ".length));
}

// Throws when the folder must not be written: a link, inside (or around) a worktree, a git folder.
function assertDestSafe(dest, repoRoots) {
	let stat = null;
	try {
		stat = fs.lstatSync(dest);
	} catch {
		// does not exist yet: fine
	}
	if (stat && stat.isSymbolicLink()) {
		throw new Error(
			`${dest} is a link (to ${fs.readlinkSync(dest)}). The tool never writes through a link: ` +
				"rename the link (e.g. to bots-dev) or pass --dest."
		);
	}
	if (stat && !stat.isDirectory()) throw new Error(`${dest} is a file, not a folder`);
	const real = realPathOf(dest);
	for (const root of repoRoots) {
		const realRoot = fs.existsSync(root) ? fs.realpathSync.native(root) : root;
		if (isInside(real, realRoot)) throw new Error(`${dest} is inside the git worktree ${root}`);
		if (isInside(realRoot, real)) throw new Error(`${dest} contains the git worktree ${root}`);
	}
	if (stat && fs.existsSync(path.join(dest, ".git"))) throw new Error(`${dest} contains .git`);
}

// Every file under dir as "a/b.lua"; throws on a link inside it (it could point anywhere).
function listFiles(dir) {
	const out = [];
	const walk = (sub) => {
		for (const entry of fs.readdirSync(path.join(dir, sub), { withFileTypes: true })) {
			const rel = sub ? `${sub}/${entry.name}` : entry.name;
			if (entry.isSymbolicLink()) throw new Error(`${path.join(dir, rel)} is a link; remove it by hand first`);
			if (entry.isDirectory()) walk(rel);
			else out.push(rel);
		}
	};
	if (fs.existsSync(dir)) walk("");
	return out.sort();
}

// ---------------------------------------------------------------- the list of what the tool wrote

// Kept in the shared .git folder (all worktrees of the clone see it; never committed, never uploaded).
function fileManifest() {
	const file = path.join(path.resolve(ROOT, gitText(["rev-parse", "--git-common-dir"])), "oha-export-bots.json");
	const read = () => {
		try {
			return JSON.parse(fs.readFileSync(file, "utf8"));
		} catch {
			return {};
		}
	};
	const write = (all) => fs.writeFileSync(file, JSON.stringify(all, null, "\t") + "\n", "utf8");
	return {
		get: (dest) => read()[samePathKey(dest)],
		set: (dest, entry) => write({ ...read(), [samePathKey(dest)]: entry }),
		del: (dest) => {
			const all = read();
			delete all[samePathKey(dest)];
			write(all);
		},
	};
}

// ---------------------------------------------------------------- plan and apply

function plan(dest, files, previous, force) {
	const owned = new Set((previous && previous.files) || []);
	const existing = listFiles(dest);
	const foreign = existing.filter((file) => !owned.has(file));
	if (foreign.length > 0 && !force) {
		const shown = foreign.slice(0, 10).join(", ") + (foreign.length > 10 ? `, ... (${foreign.length})` : "");
		throw new Error(
			`${dest} has files this tool did not write: ${shown}. ` +
				"Move them away, or pass --force to delete them and take over the folder."
		);
	}
	const remove = existing.filter((file) => !files.has(file));
	const unchanged = new Set();
	for (const [file, content] of files) {
		if (!existing.includes(file)) continue;
		if (fs.readFileSync(path.join(dest, file)).equals(content)) unchanged.add(file);
	}
	const write = [...files.keys()].filter((file) => !unchanged.has(file));
	return { remove, write, unchanged, foreign };
}

function pruneEmptyDirs(dest, removed) {
	const dirs = new Set();
	for (const file of removed) {
		let dir = path.posix.dirname(file);
		while (dir !== ".") {
			dirs.add(dir);
			dir = path.posix.dirname(dir);
		}
	}
	const deepestFirst = [...dirs].sort((a, b) => b.split("/").length - a.split("/").length);
	for (const dir of deepestFirst) {
		const full = path.join(dest, dir);
		if (fs.existsSync(full) && fs.readdirSync(full).length === 0) fs.rmdirSync(full);
	}
}

function apply(dest, files, steps, manifest, info) {
	const previous = manifest.get(dest);
	// Record the union first: if the copy stops halfway, the next run still knows every file it may have written.
	const union = new Set([...((previous && previous.files) || []), ...files.keys()]);
	fs.mkdirSync(dest, { recursive: true });
	manifest.set(dest, { ...info, files: [...union].sort() });
	for (const file of steps.remove) fs.unlinkSync(path.join(dest, file));
	pruneEmptyDirs(dest, steps.remove);
	for (const file of steps.write) {
		const full = path.join(dest, file);
		fs.mkdirSync(path.dirname(full), { recursive: true });
		fs.writeFileSync(full, files.get(file));
	}
	manifest.set(dest, { ...info, files: [...files.keys()].sort() });
}

// Deletes what the tool wrote; keeps anything else (and then the folder).
function removeExport(dest, manifest, force, dryRun) {
	const previous = manifest.get(dest);
	const owned = new Set((previous && previous.files) || []);
	const existing = listFiles(dest);
	const foreign = existing.filter((file) => !owned.has(file));
	const remove = force ? existing : existing.filter((file) => owned.has(file));
	const kept = force ? [] : foreign;
	if (!dryRun) {
		for (const file of remove) fs.unlinkSync(path.join(dest, file));
		pruneEmptyDirs(dest, remove);
		if (fs.existsSync(dest) && fs.readdirSync(dest).length === 0) fs.rmdirSync(dest);
		if (previous) manifest.del(dest);
	}
	return { remove, kept };
}

// ---------------------------------------------------------------- command line

function parseArgs(argv) {
	const args = { dryRun: false, force: false, remove: false, testGame: false, selfTest: false };
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		const value = () => {
			if (i + 1 >= argv.length) throw new Error(`${arg} needs a value`);
			return argv[++i];
		};
		if (arg === "--ref") args.ref = value();
		else if (arg === "--dest") args.dest = value();
		else if (arg === "--dota") args.dota = value();
		else if (arg === "--dry-run") args.dryRun = true;
		else if (arg === "--force") args.force = true;
		else if (arg === "--remove") args.remove = true;
		else if (arg === "--test-game") args.testGame = true;
		else if (arg === "--self-test") args.selfTest = true;
		else if (arg === "--help" || arg === "-h") args.help = true;
		else throw new Error(`unknown option ${arg} (see --help)`);
	}
	return args;
}

function usage() {
	const header = fs.readFileSync(__filename, "utf8").split(/\r?\n/).slice(1);
	console.log(
		header
			.filter((line) => line.startsWith("//"))
			.map((line) => line.replace(/^\/\/ ?/, ""))
			.join("\n")
	);
}

function megabytes(files) {
	let bytes = 0;
	for (const content of files.values()) bytes += content.length;
	return (bytes / 1024 / 1024).toFixed(1) + " MB";
}

// Tracked bot scripts other than the lineup that differ from HEAD: they are not in a test-game copy.
function uncommittedChanges() {
	// Not gitText: trimming would eat the leading status column of the first line.
	return git(["status", "--porcelain", "--untracked-files=no"], { encoding: "utf8" })
		.split(/\r?\n/)
		.filter(Boolean)
		.map((line) => line.slice(3).replace(/^.* -> /, "").replace(/^"|"$/g, ""))
		.filter((file) => file !== LINEUP_FILE && isBotScript(file));
}

function resolveDest(args) {
	if (args.dest) return path.resolve(args.dest);
	const dota = args.dota ? path.resolve(args.dota) : findDota();
	if (!dota || !fs.existsSync(dota)) {
		throw new Error('Dota not found: pass --dota "<...>/dota 2 beta/game/dota" or --dest <folder>');
	}
	return path.join(dota, "scripts", "vscripts", "bots");
}

function main(args) {
	const dest = resolveDest(args);
	assertDestSafe(dest, worktreeRoots());
	const manifest = fileManifest();
	const verb = args.dryRun ? "would " : "";

	if (args.remove) {
		const result = removeExport(dest, manifest, args.force, args.dryRun);
		console.log(`export-bots: ${verb}remove ${result.remove.length} files from ${dest}`);
		if (result.kept.length > 0) {
			console.log(`  kept ${result.kept.length} files this tool did not write (the folder stays): ` +
				result.kept.slice(0, 10).join(", "));
		}
		return;
	}

	const ref = args.ref || (args.testGame ? "HEAD" : "origin/main");
	const { commit, files, leftOut } = collect(ref);
	const short = commit.slice(0, 7);
	const date = gitText(["log", "-1", "--format=%cd", "--date=format:%Y.%m.%d", commit]);
	const notes = [];
	if (args.testGame) {
		const lineup = path.join(ROOT, LINEUP_FILE);
		if (fs.existsSync(lineup)) files.set(LINEUP_FILE, fs.readFileSync(lineup));
		const branch = ref === "HEAD" ? gitText(["rev-parse", "--abbrev-ref", "HEAD"]) : ref;
		const { render } = require("./build-info.js");
		files.set(BUILD_INFO_FILE, Buffer.from(render({ commit: short, branch, dirty: false, date }), "utf8"));
		notes.push(`lineup: working-tree ${LINEUP_FILE}; ${BUILD_INFO_FILE}: version=${date}-${short} branch=${branch}`);
		if (ref === "HEAD") {
			const changed = uncommittedChanges();
			if (changed.length > 0) {
				notes.push(`NOT in the copy (uncommitted, commit them first if the game should run them): ${changed.join(", ")}`);
			}
		}
	}
	const missing = missingRequires(files);
	if (missing.length > 0) {
		throw new Error(
			"required files missing from the copy:\n" +
				missing.map((m) => `  ${m.file} -> ${m.target}`).join("\n") +
				"\n(a runtime file outside root/BotsLib/FuncLib/Customize? add its folder to RUNTIME_DIRS)"
		);
	}
	const steps = plan(dest, files, manifest.get(dest), args.force);
	if (path.basename(dest) !== "bots") notes.push(`the game only loads a folder named "bots" (this is ${path.basename(dest)})`);

	console.log(`export-bots: ${ref} ${short} (${date}) -> ${dest}`);
	console.log(
		`  ${files.size} files, ${megabytes(files)}: ${verb}write ${steps.write.length}, ` +
			`unchanged ${steps.unchanged.size}, ${verb}delete ${steps.remove.length}`
	);
	if (steps.remove.length > 0) console.log(`  ${verb}delete: ${steps.remove.slice(0, 10).join(", ")}${steps.remove.length > 10 ? ", ..." : ""}`);
	const skipped = Object.entries(leftOut)
		.sort((a, b) => b[1] - a[1])
		.map(([top, n]) => `${top} ${n}`)
		.join(", ");
	console.log(`  left out (not bot scripts): ${skipped}`);
	for (const note of notes) console.log(`  ${note}`);
	if (!args.dryRun) {
		apply(dest, files, steps, manifest, { ref, commit, at: new Date().toISOString(), testGame: args.testGame });
	}
}

// ---------------------------------------------------------------- self-test

function selfTest() {
	let failed = 0;
	const check = (name, ok) => {
		if (!ok) failed++;
		console.log(`${ok ? "ok  " : "FAIL"} ${name}`);
	};
	const throws = (fn, pattern) => {
		try {
			fn();
			return false;
		} catch (err) {
			return pattern.test(String(err.message));
		}
	};

	const inCopy = ["hero_selection.lua", "BotsLib/hero_axe.lua", "FuncLib/systems/push.lua", "Customize/general.lua"];
	const notInCopy = ["FuncLib/README.md", "Tests/run.lua", "Util/x.lua", "Docs/a.lua", ".luacheckrc", "README.md",
		"Install-to-vscript/quick-install-oha.bat", ".env.example", ".github/workflows/lua-check.yml"];
	check("selection: runtime .lua files are in", inCopy.every(isBotScript));
	check("selection: tests, tools, docs, configs are out", notInCopy.every((file) => !isBotScript(file)));

	const sources = new Map([
		["a.lua", Buffer.from([
			'local X = require(GetScriptDirectory() .. "/FuncLib/x")',
			'local ok = pcall(require, GetScriptDirectory() .. "/Customize/build_info")',
			'local H = dofile(GetScriptDirectory() .. "/BotsLib/" .. name)',
			'local C = require("bots.Customize.general")',
		].join("\n"))],
		["FuncLib/x.lua", Buffer.from("return {}")],
	]);
	const missing = missingRequires(sources);
	check("requires: a missing dotted target is found, dynamic and optional ones are skipped",
		missing.length === 1 && missing[0].target === "Customize/general");
	sources.set("Customize/general.lua", Buffer.from("return {}"));
	check("requires: nothing missing once the file is there", missingRequires(sources).length === 0);

	const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "oha-export-test-"));
	try {
		const target = path.join(tmp, "target");
		fs.mkdirSync(target);
		const link = path.join(tmp, "link");
		fs.symlinkSync(target, link, "junction");
		check("folder: a link / junction is refused", throws(() => assertDestSafe(link, [ROOT]), /is a link/));
		check("folder: inside the repo is refused", throws(() => assertDestSafe(path.join(ROOT, "bots"), [ROOT]), /inside the git worktree/));
		check("folder: a folder around the repo is refused", throws(() => assertDestSafe(path.dirname(ROOT), [ROOT]), /contains the git worktree/));
		const withGit = path.join(tmp, "withgit");
		fs.mkdirSync(path.join(withGit, ".git"), { recursive: true });
		check("folder: a folder with .git is refused", throws(() => assertDestSafe(withGit, [ROOT]), /contains \.git/));
		check("folder: a folder below a linked parent is allowed", !throws(() => assertDestSafe(path.join(link, "bots"), [ROOT]), /./));

		const store = {};
		const manifest = { get: (d) => store[d], set: (d, e) => (store[d] = e), del: (d) => delete store[d] };
		const dest = path.join(tmp, "bots");
		const exportFiles = (files, force = false) => {
			const steps = plan(dest, files, manifest.get(dest), force);
			apply(dest, files, steps, manifest, {});
			return steps;
		};
		const first = new Map([["a.lua", Buffer.from("1")], ["BotsLib/b.lua", Buffer.from("2")]]);
		const s1 = exportFiles(first);
		check("export: first copy writes every file", s1.write.length === 2 && listFiles(dest).join() === "BotsLib/b.lua,a.lua");
		const s2 = exportFiles(first);
		check("export: same copy again changes nothing", s2.write.length === 0 && s2.unchanged.size === 2);
		fs.writeFileSync(path.join(dest, "notes.txt"), "mine");
		check("export: a file the tool did not write blocks the copy", throws(() => exportFiles(first), /did not write: notes\.txt/));
		fs.unlinkSync(path.join(dest, "notes.txt"));
		const second = new Map([["a.lua", Buffer.from("changed")], ["FuncLib/c.lua", Buffer.from("3")]]);
		const s3 = exportFiles(second);
		check("export: stale files are deleted and empty folders pruned",
			s3.remove.join() === "BotsLib/b.lua" && !fs.existsSync(path.join(dest, "BotsLib")) &&
			listFiles(dest).join() === "FuncLib/c.lua,a.lua");
		fs.writeFileSync(path.join(dest, "notes.txt"), "mine");
		exportFiles(second, true);
		check("export: --force takes over the folder", !fs.existsSync(path.join(dest, "notes.txt")));
		fs.writeFileSync(path.join(dest, "keep.txt"), "mine");
		const kept = removeExport(dest, manifest, false, false);
		check("remove: deletes what the tool wrote, keeps the rest", kept.kept.join() === "keep.txt" &&
			listFiles(dest).join() === "keep.txt");
		fs.unlinkSync(path.join(dest, "keep.txt"));
		exportFiles(second);
		removeExport(dest, manifest, false, false);
		check("remove: an emptied folder is deleted", !fs.existsSync(dest) && manifest.get(dest) === undefined);
		check("remove: the link target was never touched", fs.readdirSync(target).length === 0);
	} finally {
		fs.rmSync(tmp, { recursive: true, force: true });
	}
	console.log(failed === 0 ? "self-test passed" : `self-test: ${failed} failed`);
	return failed === 0;
}

if (require.main === module) {
	try {
		const args = parseArgs(process.argv.slice(2));
		if (args.help) usage();
		else if (args.selfTest) process.exit(selfTest() ? 0 : 1);
		else main(args);
	} catch (err) {
		console.error(`export-bots: ${err.message}`);
		process.exit(1);
	}
}

module.exports = { isBotScript, missingRequires, assertDestSafe, plan, apply, removeExport };
