# Dota bot API: what the game really exposes

Runtime dump from the game itself, not from the online docs. Taken on 2026-11-16 (game 033, bot build 2026.11.16-082) by the `[OHA-API]` dump in `ability_item_usage_generic.lua` (`a.DumpBotApi`), which runs once per game from Radiant's first bot. To refresh it, start any game and grep the console log for `[OHA-API]`.

The online references ([Valve Developer Wiki](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting), [ModDota](https://docs.moddota.com/lua_bots/)) carry no date and describe an older API. Where they disagree with this file, this file wins.

The list of known limitations (what bots can't do, why, and the workaround) is kept in the main post of
[discussion #50](https://github.com/anggara-ts/OpenHyperAI-too/discussions/50); update it when a limitation is
confirmed or disproved.

## Key findings

- **No vector-target order.** Abilities can only be cast with no target, on a unit, on a location or on a tree (plus the Push/Queue variants). A vector-targeted spell such as Muerta's Dead Shot cannot have its direction chosen.
- `GetCurrentCharges`, `GetInitialCharges` and `GetSecondaryCharges` exist on abilities as well as items. On the Ward Dispenser the first is observers and the second sentries (game 032). Whether they return charges for charge-based abilities (Mirana's Leap, Techies' mines, ...) has not been tested; `FuncLib/systems/charge_tracker.lua` still tracks those itself.
- `GetToggleState`, `IsInAbilityPhase`, `GetDamageType`, `GetTargetType/Team/Flags` are available on abilities.
- Item management beyond buy/sell: `ActionImmediate_DisassembleItem`, `ActionImmediate_SetItemCombineLock`, `ActionImmediate_SwapItems`.
- Shrines and runes have their own orders: `Action_UseShrine`, `Action_PickUpRune` (plus Push/Queue). `GetOutpost`, `GetShrine`, `GetShrineCooldown`, `IsShrineHealing`, `GetNearbyShrines` are available.

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
