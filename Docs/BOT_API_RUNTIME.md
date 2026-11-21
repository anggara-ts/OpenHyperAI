# Dota bot API: what the game really exposes

Runtime dump from the game itself, not from the online docs. Taken on 2026-11-16 (game 033, bot build 2026.11.16-082) by the `[OHA-API]` dump in `ability_item_usage_generic.lua` (`a.DumpBotApi`), which runs once per game from Radiant's first bot. To refresh it, start any game and grep the console log for `[OHA-API]`.

The online references ([Valve Developer Wiki](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting), [ModDota](https://docs.moddota.com/lua_bots/)) carry no date and describe an older API. Where they disagree with this file, this file wins.

The list of known limitations (what bots can't do, why, and the workaround) is kept in the main post of
[discussion #50](https://github.com/anggara-ts/Supercharged-OpenHyperAI/discussions/50); update it when a limitation is
confirmed or disproved.

## Key findings

- **No vector-target order.** Abilities can only be cast with no target, on a unit, on a location or on a tree (plus the Push/Queue variants). A vector-targeted spell such as Muerta's Dead Shot cannot have its direction chosen.
- `GetCurrentCharges`, `GetInitialCharges` and `GetSecondaryCharges` exist on abilities as well as items. On the Ward Dispenser the first is observers and the second sentries (game 032). Whether they return charges for charge-based abilities (Mirana's Leap, Techies' mines, ...) has not been tested; `FuncLib/systems/charge_tracker.lua` still tracks those itself.
- `GetToggleState`, `IsInAbilityPhase`, `GetDamageType`, `GetTargetType/Team/Flags` are available on abilities.
- Item management beyond buy/sell: `ActionImmediate_DisassembleItem`, `ActionImmediate_SetItemCombineLock`, `ActionImmediate_SwapItems`.
- Shrines and runes have their own orders: `Action_UseShrine`, `Action_PickUpRune` (plus Push/Queue). `GetOutpost`, `GetShrine`, `GetShrineCooldown`, `IsShrineHealing`, `GetNearbyShrines` are available.
- **A mode file replaces Valve's mode whole, even without `Think`.** Game 063 (#141): a `mode_item_generic.lua` that defined only `GetDesire` won the item mode 3.5-5.3s at a time on the river bounties and water runes, and nothing was picked up (`[OHA-ITEMMODE] result ... picked=no`); Valve's item `Think` did not run behind it. The file was removed.
- **Tested in 7.42 games (063-064):**
  - `Action_ClearActions(true)` stops an attack wind-up: 70 of 70 stops held (`[OHA-LH] cancel-result stopped=yes method=clear`, #157).
  - The time left on an enemy hero's `modifier_teleporting` counts down with the clock (`[OHA-ALCHEMIST] tp-left ... real=yes`, 4 of 4, #122/#166), so it is the real remaining TP time.
  - `Action_PickUpRune` on a river rune spot: a water rune (type 7) was taken (`river-pickup-try worked=yes type=7`, 1 sample); the river bounty (type 5) was not, 0 of 4 (games 063-064). Valve's own item mode takes both (#149).
  - A mode file that defines only `GetDesire` still replaces that Valve mode entirely: Valve's `Think` does not run behind it (the item-mode trial, #141, game 063).
  - No hidden item or extra ability gives outpost capture or watcher use: every bot's slots 17-25 are empty and there is no `capture` / `lamp` / `watcher` ability beyond the normal slots (`[OHA-API] slots`, #172, game 064).
  - Unconfirmed: `IsAlive()` on an enemy hero handle may read false after it TPs out, turns invisible or leaves vision (seen 5 times in game 064's hunt trace).

## 7.42 check (2026-11-19)

Dump taken in the first 7.42 game (game 049, build 2026.11.19-ea05353), which prints every numeric UPPER_CASE global
since #110. Issue #109.

- **No function changes.** 167 global functions, 220 unit / bot methods and 50 ability methods: the same names as the
  pre-7.42 dump (game 048).
- **363 constants.** The fallback values in `FuncLib/dota/enums.lua` (`ENGINE_NAME or fallback`) differ from the
  engine in 73 places (desire steps, `GAME_STATE_*`, `HEROPICK_STATE_*`); they are never used, because the engine
  defines those names. Values marked * below are our own: `FuncLib/systems/global_overrides.lua` sets the
  `BOT_MODE_DESIRE_*` steps (0.7 scale) and `BOT_DESIRE_OVERRIDE` before the dump runs.
- **Names that do not exist** (they read as nil, so a comparison with them never matches): `BOT_ACTION_TYPE_ATTACK_MOVE`
  (the engine has `BOT_ACTION_TYPE_ATTACKMOVE`), `DOTA_GAMERULES_STATE_POST_GAME` (`GAME_STATE_POST_GAME`),
  `BOT_MODE_GANK`, `ITEM_TARGET_TYPE_NONE`. Fixed in #112.
- **Items.** `GetItemCost` and `GetItemComponents` know the 7.42 items (Bloodslinger, Caduceus, Ristul's Devotion,
  Berserker's Sabatons, Skypiercer, Starforge, Greater Horn of Battle) and the changed recipes. The removed Helm of
  the Overlord and Khanda (`item_angels_demise`) still answer with a cost; the game files mark them obsolete and not
  purchasable. Neutral items, Aegis and the observer ward have no cost (0).
- **Abilities.** `[OHA-API] abilities <hero>` lists each bot's slots 0-35 as the engine has them, (t) talent,
  (h) hidden. Souvenirs and similar granted abilities (Ringmaster's Weighted Pie, Crystal Ball) are not in the slots
  at the start of the game.

### Constants by group (game-mode, hero-pick and animation activity constants left out)

- **ABILITY_BEHAVIOR**: `ABILITY_BEHAVIOR_AOE`=32, `ABILITY_BEHAVIOR_ATTACK`=131072, `ABILITY_BEHAVIOR_AURA`=65536, `ABILITY_BEHAVIOR_AUTOCAST`=4096, `ABILITY_BEHAVIOR_CHANNELLED`=128, `ABILITY_BEHAVIOR_DIRECTIONAL`=1024, `ABILITY_BEHAVIOR_DONT_ALERT_TARGET`=16777216, `ABILITY_BEHAVIOR_DONT_CANCEL_CHANNEL`=536870912, `ABILITY_BEHAVIOR_DONT_CANCEL_MOVEMENT`=8388608, `ABILITY_BEHAVIOR_DONT_RESUME_ATTACK`=33554432, `ABILITY_BEHAVIOR_DONT_RESUME_MOVEMENT`=262144, `ABILITY_BEHAVIOR_HIDDEN`=1, `ABILITY_BEHAVIOR_IGNORE_BACKSWING`=134217728, `ABILITY_BEHAVIOR_IGNORE_CHANNEL`=4194304, `ABILITY_BEHAVIOR_IGNORE_PSEUDO_QUEUE`=2097152, `ABILITY_BEHAVIOR_IMMEDIATE`=2048, `ABILITY_BEHAVIOR_ITEM`=256, `ABILITY_BEHAVIOR_LAST_RESORT_POINT`=-2147483648, `ABILITY_BEHAVIOR_NONE`=0, `ABILITY_BEHAVIOR_NORMAL_WHEN_STOLEN`=67108864, `ABILITY_BEHAVIOR_NOT_LEARNABLE`=64, `ABILITY_BEHAVIOR_NO_TARGET`=4, `ABILITY_BEHAVIOR_OPTIONAL_NO_TARGET`=32768, `ABILITY_BEHAVIOR_OPTIONAL_POINT`=16384, `ABILITY_BEHAVIOR_OPTIONAL_UNIT_TARGET`=8192, `ABILITY_BEHAVIOR_PASSIVE`=2, `ABILITY_BEHAVIOR_POINT`=16, `ABILITY_BEHAVIOR_ROOT_DISABLES`=524288, `ABILITY_BEHAVIOR_RUNE_TARGET`=268435456, `ABILITY_BEHAVIOR_TOGGLE`=512, `ABILITY_BEHAVIOR_UNIT_TARGET`=8, `ABILITY_BEHAVIOR_UNRESTRICTED`=1048576, `ABILITY_BEHAVIOR_VECTOR_TARGETING`=1073741824
- **ABILITY_TARGET_FLAG**: `ABILITY_TARGET_FLAG_CHECK_DISABLE_HELP`=65536, `ABILITY_TARGET_FLAG_DEAD`=8, `ABILITY_TARGET_FLAG_FOW_VISIBLE`=128, `ABILITY_TARGET_FLAG_INVULNERABLE`=64, `ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES`=16, `ABILITY_TARGET_FLAG_MANA_ONLY`=32768, `ABILITY_TARGET_FLAG_MELEE_ONLY`=4, `ABILITY_TARGET_FLAG_NONE`=0, `ABILITY_TARGET_FLAG_NOT_ANCIENTS`=512, `ABILITY_TARGET_FLAG_NOT_ATTACK_IMMUNE`=16384, `ABILITY_TARGET_FLAG_NOT_CREEP_HERO`=131072, `ABILITY_TARGET_FLAG_NOT_DOMINATED`=2048, `ABILITY_TARGET_FLAG_NOT_ILLUSIONS`=8192, `ABILITY_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES`=32, `ABILITY_TARGET_FLAG_NOT_NIGHTMARED`=524288, `ABILITY_TARGET_FLAG_NOT_SUMMONED`=4096, `ABILITY_TARGET_FLAG_NO_INVIS`=256, `ABILITY_TARGET_FLAG_OUT_OF_WORLD`=262144, `ABILITY_TARGET_FLAG_PLAYER_CONTROLLED`=1024, `ABILITY_TARGET_FLAG_PREFER_ENEMIES`=1048576, `ABILITY_TARGET_FLAG_RANGED_ONLY`=2
- **ABILITY_TARGET_TEAM**: `ABILITY_TARGET_TEAM_BOTH`=3, `ABILITY_TARGET_TEAM_ENEMY`=2, `ABILITY_TARGET_TEAM_FRIENDLY`=1, `ABILITY_TARGET_TEAM_NONE`=0
- **ABILITY_TARGET_TYPE**: `ABILITY_TARGET_TYPE_ALL`=55, `ABILITY_TARGET_TYPE_BASIC`=18, `ABILITY_TARGET_TYPE_BUILDING`=4, `ABILITY_TARGET_TYPE_COURIER`=16, `ABILITY_TARGET_TYPE_CREEP`=2, `ABILITY_TARGET_TYPE_HERO`=1, `ABILITY_TARGET_TYPE_NONE`=0, `ABILITY_TARGET_TYPE_OTHER`=32, `ABILITY_TARGET_TYPE_TREE`=64
- **ATTRIBUTE**: `ATTRIBUTE_AGILITY`=1, `ATTRIBUTE_INTELLECT`=2, `ATTRIBUTE_INVALID`=-1, `ATTRIBUTE_STRENGTH`=0
- **BARRACKS**: `BARRACKS_BOT_MELEE`=4, `BARRACKS_BOT_RANGED`=5, `BARRACKS_MID_MELEE`=2, `BARRACKS_MID_RANGED`=3, `BARRACKS_TOP_MELEE`=0, `BARRACKS_TOP_RANGED`=1
- **BOT_ACTION_DESIRE**: `BOT_ACTION_DESIRE_ABSOLUTE`=1, `BOT_ACTION_DESIRE_HIGH`=0.75, `BOT_ACTION_DESIRE_LOW`=0.25, `BOT_ACTION_DESIRE_MODERATE`=0.5, `BOT_ACTION_DESIRE_NONE`=0, `BOT_ACTION_DESIRE_VERYHIGH`=0.9, `BOT_ACTION_DESIRE_VERYLOW`=0.1
- **BOT_ACTION_TYPE**: `BOT_ACTION_TYPE_ATTACK`=4, `BOT_ACTION_TYPE_ATTACKMOVE`=5, `BOT_ACTION_TYPE_DELAY`=11, `BOT_ACTION_TYPE_DROP_ITEM`=9, `BOT_ACTION_TYPE_IDLE`=1, `BOT_ACTION_TYPE_MOVE_TO`=2, `BOT_ACTION_TYPE_MOVE_TO_DIRECTLY`=3, `BOT_ACTION_TYPE_NONE`=0, `BOT_ACTION_TYPE_PICK_UP_ITEM`=8, `BOT_ACTION_TYPE_PICK_UP_RUNE`=7, `BOT_ACTION_TYPE_SHRINE`=10, `BOT_ACTION_TYPE_USE_ABILITY`=6
- **BOT_MODE**: `BOT_MODE_ASSEMBLE`=14, `BOT_MODE_ASSEMBLE_WITH_HUMANS`=15, `BOT_MODE_ATTACK`=2, `BOT_MODE_DEFEND_ALLY`=18, `BOT_MODE_DEFEND_TOWER_BOT`=13, `BOT_MODE_DEFEND_TOWER_MID`=12, `BOT_MODE_DEFEND_TOWER_TOP`=11, `BOT_MODE_EVASIVE_MANEUVERS`=19, `BOT_MODE_FARM`=17, `BOT_MODE_ITEM`=21, `BOT_MODE_LANING`=1, `BOT_MODE_LOTUS_POOL`=30, `BOT_MODE_NONE`=0, `BOT_MODE_OUTPOST`=26, `BOT_MODE_PUSH_TOWER_BOT`=10, `BOT_MODE_PUSH_TOWER_MID`=9, `BOT_MODE_PUSH_TOWER_TOP`=8, `BOT_MODE_RETREAT`=4, `BOT_MODE_ROAM`=3, `BOT_MODE_ROSHAN`=20, `BOT_MODE_RUNE`=7, `BOT_MODE_SECRET_SHOP`=5, `BOT_MODE_SIDE_SHOP`=6, `BOT_MODE_TEAM_ROAM`=16, `BOT_MODE_WARD`=22, `BOT_MODE_WATCHER`=28, `BOT_MODE_WISDOM_SHRINE`=29
- **BOT_MODE_DESIRE**: `BOT_MODE_DESIRE_ABSOLUTE`=0.7*, `BOT_MODE_DESIRE_HIGH`=0.525*, `BOT_MODE_DESIRE_LOW`=0.175*, `BOT_MODE_DESIRE_MODERATE`=0.35*, `BOT_MODE_DESIRE_NONE`=0*, `BOT_MODE_DESIRE_VERYHIGH`=0.6*, `BOT_MODE_DESIRE_VERYLOW`=0.05*
- **COURIER_ACTION**: `COURIER_ACTION_BURST`=5, `COURIER_ACTION_ENEMY_SECRET_SHOP`=7, `COURIER_ACTION_RETURN`=0, `COURIER_ACTION_RETURN_STASH_ITEMS`=2, `COURIER_ACTION_SECRET_SHOP`=1, `COURIER_ACTION_SIDE_SHOP2`=9, `COURIER_ACTION_SIDE_SHOP`=8, `COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS`=6, `COURIER_ACTION_TAKE_STASH_ITEMS`=3, `COURIER_ACTION_TRANSFER_ITEMS`=4
- **COURIER_STATE**: `COURIER_STATE_AT_BASE`=1, `COURIER_STATE_AT_SECRET_SHOP`=7, `COURIER_STATE_DEAD`=5, `COURIER_STATE_DELIVERING_ITEMS`=3, `COURIER_STATE_GOING_TO_SECRET_SHOP`=6, `COURIER_STATE_IDLE`=0, `COURIER_STATE_MOVING`=2, `COURIER_STATE_RETURNING_TO_BASE`=4
- **DAMAGE_TYPE**: `DAMAGE_TYPE_ALL`=7, `DAMAGE_TYPE_MAGICAL`=2, `DAMAGE_TYPE_PHYSICAL`=1, `DAMAGE_TYPE_PURE`=4
- **DIFFICULTY**: `DIFFICULTY_EASY`=1, `DIFFICULTY_HARD`=3, `DIFFICULTY_INVALID`=5, `DIFFICULTY_MEDIUM`=2, `DIFFICULTY_NPX`=9, `DIFFICULTY_PASSIVE`=0, `DIFFICULTY_UNFAIR`=4
- **GAME_STATE**: `GAME_STATE_CUSTOM_GAME_SETUP`=9, `GAME_STATE_DISCONNECT`=7, `GAME_STATE_GAME_IN_PROGRESS`=5, `GAME_STATE_HERO_SELECTION`=2, `GAME_STATE_INIT`=0, `GAME_STATE_LAST`=13, `GAME_STATE_PLAYER_DRAFT`=12, `GAME_STATE_POST_GAME`=6, `GAME_STATE_PRE_GAME`=4, `GAME_STATE_STRATEGY_TIME`=3, `GAME_STATE_TEAM_SHOWCASE`=8, `GAME_STATE_WAIT_FOR_MAP_TO_LOAD`=10, `GAME_STATE_WAIT_FOR_PLAYERS_TO_LOAD`=1
- **ITEM_SLOT_TYPE**: `ITEM_SLOT_TYPE_BACKPACK`=1, `ITEM_SLOT_TYPE_INVALID`=-1, `ITEM_SLOT_TYPE_MAIN`=0, `ITEM_SLOT_TYPE_STASH`=2
- **LANE**: `LANE_BOT`=3, `LANE_MID`=2, `LANE_NONE`=0, `LANE_TOP`=1
- **PURCHASE_ITEM**: `PURCHASE_ITEM_DISALLOWED_ITEM`=78, `PURCHASE_ITEM_INSUFFICIENT_GOLD`=63, `PURCHASE_ITEM_INVALID_ITEM_NAME`=33, `PURCHASE_ITEM_NOT_AT_HOME_SHOP`=67, `PURCHASE_ITEM_NOT_AT_SECRET_SHOP`=62, `PURCHASE_ITEM_NOT_AT_SIDE_SHOP`=66, `PURCHASE_ITEM_OUT_OF_STOCK`=82, `PURCHASE_ITEM_SUCCESS`=-1
- **RUNE**: `RUNE_ARCANE`=6, `RUNE_BOUNTY`=5, `RUNE_BOUNTY_1`=2, `RUNE_BOUNTY_2`=3, `RUNE_BOUNTY_3`=4, `RUNE_BOUNTY_4`=5, `RUNE_DOUBLEDAMAGE`=0, `RUNE_HASTE`=1, `RUNE_ILLUSION`=2, `RUNE_INVALID`=-1, `RUNE_INVISIBILITY`=3, `RUNE_POWERUP_1`=0, `RUNE_POWERUP_2`=1, `RUNE_REGENERATION`=4, `RUNE_SHIELD`=9, `RUNE_WATER`=7, `RUNE_XP`=8
- **RUNE_STATUS**: `RUNE_STATUS_AVAILABLE`=1, `RUNE_STATUS_MISSING`=2, `RUNE_STATUS_UNKNOWN`=0
- **SHOP**: `SHOP_HOME`=0, `SHOP_SECRET2`=5, `SHOP_SECRET`=2, `SHOP_SIDE2`=4, `SHOP_SIDE`=1
- **TEAM**: `TEAM_DIRE`=3, `TEAM_NEUTRAL`=4, `TEAM_NONE`=5, `TEAM_RADIANT`=2
- **TOWER**: `TOWER_BASE_1`=9, `TOWER_BASE_2`=10, `TOWER_BOT_1`=6, `TOWER_BOT_2`=7, `TOWER_BOT_3`=8, `TOWER_MID_1`=3, `TOWER_MID_2`=4, `TOWER_MID_3`=5, `TOWER_TOP_1`=0, `TOWER_TOP_2`=1, `TOWER_TOP_3`=2
- **UNIT_LIST**: `UNIT_LIST_ALL`=0, `UNIT_LIST_ALLIED_BUILDINGS`=5, `UNIT_LIST_ALLIED_CREEPS`=3, `UNIT_LIST_ALLIED_HEROES`=2, `UNIT_LIST_ALLIED_OTHER`=6, `UNIT_LIST_ALLIED_WARDS`=4, `UNIT_LIST_ALLIES`=1, `UNIT_LIST_ENEMIES`=7, `UNIT_LIST_ENEMY_BUILDINGS`=11, `UNIT_LIST_ENEMY_CREEPS`=9, `UNIT_LIST_ENEMY_HEROES`=8, `UNIT_LIST_ENEMY_OTHER`=12, `UNIT_LIST_ENEMY_WARDS`=10, `UNIT_LIST_NEUTRAL_CREEPS`=13, `UNIT_LIST_THINKERS`=14
- **other**: `BOT_DESIRE_OVERRIDE`=1*, `DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE`=64, `GLYPH_COOLDOWN`=360, `SHRINE_BASE_1`=0, `SHRINE_BASE_2`=1, `SHRINE_BASE_3`=2, `SHRINE_JUNGLE_1`=3, `SHRINE_JUNGLE_2`=4

## Names that come from our own scripts

The dump reads the live tables, so it also lists what OpenHyperAI defines or replaces. These are **not** engine API:

- Global functions defined by our scripts: `AttackUnits`, `ConsiderMove`, `GetAdjustedDesireValue`, `HandleIdleBotState`, `_HandleIdleBotStateInner`, `IsLanMode`, `LoadCustomize`, `OhaCastGuard`, `SafeAbility`, `SafeCall`, `ShouldSkipBotThink`, `UseAstralPull`, `UseCyclone`, `UseDispelMagic`, `UseHurlBoulder`, `UseWindWalk`, `VerifyLastSwap`.
- Engine globals that our scripts wrap (the engine has them; ours adds checks or logging): `GetScriptDirectory`, `GetTeamPlayers`, `GetUnitToLocationDistance`, `GetUnitToUnitDistance`, `RandomFloat`, `next`, `print`.
- Methods added to `CDOTA_Bot_Script` by `FuncLib/systems/global_overrides.lua`: `OriginalGetHealth`, `OriginalGetMaxHealth`, and `GetUnitToLocationDistance` as a method (the engine only has the global). It also wraps these engine methods: `ActionImmediate_SwapItems`, `ActionPush_UseAbility`, `Action_AttackUnit`, `Action_UseAbility`, `GetAbilityByName`, `GetAssignedLane`, `GetAttackRange`, `GetAttackTarget`, `GetCastRange`, `GetHealth`, `GetLocation`, `GetMagicResist`, `GetMana`, `GetMaxHealth`, `GetMaxMana`, `GetNearbyCreeps`, `GetNearbyHeroes`, `GetNearbyLaneCreeps`, `GetNearbyNeutralCreeps`, `GetNearbyTowers`, `GetTarget`, `GetUnitName`, `HasModifier`, `IsAttackImmune`, `IsChanneling`, `IsIllusion`, `IsInvulnerable`, `IsMagicImmune`, `IsUsingAbility`, `NumModifiers`, `WasRecentlyDamagedByAnyHero`.

## Counts

| Group | Functions |
|---|---|
| Unit / bot methods (CDOTA_Bot_Script) | 220 |
| Ability and item methods (CDOTABaseAbility_BotScript) | 50 |
| Global functions | 173 |
| CDOTA_TeamCommander | 1 |

## Unit / bot methods (CDOTA_Bot_Script)

### Action

`Action_AttackMove`, `Action_AttackUnit`, `Action_ClearActions`, `Action_Delay`, `Action_DropItem`, `Action_MoveDirectly`, `Action_MovePath`, `Action_MoveToLocation`, `Action_MoveToUnit`, `Action_PickUpItem`, `Action_PickUpRune`, `Action_UseAbility`, `Action_UseAbilityOnEntity`, `Action_UseAbilityOnLocation`, `Action_UseAbilityOnTree`, `Action_UseShrine`

### ActionImmediate

`ActionImmediate_Buyback`, `ActionImmediate_Chat`, `ActionImmediate_Courier`, `ActionImmediate_DisassembleItem`, `ActionImmediate_Glyph`, `ActionImmediate_LevelAbility`, `ActionImmediate_Ping`, `ActionImmediate_PurchaseItem`, `ActionImmediate_SellItem`, `ActionImmediate_SetItemCombineLock`, `ActionImmediate_SwapItems`

### ActionPush

`ActionPush_AttackMove`, `ActionPush_AttackUnit`, `ActionPush_Delay`, `ActionPush_DropItem`, `ActionPush_MoveDirectly`, `ActionPush_MovePath`, `ActionPush_MoveToLocation`, `ActionPush_MoveToUnit`, `ActionPush_PickUpItem`, `ActionPush_PickUpRune`, `ActionPush_UseAbility`, `ActionPush_UseAbilityOnEntity`, `ActionPush_UseAbilityOnLocation`, `ActionPush_UseAbilityOnTree`, `ActionPush_UseShrine`

### ActionQueue

`ActionQueue_AttackMove`, `ActionQueue_AttackUnit`, `ActionQueue_Delay`, `ActionQueue_DropItem`, `ActionQueue_MoveDirectly`, `ActionQueue_MovePath`, `ActionQueue_MoveToLocation`, `ActionQueue_MoveToUnit`, `ActionQueue_PickUpItem`, `ActionQueue_PickUpRune`, `ActionQueue_UseAbility`, `ActionQueue_UseAbilityOnEntity`, `ActionQueue_UseAbilityOnLocation`, `ActionQueue_UseAbilityOnTree`, `ActionQueue_UseShrine`

### Can

`CanBeSeen`

### Find

`FindAoELocation`, `FindItemSlot`

### Get

`GetAbilityByName`, `GetAbilityInSlot`, `GetAbilityPoints`, `GetAbilityTarget`, `GetAcquisitionRange`, `GetActiveMode`, `GetActiveModeDesire`, `GetActualIncomingDamage`, `GetAnimActivity`, `GetAnimCycle`, `GetArmor`, `GetAssignedLane`, `GetAttackDamage`, `GetAttackPoint`, `GetAttackProjectileSpeed`, `GetAttackRange`, `GetAttackSpeed`, `GetAttackTarget`, `GetAttributeValue`, `GetBaseDamage`, `GetBaseDamageVariance`, `GetBaseHealthRegen`, `GetBaseManaRegen`, `GetBaseMovementSpeed`, `GetBoundingRadius`, `GetBountyGoldMax`, `GetBountyGoldMin`, `GetBountyXP`, `GetBuybackCooldown`, `GetBuybackCost`, `GetCourierValue`, `GetCurrentActionType`, `GetCurrentActiveAbility`, `GetCurrentMovementSpeed`, `GetCurrentVisionRange`, `GetDayTimeVisionRange`, `GetDenies`, `GetDifficulty`, `GetEstimatedDamageToTarget`, `GetEvasion`, `GetExtrapolatedLocation`, `GetFacing`, `GetGold`, `GetGroundHeight`, `GetHealth`, `GetHealthRegen`, `GetHealthRegenPerStr`, `GetIncomingTrackingProjectiles`, `GetItemInSlot`, `GetItemSlotType`, `GetLastAttackTime`, `GetLastHits`, `GetLevel`, `GetLocation`, `GetMagicResist`, `GetMana`, `GetManaRegen`, `GetManaRegenPerInt`, `GetMaxHealth`, `GetMaxMana`, `GetModifierAuxiliaryUnits`, `GetModifierByName`, `GetModifierList`, `GetModifierName`, `GetModifierRemainingDuration`, `GetModifierStackCount`, `GetMostRecentPing`, `GetMovementDirectionStability`, `GetNearbyBarracks`, `GetNearbyCreeps`, `GetNearbyFillers`, `GetNearbyHeroes`, `GetNearbyLaneCreeps`, `GetNearbyNeutralCreeps`, `GetNearbyShrines`, `GetNearbyTowers`, `GetNearbyTrees`, `GetNetWorth`, `GetNextItemPurchaseValue`, `GetNightTimeVisionRange`, `GetOffensivePower`, `GetPlayerID`, `GetPrimaryAttribute`, `GetQueuedActionType`, `GetRawOffensivePower`, `GetRemainingLifespan`, `GetRespawnTime`, `GetSecondsPerAttack`, `GetSlowDuration`, `GetSpellAmp`, `GetStashValue`, `GetStunDuration`, `GetTalent`, `GetTarget`, `GetTeam`, `GetUnitName`, `GetUnitToLocationDistance`, `GetVelocity`, `GetXPNeededToLevel`

### Has

`HasBlink`, `HasBuyback`, `HasInvisibility`, `HasMinistunOnAttack`, `HasModifier`, `HasScepter`, `HasSilence`

### Is

`IsAlive`, `IsAncientCreep`, `IsAttackImmune`, `IsBlind`, `IsBlockDisabled`, `IsBot`, `IsBuilding`, `IsCastingAbility`, `IsChanneling`, `IsCourier`, `IsCreep`, `IsDisarmed`, `IsDominated`, `IsEvadeDisabled`, `IsFacingLocation`, `IsFort`, `IsHero`, `IsHexed`, `IsIllusion`, `IsInvisible`, `IsInvulnerable`, `IsMagicImmune`, `IsMinion`, `IsMuted`, `IsNightmared`, `IsNull`, `IsRooted`, `IsSilenced`, `IsSpeciallyDeniable`, `IsSpeciallyUndeniable`, `IsStunned`, `IsTower`, `IsUnableToMiss`, `IsUsingAbility`

### Other

`DistanceFromFountain`, `DistanceFromSecretShop`, `DistanceFromSideShop`, `NumModifiers`, `NumQueuedActions`, `OriginalGetHealth`, `OriginalGetMaxHealth`, `TimeSinceDamagedByAnyHero`, `TimeSinceDamagedByCreep`, `TimeSinceDamagedByHero`, `TimeSinceDamagedByPlayer`, `TimeSinceDamagedByTower`, `UsingItemBreaksInvisibility`

### Set

`SetNextItemPurchaseValue`, `SetTarget`

### Was

`WasRecentlyDamagedByAnyHero`, `WasRecentlyDamagedByCreep`, `WasRecentlyDamagedByHero`, `WasRecentlyDamagedByPlayer`, `WasRecentlyDamagedByTower`

## Ability and item methods (CDOTABaseAbility_BotScript)

### Can

`CanAbilityBeUpgraded`, `CanBeDisassembled`

### Get

`GetAOERadius`, `GetAbilityDamage`, `GetAutoCastState`, `GetBehavior`, `GetCastPoint`, `GetCastRange`, `GetCaster`, `GetChannelTime`, `GetChannelledManaCostPerSecond`, `GetCooldown`, `GetCooldownTimeRemaining`, `GetCurrentCharges`, `GetDamageType`, `GetDuration`, `GetEstimatedDamageToTarget`, `GetHeroLevelRequiredToUpgrade`, `GetInitialCharges`, `GetLevel`, `GetManaCost`, `GetMaxLevel`, `GetName`, `GetPowerTreadsStat`, `GetSecondaryCharges`, `GetSpecialValueFloat`, `GetSpecialValueInt`, `GetTargetFlags`, `GetTargetTeam`, `GetTargetType`, `GetToggleState`

### Is

`IsActivated`, `IsChanneling`, `IsCombineLocked`, `IsCooldownReady`, `IsFullyCastable`, `IsHidden`, `IsInAbilityPhase`, `IsItem`, `IsNull`, `IsOwnersManaEnough`, `IsPassive`, `IsStealable`, `IsStolen`, `IsTalent`, `IsToggle`, `IsTrained`, `IsUltimate`

### Other

`ProcsMagicStick`, `ToggleAutoCast`

## Global functions

`AddAvoidanceZone`, `AddConditionalAvoidanceZone`, `AttackUnits`, `CMBanHero`, `CMPickHero`, `Clamp`, `ConsiderMove`, `CreateHTTPRequest`, `CreateRemoteHTTPRequest`, `DebugDrawCircle`, `DebugDrawLine`, `DebugDrawText`, `DebugPause`, `DebuggerBreak`, `DotaTime`, `GameTime`, `GeneratePath`, `GetAdjustedDesireValue`, `GetAllTrees`, `GetAmountAlongLane`, `GetAncient`, `GetAvoidanceZones`, `GetBarracks`, `GetBot`, `GetBotAbilityByHandle`, `GetBotByHandle`, `GetCMCaptain`, `GetCMPhaseTimeRemaining`, `GetCourier`, `GetCourierForPlayer`, `GetCourierState`, `GetDefendLaneDesire`, `GetDroppedItemList`, `GetFarmLaneDesire`, `GetGameMode`, `GetGameState`, `GetGameStateTimeRemaining`, `GetGlyphCooldown`, `GetHeightLevel`, `GetHeroAssists`, `GetHeroDeaths`, `GetHeroKills`, `GetHeroLastSeenInfo`, `GetHeroLevel`, `GetHeroPickState`, `GetIncomingTeleports`, `GetItemComponents`, `GetItemCost`, `GetItemStockCount`, `GetLaneFrontAmount`, `GetLaneFrontLocation`, `GetLinearProjectileByHandle`, `GetLinearProjectiles`, `GetLocationAlongLane`, `GetNeutralSpawners`, `GetNumCouriers`, `GetOpposingTeam`, `GetOutpost`, `GetPushLaneDesire`, `GetRoamDesire`, `GetRoamTarget`, `GetRoshanDesire`, `GetRoshanKillTime`, `GetRuneSpawnLocation`, `GetRuneStatus`, `GetRuneTimeSinceSeen`, `GetRuneType`, `GetScriptDirectory`, `GetSelectedHeroName`, `GetShopLocation`, `GetShrine`, `GetShrineCooldown`, `GetTeam`, `GetTeamForPlayer`, `GetTeamMember`, `GetTeamPlayers`, `GetTimeOfDay`, `GetTower`, `GetTowerAttackTarget`, `GetTreeLocation`, `GetUnitList`, `GetUnitPotentialValue`, `GetUnitToLocationDistance`, `GetUnitToLocationDistanceSqr`, `GetUnitToUnitDistance`, `GetUnitToUnitDistanceSqr`, `GetWorldBounds`, `HandleIdleBotState`, `InstallCastCallback`, `InstallChatCallback`, `InstallCourierDeathCallback`, `InstallDamageCallback`, `InstallRoshanDeathCallback`, `IsCMBannedHero`, `IsCMPickedHero`, `IsCourierAvailable`, `IsFlyingCourier`, `IsHeroAlive`, `IsInCMBanPhase`, `IsInCMPickPhase`, `IsItemPurchasedFromSecretShop`, `IsItemPurchasedFromSideShop`, `IsLanMode`, `IsLocationPassable`, `IsLocationVisible`, `IsPlayerBot`, `IsPlayerInHeroSelectionControl`, `IsRadiusVisible`, `IsShrineHealing`, `IsTeamPlayer`, `LoadCustomize`, `Max`, `Min`, `Msg`, `OHA_RAW_PRINT`, `OhaCastGuard`, `PointToLineDistance`, `QAngle`, `RandomFloat`, `RandomFloatWrapper`, `RandomInt`, `RandomVector`, `RealTime`, `RemapValClamped`, `RemoveAvoidanceZone`, `RollPercentage`, `SafeAbility`, `SafeCall`, `Script_RandomFloat`, `Script_RemapVal`, `SelectHero`, `SetCMCaptain`, `ShouldSkipBotThink`, `UseAstralPull`, `UseCyclone`, `UseDispelMagic`, `UseHurlBoulder`, `UseWindWalk`, `Vector`, `VerifyLastSwap`, `Warning`, `_HandleIdleBotStateInner`, `assert`, `collectgarbage`, `dofile`, `error`, `gcinfo`, `getfenv`, `getmetatable`, `ipairs`, `load`, `loadfile`, `loadstring`, `log`, `module`, `newproxy`, `next`, `pairs`, `pcall`, `print`, `printstack`, `rawequal`, `rawget`, `rawset`, `require`, `select`, `setfenv`, `setmetatable`, `tonumber`, `tostring`, `type`, `unpack`, `xpcall`

## CDOTA_TeamCommander

### Is

`IsNull`

The bot handle (`GetBot()`) exposes the same 220 functions as `CDOTA_Bot_Script`.
