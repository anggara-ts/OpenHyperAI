// Stratz match data for the generator: the cache in Util/item-builds/cache/raw/ and the fetch that fills it.
//   <hero>_<pos>.json  { s: starting purchases, b: boots, f: every purchase per minute, st: (unused) }
//   <hero>_time.json   per minute and position: matches still running and the average net worth
//   _meta.json         { week, patch }: the week the files belong to; another --week is refused
// The token comes from STRATZ_TOKEN (the repo's .env) and is never printed.
"use strict";
const fs = require("fs");
const path = require("path");

const CACHE = path.join(__dirname, "..", "cache");
const RAW = path.join(CACHE, "raw");
const ROOT = path.join(__dirname, "..", "..", "..");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
// Item ids in the purchase rows that the constants do not name (a patch added items since the constants were fetched).
const unknownIds = new Set();

function meta() {
	const file = path.join(RAW, "_meta.json");
	return fs.existsSync(file) ? readJson(file) : null;
}

async function stratz(query) {
	try {
		process.loadEnvFile(path.join(ROOT, ".env"));
	} catch (e) {
		// no .env: the environment may still hold the token
	}
	const token = process.env.STRATZ_TOKEN || "";
	if (!token) throw new Error("STRATZ_TOKEN is not set: put it in the repo's .env (see .env.example)");
	for (let attempt = 0; attempt < 4; attempt++) {
		const response = await fetch("https://api.stratz.com/graphql", {
			method: "POST",
			headers: { "Content-Type": "application/json", Authorization: "Bearer " + token, "User-Agent": "STRATZ_API" },
			body: JSON.stringify({ query }),
		});
		if (response.status === 429) {
			await sleep(5000);
			continue;
		}
		if (!response.ok) throw new Error(`Stratz: HTTP ${response.status}`);
		const body = await response.json();
		if (body.errors && body.errors.length) throw new Error(`Stratz: ${body.errors[0].message}`);
		return body.data;
	}
	throw new Error("Stratz: rate limited");
}

async function constants(allowFetch) {
	const file = path.join(CACHE, "stratz_constants.json");
	// A new week (no _meta.json yet) may bring new item ids: the constants are fetched again with it.
	if (allowFetch && !meta()) fs.rmSync(file, { force: true });
	if (fs.existsSync(file)) return readJson(file);
	if (!allowFetch) throw new Error("no Stratz constants in the cache: run with --fetch");
	const data = await stratz("{ constants { heroes { id shortName displayName } items { id shortName components { componentId } } } }");
	fs.mkdirSync(CACHE, { recursive: true });
	fs.writeFileSync(file, JSON.stringify(data.constants));
	return data.constants;
}

// Fetch what the cache lacks for these heroes. week: "YYYY-MM-DD", a day inside the Stratz week.
async function fetchMissing(heroes, week, patch, log) {
	fs.mkdirSync(RAW, { recursive: true });
	const known = meta();
	if (known && known.week !== week) {
		throw new Error(`cache/raw holds the week of ${known.week}; move it away before fetching the week of ${week}`);
	}
	fs.writeFileSync(path.join(RAW, "_meta.json"), JSON.stringify({ week, patch }));
	const stamp = Math.floor(Date.parse(week + "T12:00:00Z") / 1000);
	let fetched = 0;
	for (const hero of heroes) {
		for (let pos = 1; pos <= 5; pos++) {
			const file = path.join(RAW, `${hero.shortName}_${pos}.json`);
			if (fs.existsSync(file)) continue;
			const args = `heroId: ${hero.id}, week: ${stamp}, positionIds: [POSITION_${pos}]`;
			const data = await stratz(
				`{ heroStats { s: itemStartingPurchase(${args}) { itemId matchCount winCount instance wasGiven } b: itemBootPurchase(${args}) { itemId matchCount instance time } f: itemFullPurchase(${args}, matchLimit: 0) { itemId matchCount winCount instance time } } }`,
			);
			fs.writeFileSync(file, JSON.stringify(data.heroStats));
			fetched++;
			await sleep(350);
		}
		const timeFile = path.join(RAW, `${hero.shortName}_time.json`);
		if (!fs.existsSync(timeFile)) {
			// Without groupByTime the same query returns one row: the matches still running at minute 35, not all of them.
			const data = await stratz(
				`{ heroStats { t: stats(heroIds: [${hero.id}], week: ${stamp}, groupByPosition: true, groupByTime: true, minTime: 0, maxTime: 75) { time position matchCount networth } } }`,
			);
			fs.writeFileSync(timeFile, JSON.stringify(data.heroStats.t));
			fetched++;
			await sleep(350);
		}
		if (log) log(hero.shortName);
	}
	return fetched;
}

// One hero and position, ready for the generator. null when there is no file.
function position(hero, pos, itemName) {
	const file = path.join(RAW, `${hero}_${pos}.json`);
	const timeFile = path.join(RAW, `${hero}_time.json`);
	if (!fs.existsSync(file) || !fs.existsSync(timeFile)) return null;
	const raw = readJson(file);
	const series = readJson(timeFile)
		.filter((row) => row.position === `POSITION_${pos}`)
		.sort((a, b) => a.time - b.time);
	const matches = series.length ? Number(series[0].matchCount) : 0;
	const at = (minute) => series[Math.max(0, Math.min(series.length - 1, Math.round(minute)))];
	const remaining = (minute) => (series.length ? Number(at(minute).matchCount) : 0);
	// The minute the average net worth reaches this much gold; past the data, the last ten minutes' rate goes on.
	const minuteOfNetWorth = (gold) => {
		for (const row of series) if (Number(row.networth) >= gold) return row.time;
		if (series.length < 12) return 999;
		const last = series[series.length - 1];
		const before = series[series.length - 11];
		const rate = Math.max(100, (Number(last.networth) - Number(before.networth)) / 10);
		return last.time + (gold - Number(last.networth)) / rate;
	};
	const items = {};
	for (const row of raw.f || []) {
		if (row.instance !== 0) continue;
		const name = itemName.get(row.itemId);
		if (!name) {
			unknownIds.add(row.itemId);
			continue;
		}
		const item = (items[name] = items[name] || { name, matches: 0, rows: [] });
		item.matches += row.matchCount;
		item.rows.push([row.time, row.matchCount]);
	}
	for (const item of Object.values(items)) {
		item.rows.sort((a, b) => a[0] - b[0]);
		let seen = 0;
		for (const [minute, count] of item.rows) {
			seen += count;
			if (seen >= item.matches / 2) {
				item.minute = minute;
				break;
			}
		}
		item.share = matches > 0 ? item.matches / matches : 0;
		// Of the matches that were still running at the item's usual minute: late items are not punished for short games.
		item.rate = Math.min(1, item.matches / Math.max(1, remaining(item.minute)));
		delete item.rows;
	}
	// Starting purchases: copies[k] = matches that bought a (k+1)th copy; share is against the most bought item.
	const start = {};
	for (const row of raw.s || []) {
		const name = itemName.get(row.itemId);
		if (!name) continue;
		const copies = (start[name] = start[name] || []);
		copies[row.instance] = (copies[row.instance] || 0) + row.matchCount;
	}
	const startTop = Math.max(1, ...Object.values(start).map((copies) => copies[0] || 0));
	const boots = {};
	for (const row of raw.b || []) {
		if (row.instance !== 0) continue;
		const name = itemName.get(row.itemId);
		if (name) boots[name] = { matches: row.matchCount, minute: row.matchCount > 0 ? row.time / row.matchCount / 60 : 0 };
	}
	return { hero, pos, matches, remaining, minuteOfNetWorth, items, start, startTop, boots };
}

module.exports = { RAW, meta, constants, fetchMissing, position, unknownIds };
