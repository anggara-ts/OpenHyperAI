// One hero and position: the whole buy list from the data, checked by the simulation.
//   start kit   the 600 gold the data spends before the horn
//   boots       the pair most players buy, at the minute they buy it
//   items       picked by pick rate, ordered by the median minute of the first purchase
//   reduce      the list is walked (lib/sim.js); an item that does not fit six slots, or that the hero's average
//               net worth cannot pay near the minute players buy it, means two builds got mixed: the least picked
//               item up to that point goes, until the list fits
//   top-up      free slots at the end are filled from less picked data items, then from the old list's tail
"use strict";
const { NO_SLOT, BOOTS } = require("./sim");

const TUNING = {
	// Pick-rate floor by purchase minute: early items are cheap and many, so they need more matches behind them.
	earlyFloor: 0.3,
	earlyMinute: 12,
	lateFloor: 0.15,
	lateMinute: 25,
	// A list item may be bought this much later than players buy it before it counts as "does not fit".
	slackMinutes: 5,
	slackShare: 0.3,
	// Top-up: the least a data item needs to fill a free slot at the end of the list.
	topUpFloor: 0.08,
	topUpMatches: 50,
	// A part that players mostly turn into something else is not an item of its own.
	partShare: 0.65,
	// Two picked items that both build from the same finished item of this cost or more are two builds.
	sharedBaseCost: 1700,
	// Under this share of matches with any pair, the hero's players do not buy boots at all.
	bootsFloor: 0.1,
	startMin: 0.4,
	startFill: 0.15,
};
const START_GOLD = 600;
const MAIN_BOOTS = ["item_power_treads", "item_phase_boots", "item_arcane_boots", "item_tranquil_boots"];
const DOUBLE = new Set(["item_branches", "item_circlet", "item_mantle", "item_slippers", "item_gauntlets", "item_clarity", "item_flask", "item_enchanted_mango", "item_tango"]);
// Never a list entry of its own: wards, dust, smoke, scrolls and the like are bought by other code.
const NOT_AN_ENTRY = /^item_(ward_|smoke_of_deceit|dust|tpscroll|gem|rapier|tome_of_knowledge|recipe_|famango|great_famango|greater_famango|cheese|aegis|refresher_shard)/;
const START_ONLY = new Set(["item_tango", "item_flask", "item_clarity", "item_enchanted_mango", "item_faerie_fire", "item_blood_grenade", "item_branches"]);
const SINKS = ["item_aghanims_shard", "item_moon_shard", "item_ultimate_scepter_2", "item_travel_boots_2"];

function makeBuilder(game, sim) {
	const { items, bundle } = game;
	const cost = (name) => (items[name] ? items[name].cost : 0);
	const buyable = (name) => items[name] !== undefined && items[name].buy !== false;
	const floorAt = (minute) => {
		if (minute <= TUNING.earlyMinute) return TUNING.earlyFloor;
		if (minute >= TUNING.lateMinute) return TUNING.lateFloor;
		return TUNING.earlyFloor + ((TUNING.lateFloor - TUNING.earlyFloor) * (minute - TUNING.earlyMinute)) / (TUNING.lateMinute - TUNING.earlyMinute);
	};
	const parts = (name) => bundle[name] || [];
	const tree = (name) => sim.closure(name);

	// The 600 gold of starting items the data buys: every copy 40% of players buy, then filled from 15%.
	function dataKit(data) {
		const share = (name, copy) => ((data.start[name] || [])[copy - 1] || 0) / data.startTop;
		const names = Object.keys(data.start).filter((name) => buyable(name) && !/^item_(ward_|recipe_)/.test(name) && cost(name) > 0);
		const slots = [];
		for (const name of names) {
			slots.push([name, 1]);
			if (DOUBLE.has(name)) slots.push([name, 2]);
		}
		slots.sort((a, b) => share(b[0], b[1]) - share(a[0], a[1]));
		const kit = [];
		const have = {};
		let gold = START_GOLD;
		const add = (name) => {
			kit.push(name);
			gold -= cost(name);
			have[name] = (have[name] || 0) + 1;
		};
		for (const [name, copy] of slots) {
			if (share(name, copy) < TUNING.startMin) break;
			if ((have[name] || 0) === copy - 1 && cost(name) <= gold) add(name);
		}
		for (const [name, copy] of slots) {
			if (copy !== 1 || have[name] || share(name, 1) < TUNING.startFill || name === "item_magic_wand") continue;
			if (gold >= 150 && cost(name) <= gold) add(name);
		}
		return { kit, share };
	}
	function kitEntries(kit) {
		const counts = {};
		const order = [];
		for (const name of kit) {
			if (!counts[name]) order.push(name);
			counts[name] = (counts[name] || 0) + 1;
		}
		const entries = order.map((name) => (counts[name] >= 2 && DOUBLE.has(name) && name !== "item_tango" ? name.replace("item_", "item_double_") : name));
		const rank = (name) => (name === "item_tango" ? 0 : name === "item_blood_grenade" ? 1 : 2);
		return entries.sort((a, b) => rank(a) - rank(b));
	}
	// build({ hero, pos, data, old: [{name|variable}], variables, pin, waits, sellPairs, banned, canPair, explain })
	function build(input) {
		const { data, pos, pin, variables } = input;
		const notes = [];
		const log = input.explain ? (...args) => console.log("   ", ...args) : () => {};
		const forbid = new Set(pin.forbid || []);
		const oldNames = input.old.map((entry) => entry.name).filter(Boolean);
		const oldVariables = input.old.filter((entry) => entry.variable);
		const variableItems = new Set(oldVariables.flatMap((entry) => (variables[entry.variable] || []).filter(Boolean)));
		const stat = (name) => data.items[name];
		const list = [];
		const add = (entry) => {
			if (entry.name && list.some((other) => other.name === entry.name)) return null;
			list.push(entry);
			return entry;
		};

		// 1. Start kit.
		const head = pin.start || kitEntries(dataKit(data).kit);
		if (pin.start) notes.push("start kit pinned");
		head.forEach((name, index) => add({ name, minute: -10 + index * 0.01, role: "start", fixed: true }));
		(pin.next || []).forEach((name, index) => add({ name, minute: -5 + index * 0.01, role: "pinned", fixed: true }));
		const headTree = new Set(head.flatMap((name) => [...tree(name)]));

		// 2. Boots: the pair most players buy; plain Boots when Boots of Travel is what they are turned into; the old
		// list's pair when hardly anyone buys boots on the hero (a bot still has to walk).
		const rateOf = (row) => (row ? row.matches / Math.max(1, data.remaining(row.minute)) : 0);
		const mainBoots = Object.entries(data.boots)
			.filter(([name]) => MAIN_BOOTS.includes(name) && buyable(name))
			.sort((x, y) => y[1].matches - x[1].matches);
		const travel = data.boots.item_travel_boots;
		let boots = pin.boots || (mainBoots.length ? mainBoots[0][0] : null);
		if (!pin.boots && travel && mainBoots.length && travel.matches > mainBoots[0][1].matches && data.boots.item_boots) boots = "item_boots";
		if (!pin.boots && (!boots || rateOf(data.boots[boots]) < TUNING.bootsFloor)) {
			const before = oldNames.map((name) => game.alias[name] || name).find((name) => MAIN_BOOTS.includes(name) || name === "item_boots");
			const share = Math.round(rateOf(data.boots[boots]) * 100);
			if (before) notes.push(`boots kept from the old list (${before}): the data buys ${boots || "none"} in ${share}% of matches`);
			else notes.push(`no boots, as in the old list: the data buys ${boots || "none"} in ${share}% of matches`);
			boots = before || null;
		}
		if (boots) {
			const row = data.boots[boots] || { minute: 9 };
			add({ name: boots, minute: row.minute, role: "boots", fixed: true });
			const upgrades = { item_arcane_boots: "item_guardian_greaves", item_tranquil_boots: "item_boots_of_bearing" };
			for (const later of [upgrades[boots], "item_travel_boots"]) {
				const laterRow = later && data.boots[later];
				if (!laterRow || forbid.has(later) || !buyable(later)) continue;
				const rate = rateOf(laterRow);
				// One pair: the purchase script skips Boots of Travel once Guardian Greaves or Boots of Bearing is owned.
				if (later === "item_travel_boots" && list.some((other) => other.name === upgrades[boots])) continue;
				if (rate >= TUNING.lateFloor || (boots === "item_boots" && later === "item_travel_boots")) {
					add({ name: later, minute: Math.max(laterRow.minute, row.minute + 1), role: "item", rate, share: laterRow.matches / Math.max(1, data.matches) });
				}
			}
		}

		// 3. Candidates from the purchase data.
		const candidates = Object.values(data.items)
			.filter((item) => buyable(item.name) && !NOT_AN_ENTRY.test(item.name) && !BOOTS.has(item.name) && !START_ONLY.has(item.name))
			.filter((item) => !forbid.has(item.name) && !variableItems.has(item.name) && item.minute !== undefined);
		const isCandidate = new Set(candidates.map((item) => item.name));
		const upgradesOf = (name) => candidates.filter((item) => item.name !== name && parts(item.name).includes(name));
		const isPart = (name) => {
			const own = stat(name);
			if (!own) return false;
			// Boots count too: a Ring of Basilius that ends up in Arcane Boots is a part.
			const intoBoots = Object.entries(data.boots).filter(([boots]) => parts(boots).includes(name)).reduce((sum, [, row]) => sum + row.matches, 0);
			const turned = intoBoots + upgradesOf(name).reduce((sum, item) => sum + item.matches, 0);
			return turned >= TUNING.partShare * own.matches;
		};
		const noUseRule = (name) => items[name] && items[name].active && !game.usage.has(name) && !input.heroUses.has(name);
		const gaps = [];
		const picked = [];
		for (const item of candidates.slice().sort((a, b) => b.rate - a.rate)) {
			if (item.rate < floorAt(item.minute)) continue;
			if (isPart(item.name) || headTree.has(item.name)) continue;
			if (noUseRule(item.name) && item.name !== "item_radiance") {
				gaps.push(`${item.name} (${Math.round(item.rate * 100)}%) has an active and no use rule: left out`);
				continue;
			}
			picked.push(item);
		}
		// Forced: pins, and an item the hero's farm rule waits for without a cap.
		const forced = new Map();
		for (const name of pin.require || []) forced.set(name, "pinned");
		for (const wait of input.waits || []) {
			// A wait with no net-worth cap never ends: the list buys the item. (The capped waits the old lists
			// bought are pins in pins.json.)
			if (wait.cap === null && buyable(wait.item) && !forbid.has(wait.item) && !variableItems.has(wait.item)) forced.set(wait.item, "farm rule waits for it");
		}
		const minuteFromOld = (name) => {
			const at = oldNames.indexOf(name);
			for (let i = at - 1; i >= 0; i--) if (stat(oldNames[i]) && !BOOTS.has(oldNames[i])) return stat(oldNames[i]).minute + 0.5;
			for (let i = at + 1; at >= 0 && i < oldNames.length; i++) if (stat(oldNames[i]) && !BOOTS.has(oldNames[i])) return stat(oldNames[i]).minute - 0.5;
			return 30;
		};
		// Two picks built from the same finished item are alternatives: the more picked one stays.
		const base = (name) =>
			[...tree(name)].filter((part) => {
				if (part === name || !buyable(part)) return false;
				if (part === "item_blink" || (cost(part) >= TUNING.sharedBaseCost && bundle[part])) return true;
				// A finished item players keep (Urn of Shadows): its upgrades are alternatives too.
				return bundle[part] !== undefined && stat(part) !== undefined && !isPart(part);
			});
		const clash = (name) => {
			const mine = base(name);
			return list.find((other) => other.name && other.role !== "start" && !tree(name).has(other.name) && !tree(other.name).has(name) && base(other.name).some((part) => mine.includes(part)));
		};
		for (const [name, why] of forced) {
			const own = stat(name);
			const there = list.find((other) => other.name === name);
			if (there) there.fixed = true;
			const entry = add({ name, minute: own ? own.minute : minuteFromOld(name), role: "item", fixed: true, why, rate: own ? own.rate : 0, share: own ? own.share : 0 });
			if (entry && (!own || own.rate < floorAt(own.minute))) notes.push(`${name} kept: ${why}${own ? ` (${Math.round(own.rate * 100)}% in the data)` : " (not in the data)"}`);
		}
		for (const item of picked) {
			if (forced.has(item.name)) continue;
			const other = clash(item.name);
			if (other) {
				log(`skip ${item.name}: shares a base with ${other.name}`);
				continue;
			}
			add({ name: item.name, minute: item.minute, role: "item", rate: item.rate, share: item.share });
		}
		// The random picks the old list names stay, where their items are bought in the data (or where they were).
		for (const entry of oldVariables) {
			const options = (variables[entry.variable] || []).filter(Boolean);
			const known = options.map(stat).filter(Boolean);
			const total = known.reduce((sum, item) => sum + item.matches, 0);
			let minute = total > 0 ? known.reduce((sum, item) => sum + item.minute * item.matches, 0) / total : null;
			if (minute === null) {
				const at = input.old.indexOf(entry);
				const before = input.old.slice(0, at).reverse().find((other) => other.name && stat(other.name) && !BOOTS.has(other.name));
				minute = before ? stat(before.name).minute + 0.5 : 30;
			}
			list.push({ variable: entry.variable, options: variables[entry.variable] || [], minute, role: "item", fixed: true, comment: entry.comment, lead: entry.lead });
		}

		const order = () => {
			list.sort((a, b) => a.minute - b.minute);
			// Pinned order: [a, b] = a before b; adjacent = b right after a.
			for (const [first, second] of pin.before || []) {
				const a = list.findIndex((entry) => entry.name === first);
				const b = list.findIndex((entry) => entry.name === second);
				if (a >= 0 && b >= 0 && a > b) list.splice(b, 0, list.splice(a, 1)[0]);
			}
			for (const [first, second] of pin.adjacent || []) {
				const b = list.findIndex((entry) => entry.name === second);
				if (b < 0) continue;
				const moved = list.splice(b, 1)[0];
				const a = list.findIndex((entry) => entry.name === first);
				list.splice(a + 1, 0, moved);
			}
			return list;
		};
		// Every way the random picks can fall.
		const concrete = () => {
			let lists = [[]];
			for (const entry of list) {
				if (!entry.variable) lists.forEach((names) => names.push(entry.name));
				else lists = lists.flatMap((names) => (entry.options.length ? entry.options : [null]).map((option) => (option ? [...names, option] : names.slice())));
			}
			return lists.slice(0, 40);
		};
		const pairs = () => [...input.sellPairs, ...newPairs];
		const newPairs = [];
		const keep = new Set([...forced.keys(), ...variableItems]);
		const walk = (room) => {
			const found = { violations: [], cumOf: {}, keepers: 0 };
			for (const names of concrete()) {
				const result = sim.simulate(names, { pos, sellPairs: pairs(), room: room && input.canPair, banned: input.banned, keep });
				for (const pair of result.newPairs) if (!newPairs.some((p) => p[0] === pair[0] && p[1] === pair[1])) newPairs.push(pair);
				found.violations.push(...result.violations);
				for (const step of result.steps) found.cumOf[step.entry] = Math.max(found.cumOf[step.entry] || 0, step.cum);
				found.keepers = Math.max(found.keepers, result.keepers.length);
			}
			return found;
		};
		const slack = (minute) => Math.max(TUNING.slackMinutes, TUNING.slackShare * minute);
		const indexOfName = (name) => list.findIndex((entry) => entry.name === name || (entry.variable && entry.options.includes(name)));
		const drop = (entry, why) => {
			list.splice(list.indexOf(entry), 1);
			log(`drop ${entry.name}: ${why}`);
			dropped.push(`${entry.name} (${Math.round((entry.rate || 0) * 100)}%): ${why}`);
		};
		const dropped = [];

		// 4. Reduce until the list fits.
		const unresolved = [];
		for (let round = 0; round < 80; round++) {
			order();
			newPairs.length = 0;
			const found = walk(true);
			let problem = null;
			for (const violation of found.violations) {
				const at = indexOfName(violation.entry);
				if (at >= 0 && (!problem || at < problem.at)) problem = { at, kind: violation.kind, detail: violation.detail, entry: violation.entry };
			}
			// Too late: the list reaches the item long after players have it.
			for (let at = 0; at < list.length; at++) {
				const entry = list[at];
				if (!entry.name || entry.role !== "item" || entry.topUp || !stat(entry.name) || found.cumOf[entry.name] === undefined) continue;
				const reached = data.minuteOfNetWorth(found.cumOf[entry.name]);
				entry.reached = reached;
				if (reached > entry.minute + slack(entry.minute) && (!problem || at < problem.at)) {
					problem = { at, kind: "late", entry: entry.name, detail: `the list reaches it at minute ${Math.round(reached)}, players buy it at ${entry.minute}` };
				}
			}
			if (!problem) break;
			if (problem.kind === "no-op") {
				const entry = list[problem.at];
				if (entry.name && !entry.fixed) {
					drop(entry, "already owned when its turn comes");
					continue;
				}
			}
			const removable = list.slice(0, problem.at + 1).filter((entry) => entry.role === "item" && !entry.fixed);
			if (removable.length === 0) {
				if (!unresolved.some((u) => u.entry === problem.entry && u.kind === problem.kind)) unresolved.push(problem);
				if (problem.kind === "late") {
					// Nothing left to take out before it: the forced or early items alone are dearer than the data's timing.
					const entry = list[problem.at];
					entry.minute = Math.max(entry.minute, entry.reached - slack(entry.minute) + 0.01);
					entry.late = true;
					continue;
				}
				break;
			}
			// The dear items are what makes a list late; a cheap early item only goes when nothing else can.
			const dear = removable.filter((entry) => cost(entry.name) >= 1500);
			const victim = (dear.length ? dear : removable).reduce((low, entry) => ((entry.rate || 0) < (low.rate || 0) ? entry : low));
			drop(victim, problem.kind === "late" ? `does not fit before ${problem.entry} (${problem.detail})` : `${problem.kind} at ${problem.entry}`);
		}

		// 5. Parts as their own step: a part players buy early, with another list item between it and its upgrade.
		for (const entry of list.slice()) {
			if (!entry.name || entry.role !== "item") continue;
			for (const part of tree(entry.name)) {
				const own = stat(part);
				if (part === entry.name || !own || !isCandidate.has(part) || !bundle[part] || list.some((other) => other.name === part)) continue;
				if (own.rate < floorAt(own.minute) || own.minute >= entry.minute) continue;
				const between = list.some((other) => other !== entry && other.role !== "start" && other.minute > own.minute && other.minute < entry.minute);
				if (!between) continue;
				// A step must not cost a slot the list does not have.
				const step = add({ name: part, minute: own.minute, role: "item", rate: own.rate, share: own.share, step: entry.name });
				order();
				newPairs.length = 0;
				if (step && walk(true).violations.some((violation) => violation.kind !== "no-op")) list.splice(list.indexOf(step), 1);
			}
		}
		order();
		// An item right before its own upgrade is the same purchase twice: only the upgrade stays.
		for (let at = list.length - 2; at >= 0; at--) {
			const entry = list[at];
			const next = list[at + 1];
			if (!entry.name || !next.name || entry.role !== "item" || entry.fixed || next.role !== "item") continue;
			if (tree(next.name).has(entry.name) && next.minute - entry.minute < 5) list.splice(at, 1);
		}

		// 6. Top-up: free slots at the end.
		const tryAppend = (entry) => {
			if (!entry.name || forbid.has(entry.name) || !buyable(entry.name) || list.some((other) => other.name === entry.name)) return false;
			if (variableItems.has(entry.name) || clash(entry.name)) return false;
			list.push(entry);
			newPairs.length = 0;
			const found = walk(true);
			const bad = found.violations.some((violation) => violation.kind !== "no-op" || violation.entry === entry.name);
			if (bad) list.pop();
			return !bad;
		};
		let lastMinute = Math.max(0, ...list.filter((entry) => entry.role !== "sink").map((entry) => entry.minute));
		const freeSlots = () => 6 - walk(true).keepers;
		const upgradesHeld = (name) => list.some((other) => other.name && other.name !== name && tree(name).has(other.name) && bundle[other.name] !== undefined);
		const extra = candidates
			.filter((item) => item.rate >= TUNING.topUpFloor && item.matches >= TUNING.topUpMatches && !isPart(item.name) && !headTree.has(item.name))
			.filter((item) => !noUseRule(item.name) && cost(item.name) >= 1500)
			.sort((a, b) => b.rate - a.rate);
		let toppedUp = 0;
		for (const item of extra) {
			if (toppedUp >= 6) break;
			if (list.some((other) => other.name === item.name) || dropped.some((text) => text.startsWith(item.name + " "))) continue;
			if (freeSlots() <= 0 && !list.some((other) => other.name && tree(item.name).has(other.name) && other.role === "item")) continue;
			lastMinute += 1;
			if (tryAppend({ name: item.name, minute: Math.max(item.minute, lastMinute), role: "item", topUp: "data", rate: item.rate, share: item.share })) {
				toppedUp++;
				lastMinute = Math.max(lastMinute, item.minute);
			}
		}
		order();
		lastMinute = Math.max(0, ...list.map((entry) => entry.minute));
		const tailKept = [];
		for (const name of oldNames) {
			if (SINKS.includes(name) || NO_SLOT.has(name) || BOOTS.has(name) || !buyable(name) || cost(name) < 1500) continue;
			if (list.some((other) => other.name === name) || dropped.some((text) => text.startsWith(name + " "))) continue;
			if ([...list].some((other) => other.name && tree(other.name).has(name))) continue;
			if (freeSlots() <= 0 && !upgradesHeld(name)) continue;
			lastMinute += 1;
			if (tryAppend({ name, minute: lastMinute, role: "item", topUp: "old list" })) tailKept.push(name);
		}
		// Gold sinks that take no slot stay where the old list had them: at the end.
		for (const name of SINKS) {
			if (forbid.has(name) || list.some((other) => other.name === name)) continue;
			const own = stat(name);
			const fromData = name === "item_aghanims_shard" && own && own.rate >= TUNING.lateFloor;
			if (!fromData && !oldNames.includes(name)) continue;
			if (dropped.some((text) => text.startsWith(name + " ")) && !oldNames.includes(name)) continue;
			// Boots of Travel 2 only upgrades a pair the data put in the list.
			if (name === "item_travel_boots_2" && !list.some((other) => other.name === "item_travel_boots")) continue;
			lastMinute += 1;
			const entry = { name, minute: lastMinute, role: "sink", rate: own ? own.rate : 0 };
			if (!tryAppend(entry)) log(`sink ${name} does not fit`);
		}
		order();
		if (tailKept.length) notes.push(`tail kept from the old list: ${tailKept.join(", ")}`);

		// 7. Final walk.
		newPairs.length = 0;
		const final = walk(true);
		const hard = final.violations.filter((violation) => violation.kind !== "no-op");
		const lateNotes = list.filter((entry) => entry.late).map((entry) => `${entry.name} is reached at minute ${Math.round(entry.reached)} (players: ${stat(entry.name).minute})`);
		return {
			ok: hard.length === 0 && unresolved.every((problem) => problem.kind === "late"),
			problems: [...hard.map((violation) => `${violation.kind} at ${violation.entry}: ${violation.detail}`), ...unresolved.filter((p) => p.kind !== "late").map((p) => `${p.kind} at ${p.entry}: ${p.detail}`)],
			entries: list.map((entry) => ({ ...entry })),
			newPairs: newPairs.slice(),
			keepers: final.keepers,
			notes: [...notes, ...lateNotes],
			dropped,
			gaps,
			cost: Math.max(0, ...Object.values(final.cumOf)),
		};
	}

	return { build, dataKit, kitEntries, TUNING };
}

module.exports = { makeBuilder, TUNING };
