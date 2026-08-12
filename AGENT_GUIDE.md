# Agent guide: NeomorphResourcePanel

## Start here

[`NeomorphResourcePanel.toc`](NeomorphResourcePanel.toc) loads `core/DB.lua`, `core/Debug.lua`, `modules/ResourceBar.lua`, then `core/Init.lua`. The file-load namespace is `local ADDON_NAME, NS = ...`; `core/Init.lua` creates the event frame and is the single lifecycle/slash entry point.

## Runtime map

- `core/DB.lua:NS.GetDB` applies defaults to `NeomorphResourcePanelDB`; `NS.ResetDB` replaces it with defaults. Durable keys are `locked`, `threshold`, `width`, `height`, `showText`, and point/offset fields.
- `core/Init.lua` handles `PLAYER_LOGIN` (module check, `ResourceBar:Create`, `ApplyDB`), player power/max/display events, combat transitions, and world entry. It narrows power events to `player` with `RegisterUnitEvent`.
- `modules/ResourceBar.lua:M:Create` creates `NeomorphResourcePanelFrame`, StatusBar, optional text, drag handlers, and transient color/curve caches. `M:UpdateAll` reads `UnitPowerType`, `UnitPowerMax`, `UnitPower`, and color data; `M:ApplyColor` selects resource color or combat red threshold, with a curve fallback for secret percentages.
- `core/Debug.lua` owns a bounded local debug log exposed by `/nrp log [n]`; it is not a second persistence system.

## State and dependencies

The only SavedVariables table is `NeomorphResourcePanelDB`; frame, cached resource type/max, color curve, and debug state are runtime. There are no addon/library dependencies. The module observes Blizzard power APIs and uses `C_CurveUtil`/`Enum.LuaCurveType` when available.

## Change routing

- Defaults/reset/schema: `core/DB.lua`.
- Event registration/command grammar: `core/Init.lua`; keep power events player-filtered.
- Bar geometry/drag/text: `ResourceBar:Create`, `ApplyDB`, and drag handlers in `modules/ResourceBar.lua`.
- Resource reading/formatting: `UpdateAll`, `OnPowerUpdate`, `OnDisplayPower` in `ResourceBar.lua`.
- Combat threshold/secret handling: `ApplyColor`, `EnsureCombatCurve`, `UpdatePercentScale`; do not compare or format secret values.
- Diagnostics only: `core/Debug.lua` and `/nrp log`.

## Invariants/risks

- The bar represents the player resource only; `OnPowerUpdate` must ignore non-player units and irrelevant power tokens.
- In combat, `UnitPower`/`UnitPowerMax`/`UnitPowerPercent` may return secret values. Preserve `IsSecret` guards, avoid arithmetic/comparison on secrets, and use the curve path or safe fallback.
- Dragging and reset are blocked in combat via `InCombatLockdown`; preserve position persistence and clamping.
- `UpdateAll` is event-driven and can be frequent. Keep cached bar/text colors and avoid unnecessary StatusBar writes.

## Verification

Static checks:

```powershell
Get-Content _Addons/NeomorphResourcePanel/NeomorphResourcePanel.toc
rg -n "NeomorphResourcePanelDB|UpdateAll|ApplyColor|RegisterUnitEvent|SlashCmdList|InCombatLockdown|C_CurveUtil" _Addons/NeomorphResourcePanel
```

In-game: `/nrp help`, drag/unlock/lock, `/nrp threshold 0.8`, reset out of combat and in combat, switch power forms/resources, test text/value updates, cross the threshold during combat, reload/login, and inspect `/nrp log`. Confirm no arithmetic/taint errors when resource values are restricted.

## Unknowns

Exact `UnitPowerPercent` scale and secret-return behavior are client/build dependent; the code probes scale only on safe paths. Validate the curve output visually in the target build.
