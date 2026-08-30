# Neomorph Resource Panel agent guide

## Contract

Target Retail 12.1 / Interface `120100`. Preserve the compact resource bar, resource coloring, combat warning threshold, movement lock, numeric text, and slash controls.

Read in this order:

1. `NeomorphResourcePanel.toc`
2. `core/DB.lua`
3. `modules/ResourceBar.lua`
4. `core/Init.lua`
5. `core/Debug.lua`
6. `ARCHITECTURE.md`
7. `tests/test_resource_panel_12_1.lua`

## Power API rules

Generated Retail 12.1 docs mark:

- `UnitPower` as `SecretWhenUnitPowerRestricted`;
- `UnitPowerMax` as `SecretWhenUnitPowerMaxRestricted`;
- `UnitPowerPercent` as curve-capable and potentially restricted.

Required order:

1. call the API;
2. test accessibility;
3. only then use `type`, comparison, arithmetic, formatting, indexing, logging, or persistence.

Do not use `tonumber`, `tostring`, copying, `pcall`, or serialization as declassification.

## Native sinks

Raw current/max power may be forwarded to the addon-owned StatusBar:

```text
StatusBar:SetMinMaxValues
StatusBar:SetValue
```

Do not cache, compare, or format inaccessible values. Do not replace the native sink with a smoothing library that reads/clamps cached values in Lua.

## Curves

The custom color curve uses normalized input `[0, 1]`. `CurveConstants.ScaleTo100` is used only for accessible text output.

A curve result must pass the same access boundary before `GetRGB` and color application. If unavailable, use the ordinary resource color; never infer threshold state from fill geometry, timing, errors, or visibility.

## Events

Use native frame events and `RegisterUnitEvent` for player power updates. Keep the addon event-driven. Do not add polling, combat-log reconstruction, aura scans, or a permanent `OnUpdate`.

Event payloads such as `powerTypeToken` must be access-checked before comparison. An inaccessible token should trigger a safe full refresh, not an error or skipped update.

## UI and SavedVariables

The frame is addon-owned. Drag/reset geometry changes remain blocked in combat. A locked frame must disable mouse interception.

Schema changes belong in `core/DB.lua`; validate all persisted scalars and point names. Never persist gameplay payloads or curve objects.

Debug is opt-in, bounded, and must sanitize every payload before formatting or chat output.

## Verification

```text
texlua --luaconly core/DB.lua core/Debug.lua modules/ResourceBar.lua core/Init.lua tests/test_resource_panel_12_1.lua
texlua tests/test_resource_panel_12_1.lua
```

Then run the exact live matrix in `Docs/TODO.md`. Do not claim client validation from mocks.

Do not add GitHub Actions or other CI unless the owner explicitly changes the repository policy.
