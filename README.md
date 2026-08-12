# NeomorphResourcePanel

A compact player resource bar that uses the active resource color and changes to a combat warning color above a configurable threshold.

## Installation

Copy the `NeomorphResourcePanel` directory into `World of Warcraft/_retail_/Interface/AddOns/`, then restart the client or use `/reload`.

## Compatibility and data

- Interface: `120001`, `120005`
- Version: `0.1.1`
- Saved variables: `NeomorphResourcePanelDB`

## Usage

Use `/nrp help` to list commands. Supported controls include `/nrp lock`, `/nrp reset`, `/nrp threshold <0..1>`, and `/nrp log [n]`.

## Development status

No older todo or history tracker was present. This repository now tracks the required target-client smoke test of resource updates, combat threshold behavior, movement lock, and reset in [todo.md](todo.md).

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
