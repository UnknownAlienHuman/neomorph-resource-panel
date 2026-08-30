# Neomorph Resource Panel

A compact, event-driven player power bar for World of Warcraft Retail 12.1. It uses the active resource color and can switch to a warning color in combat when the configured power threshold is reached.

## Compatibility

- Retail / Midnight `12.1.0`
- Interface `120100`
- Version `0.2.0`
- Verified Blizzard source baseline `12.1.0.69497`
- SavedVariables `NeomorphResourcePanelDB`
- External dependencies: none
- GitHub Actions / CI: none

## Restricted-value model

Retail 12.1 may restrict `UnitPower` and `UnitPowerMax` in some contexts. The addon does not perform arithmetic, comparisons, formatting, logging, or serialization until accessibility has been checked.

The bar fill uses the native `StatusBar:SetMinMaxValues` and `StatusBar:SetValue` sinks, which can receive the raw values without reconstructing them in Lua.

Combat threshold coloring prefers:

```text
UnitPowerPercent("player", powerType, false, colorCurve)
```

The curve maps the normalized power percentage to either the ordinary resource color or the ordinary warning color. If the curve result is unavailable/inaccessible, the addon fails closed to the resource color instead of inventing a threshold result.

Numeric text uses `CurveConstants.ScaleTo100` only when the returned value is accessible. Otherwise the display falls back to the ordinary resource token.

## Commands

```text
/nrp help
/nrp lock
/nrp toggle
/nrp text
/nrp threshold <0..1>
/nrp reset
/nrp debug
/nrp log [n]
/nrp status
```

`/nrp reset` is blocked in combat because it changes frame geometry. Locking the panel disables mouse interception entirely.

## Performance

- native unit-power events only;
- no `OnUpdate`;
- no ticker or polling loop;
- no combat log;
- no aura scan;
- no frame-tree scan;
- debug logging is disabled by default and bounded to 200 runtime entries.

## Validation

`tests/test_resource_panel_12_1.lua` checks schema migration, restricted-value ordering, native StatusBar sinks, curve threshold behavior, event-token handling, lock/reset behavior, and debug sanitization.

Live-client verification is still required before release. See [Docs/TODO.md](Docs/TODO.md).

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

Licensed under the [MIT License](LICENSE).
