// Walks a buy list the way item_purchase_generic.lua does: what each entry costs with the parts already held,
// what combines, what the sell rules take away, and whether the hero ever needs more than six main slots.
// Tests/test_item_build_sim.lua does the same walk in Lua on the lists the hero files return; keep the two alike.
"use strict";

// Used up or eaten on purchase: no slot.
const NO_SLOT = new Set([
	"item_tango",
	"item_clarity",
	"item_flask",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_tpscroll",
	"item_smoke_of_deceit",
	"item_dust",
	"item_ward_observer",
	"item_ward_sentry",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_tome_of_knowledge",
]);
const BOOTS = new Set([
	"item_boots",
	"item_power_treads",
	"item_phase_boots",
	"item_arcane_boots",
	"item_tranquil_boots",
	"item_travel_boots",
	"item_travel_boots_2",
	"item_guardian_greaves",
	"item_boots_of_bearing",
]);
// A held item this cheap is backpack filler, not one of the six.
const FILLER_COST = 600;
// The dearest item a generated sell pair may sell to make room.
const SELL_FOR_ROOM_COST = 2000;

function makeSim(game) {
	const { items, bundle, alias } = game;
	const cost = (name) => (items[name] ? items[name].cost : 0);
	const isRealItem = (name) => items[name] !== undefined && bundle[name] !== undefined && !/^item_double_/.test(name);
	const heldName = (name) => (/^item_power_treads_/.test(name) ? "item_power_treads" : name);

	// Every name in an entry's part tree (the entry included), owned or not.
	function closure(entry, out = new Set()) {
		if (out.has(entry)) return out;
		out.add(entry);
		for (const part of bundle[entry] || []) closure(part, out);
		return out;
	}

	function fixTravelBoots(list) {
		const out = [];
		let seen = false;
		for (const entry of list) {
			if (entry === "item_travel_boots") seen = true;
			else if (entry === "item_travel_boots_2" && !seen) {
				out.push("item_travel_boots");
				seen = true;
			}
			out.push(entry);
		}
		return out;
	}

	// list: item names. options: pos, sellPairs (the hero's own), room (true: sell pairs may be added to keep six
	// slots), banned (set of "trigger>victim" pairs that may not be added), keep (set of names never sold for room).
	function simulate(listIn, options = {}) {
		const list = fixTravelBoots(listIn);
		const pos = options.pos || 1;
		const heroPairs = options.sellPairs || [];
		const banned = options.banned || new Set();
		const keep = options.keep || new Set();
		const newPairs = [];
		const inv = [];
		const flags = { blessing: false, moon: false };
		const count = (name) => inv.filter((held) => held === name).length;
		const remove = (name) => {
			const at = inv.indexOf(name);
			if (at >= 0) inv.splice(at, 1);
			return at >= 0;
		};
		const owned = (name) => {
			if (alias[name]) return owned(alias[name]);
			if (/^item_double_/.test(name)) return count(name.replace("_double", "")) >= 2;
			if (/^PvN_/.test(name)) return flags.moon;
			if (name === "item_ultimate_scepter") return flags.blessing || count(name) > 0;
			if (name === "item_moon_shard") return flags.moon;
			if (name === "item_ultimate_scepter_2") return flags.blessing && count("item_ultimate_scepter") === 0;
			return count(name) > 0;
		};
		const neededLater = (name, from) => {
			for (let i = from; i < list.length; i++) if (closure(list[i]).has(name)) return list[i];
			return null;
		};
		const violations = [];
		const steps = [];
		let cum = 0;
		const fodder = (name) =>
			cost(name) <= FILLER_COST || game.earlyItems.has(name) || (pos >= 4 && game.supportSellWhenFull.has(name));

		for (let index = 0; index < list.length; index++) {
			const entry = list[index];
			if (owned(entry)) {
				steps.push({ entry, cost: 0, cum, held: inv.slice(), skipped: true });
				violations.push({ index, entry, kind: "no-op", detail: "already owned when its turn comes" });
				continue;
			}
			// One pair of boots: the script skips Boots of Travel while Guardian Greaves or Boots of Bearing is owned.
			if (/^item_travel_boots/.test(entry) && count("item_guardian_greaves") + count("item_boots_of_bearing") > 0) {
				steps.push({ entry, cost: 0, cum, held: inv.slice(), skipped: true });
				violations.push({ index, entry, kind: "no-op", detail: "skipped in game: Guardian Greaves or Boots of Bearing is owned" });
				continue;
			}
			// What the bot buys: Item.GetBasicItems, each owned copy covering one part.
			const ownedLeft = {};
			const basics = [];
			const expand = (name) => {
				if (ownedLeft[name] === undefined) ownedLeft[name] = owned(name) ? Math.max(1, count(name)) : 0;
				if (ownedLeft[name] > 0) {
					ownedLeft[name]--;
					return;
				}
				if (bundle[name]) bundle[name].forEach(expand);
				else basics.push(name);
			};
			expand(entry);
			let spent = 0;
			for (const basic of basics) {
				if (!items[basic] || items[basic].buy === false) {
					violations.push({ index, entry, kind: "unknown-item", detail: basic });
					continue;
				}
				spent += cost(basic);
				inv.push(basic);
			}
			cum += spent;
			// Combine, parts first: every real item in the entry's tree whose parts are all held.
			const targets = [...closure(entry)].filter(isRealItem);
			for (let pass = 0; pass < 8; pass++) {
				let combined = false;
				for (const target of targets) {
					const parts = bundle[target];
					const need = {};
					for (const part of parts) need[part] = (need[part] || 0) + 1;
					if (Object.keys(need).every((part) => count(part) >= need[part])) {
						parts.forEach(remove);
						inv.push(heldName(target));
						combined = true;
					}
				}
				if (!combined) break;
			}
			for (let i = inv.length - 1; i >= 0; i--) {
				if (!NO_SLOT.has(inv[i])) continue;
				if (inv[i] === "item_ultimate_scepter_2") flags.blessing = true;
				if (inv[i] === "item_moon_shard") flags.moon = true;
				inv.splice(i, 1);
			}
			// Sell rules.
			const sold = [];
			const sell = (victim, why) => {
				if (!remove(victim)) return false;
				sold.push(`${victim} (${why})`);
				const later = neededLater(victim, index + 1);
				if (later) violations.push({ index, entry, kind: "sold-then-needed", detail: `${victim} is sold (${why}) and ${later} needs it later` });
				return true;
			};
			const allPairs = () => [...game.globalSellPairs, ...heroPairs, ...newPairs, ["item_satanic", "item_mask_of_madness"]];
			const runPairs = () => {
				for (let pass = 0; pass < 4; pass++) {
					let any = false;
					for (const [trigger, victim] of allPairs()) {
						if (count(trigger) > 0 && count(victim) > 0 && trigger !== victim) any = sell(victim, `pair with ${trigger}`) || any;
					}
					if (!any) break;
				}
				if (count("item_travel_boots") + count("item_travel_boots_2") > 0) {
					for (const boots of game.earlyBoots) if (count(boots) > 0) sell(boots, "Boots of Travel owned");
				}
			};
			runPairs();
			// Six main slots: everything that is not backpack filler.
			const keepers = () => inv.filter((name) => !fodder(name));
			while (keepers().length > 6) {
				const trigger = heldName(alias[entry] && count(alias[entry]) > 0 ? alias[entry] : entry);
				const room = options.room && count(trigger) > 0 && !fodder(trigger);
				const victims = keepers()
					.filter((name) => name !== trigger && cost(name) <= SELL_FOR_ROOM_COST && !BOOTS.has(name) && !keep.has(name))
					.filter((name) => !neededLater(name, index + 1) && !banned.has(`${trigger}>${name}`))
					.sort((a, b) => cost(a) - cost(b));
				if (!room || victims.length === 0) {
					violations.push({ index, entry, kind: "slots", detail: `${keepers().length} items for six slots: ${keepers().join(", ")}` });
					break;
				}
				newPairs.push([trigger, victims[0]]);
				runPairs();
			}
			// The script's own full-inventory rule (nine slots with the backpack).
			while (inv.length >= 9) {
				const order = [...game.earlyItems, ...(pos >= 4 ? game.supportSellWhenFull : [])];
				const victim = order.find((name) => count(name) > 0) || inv.find((name) => cost(name) <= FILLER_COST);
				if (!victim) {
					violations.push({ index, entry, kind: "inventory-full", detail: inv.join(", ") });
					break;
				}
				sell(victim, "inventory full");
			}
			steps.push({ entry, cost: spent, cum, held: inv.slice(), sold });
		}
		return { ok: violations.length === 0, violations, steps, newPairs, final: inv.slice(), keepers: inv.filter((name) => !fodder(name)), cum };
	}

	return { simulate, closure, cost, fixTravelBoots };
}

module.exports = { makeSim, NO_SLOT, BOOTS };
