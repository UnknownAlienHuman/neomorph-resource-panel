# Architecture

The TOC loads database defaults and debug support before `modules/ResourceBar.lua`, then `core/Init.lua` creates the UI and dispatches lifecycle and player-resource events. `core/DB.lua` owns `NeomorphResourcePanelDB`; `modules/ResourceBar.lua` owns the frame and its update/application methods.

The initialization frame creates the bar at login, forwards display/power/combat/world events to the module, and owns the `/nrp` command surface. Test resource-type changes, threshold color changes, position persistence, and combat-safe reset handling in-game.
