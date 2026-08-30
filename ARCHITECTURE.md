# Neomorph Resource Panel architecture

## Modules

```text
core/DB.lua
core/Debug.lua
modules/ResourceBar.lua
core/Init.lua
```

`core/DB.lua` owns the schema-v2 SavedVariables boundary and the shared access-first helpers. `core/Debug.lua` owns a runtime-only bounded ring buffer. `modules/ResourceBar.lua` owns the addon-created frame, StatusBar, power/color state, and curve evaluation. `core/Init.lua` owns native event registration and slash commands.

## State ownership

Persistent state is limited to enablement, movement lock, threshold, dimensions, text/debug toggles, and position. Restricted gameplay values, curve results, and event payloads are never persisted.

Runtime state is limited to the current ordinary power type/token, ordinary base color, addon frame references, the ordinary color cache, and an addon-created threshold curve.

## Power flow

1. `UNIT_DISPLAYPOWER`, `UNIT_MAXPOWER`, `UNIT_POWER_UPDATE`, world entry, and combat transitions trigger an update.
2. `UnitPowerType("player")` supplies the ordinary power type/token and optional ordinary resource color.
3. `UnitPowerMax` and `UnitPower` are passed to native StatusBar sinks. Lua arithmetic occurs only when both values are accessible ordinary numbers.
4. Numeric text uses `UnitPowerPercent(..., CurveConstants.ScaleTo100)` only when the result is accessible.
5. In combat, a normalized color curve is evaluated through `UnitPowerPercent`. Inaccessible curve output falls back to the resource color.

## Secret-value boundary

`NS.Safe.CanAccess` is called before type checks, comparisons, arithmetic, formatting, indexing, logging, or serialization. `pcall` contains API errors but does not declassify a result.

The addon never tries to recover restricted power values. Native widget sinks render the fill; curve evaluation is used only when it returns an accessible color result.

## Combat boundary

The frame is addon-owned. Normal event-driven value/color updates continue in combat. Dragging and full settings reset are blocked in combat. No protected Blizzard frame is modified.

## Performance

There is no periodic driver. Work is proportional to native power/display/combat events. The debug ring is disabled by default, runtime-only, and bounded.

## Evidence ceiling

The code targets source baseline `12.1.0.69497`. Local mocks establish control-flow and access-order invariants, not live restricted-context behavior, visual correctness, taint safety, or future-build compatibility.
