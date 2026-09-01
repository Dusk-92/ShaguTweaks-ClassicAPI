# ShaguTweaks-ClassicAPI third-party notices

This file records third-party material, upstream sources, external runtime
dependencies, and development references known to ShaguTweaks-ClassicAPI.

It is intentionally additive: source comments, Git history, upstream license
notices, and README credits remain part of the provenance trail and should not
be removed merely because this summary exists.

## ShaguTweaks

ShaguTweaks-ClassicAPI is a fork of ShaguTweaks:

- Source: https://github.com/shagu/ShaguTweaks
- Copyright (c) 2021 Eric Mauser (Shagu)
- License: MIT

The original MIT license remains at the repository root in `LICENSE` and an
additional preserved copy is stored in `LICENSES/ShaguTweaks-MIT.txt`.

The MIT grant applies to material for which the upstream copyright holder had
the right to grant those permissions. It does not by itself establish ownership
or relicensing authority over unrelated third-party or game-derived assets that
may have been present in an upstream package.

## TokensWorth/ShaguTweaks-mods

Extended frame support in `mods/move-unitframes.lua` contains code adapted
from `TokensWorth/ShaguTweaks-mods`:

- Upstream module: `mods/move-unitframes-extended.lua`
- Source: https://github.com/TokensWorth/ShaguTweaks-mods
- Copyright (c) 2022 GryllsAddons
- License: MIT

The preserved license text is stored in
`LICENSES/ShaguTweaks-mods-MIT.txt`.

## ClassicAPI

ClassicAPI is a required external runtime dependency used by
ShaguTweaks-ClassicAPI.

- Source: https://github.com/brues-code/ClassicAPI
- The upstream repository includes the GNU General Public License version 3.
- ClassicAPI itself is **not bundled** in this addon repository.

A verbatim copy of the upstream license document is preserved in
`LICENSES/ClassicAPI-GPL-3.0.txt` for reference. Including that license text
does not relicense ShaguTweaks-ClassicAPI under the GPL and does not imply that
ClassicAPI binaries or source are distributed as part of this addon.

## AoELoot

`mods/aoe-loot.lua` is adapted from the standalone AoELoot addon provided to
the project by Sandrea:

- Original addon title: `AoELoot`
- Original metadata credit: Sandrea / ChatGPT
- Adapted module: `mods/aoe-loot.lua`

The supplied package did not include an upstream URL or a separate license
file. This notice records the known provenance and preserves attribution; it
does not infer additional licensing terms.

## SuperWoW

SuperWoW is an optional external runtime dependency/fallback used by some
compatibility paths.

- Source: https://github.com/balakethelock/SuperWoW
- SuperWoW is **not bundled** in this addon repository.
- Its upstream license is preserved verbatim in
  `LICENSES/SuperWoW-LICENSE.txt`.

The upstream SuperWoW license has its own restrictions. This notice records the
dependency and preserves its license; it does not extend those terms to
ShaguTweaks-ClassicAPI or grant additional rights in SuperWoW.

## pfUI and zUI

pfUI and zUI are credited in the project README as sources of additional code
ideas and development reference.

This notice does **not** make a broader claim that either project is bundled in
whole, nor does it infer a license for unspecified material. Any specific
future copied or substantially adapted component should be documented with its
exact source, affected files, and applicable license at the time it is added.

## Turtle WoW-like environments

ShaguTweaks-ClassicAPI contains compatibility logic intended for Turtle WoW-like
server/client environments. Compatibility, testing, naming, or behavioral
reference does not create an affiliation, endorsement, partnership, or
ownership relationship with those projects or their maintainers.

## Artwork and screenshots

Artwork under `img/` and screenshots under `screenshots/` are tracked
separately in `Docs/ASSET_PROVENANCE.md`.

A project-level software license does not automatically prove ownership or
relicensing authority for every visual asset in an upstream project. The asset
manifest therefore records exact upstream matches without making broader
ownership claims.

## Project identity and trademarks

The canonical repository maintained by Dusk-92 is:

- https://github.com/Dusk-92/ShaguTweaks-ClassicAPI

Forks, mirrors, package caches, and modified copies hosted elsewhere are
independent unless this canonical project explicitly states otherwise.

World of Warcraft and Blizzard Entertainment names, marks, and game assets
remain the property of their respective rights holders. Other project names and
trademarks remain the property of their respective owners.

See `PROJECT_IDENTITY.md` for the full project-identity notice.

## Preservation rule

Do not remove historical source comments, attribution notes, license notices,
compatibility explanations, or provenance records simply because newer
documentation summarizes them.

When replacing or substantially rewriting third-party-derived material, update
the provenance record rather than erasing the earlier history.
