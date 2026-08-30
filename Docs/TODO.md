# Neomorph Resource Panel live validation matrix

Local tests validate code boundaries only. Complete these checks on the exact Retail 12.1 target client before release.

## P0 — load and migration

- [ ] Fresh install with no SavedVariables.
- [ ] Migration from representative 0.1.x SavedVariables.
- [ ] Invalid/oversized threshold, dimensions, point, and coordinates sanitize correctly.
- [ ] `/reload` outside combat and during combat.
- [ ] No Lua, forbidden-action, taint, or restricted-value error.

## P0 — resources and forms

- [ ] Mana, rage, energy, focus, runic power, and applicable class secondary resources.
- [ ] Form/stance/spec/vehicle changes that fire `UNIT_DISPLAYPOWER`.
- [ ] Resource maximum changes from talents, buffs, or equipment.
- [ ] Zero/empty resource and full resource.
- [ ] Rapid generation/spending without stale value or color.
- [ ] Normal outdoor combat and restricted dungeon/raid/PvP contexts.

## P0 — threshold and text

- [ ] Out of combat always uses the active resource color.
- [ ] In combat below, exactly at, and above the configured threshold.
- [ ] Curve-based warning color when raw current/max power is restricted.
- [ ] Restricted curve result falls back to resource color without error.
- [ ] Numeric current/max/percent text when accessible.
- [ ] Resource-token fallback when numeric text is inaccessible.
- [ ] `/nrp threshold <0..1>` updates color immediately.
- [ ] `/nrp text` toggles text without recreating the frame.

## P0 — movement and persistence

- [ ] Drag while unlocked and out of combat.
- [ ] Drag blocked in combat.
- [ ] Locked frame does not intercept mouse input.
- [ ] Saved position, width, height, lock, threshold, text, and enabled state persist through `/reload` and restart.
- [ ] `/nrp reset` restores defaults out of combat and is blocked in combat.
- [ ] `/nrp toggle`, `/nrp lock`, `/nrp status`.

## P1 — diagnostics and performance

- [ ] Debug is silent by default.
- [ ] `/nrp debug` and `/nrp log [n]` produce only ordinary sanitized output.
- [ ] Debug ring remains bounded under repeated updates.
- [ ] CPU/allocation capture during idle and rapid power updates.
- [ ] Confirm no `OnUpdate`, ticker, combat-log, aura, or frame-tree scan appears.

## Release gate

Record client build, class/spec/resource combinations, restricted contexts, profiler data, SavedVariables migration result, and any errors before publishing the release.
