# Stadium Overworld DX

**Stadium Overworld DX** is an early beta compatibility build for Pokémon Gen1Recomp. It adds Pokémon Stadium-style 3D models to overworld and follower Pokémon while targeting modern **DRAMALESS_SHAPE v2.x**.

This mod is designed to pair with **STADIUM_BATTLE_FX** for battle Pokémon models, battle effects, cameras, and battle presentation.

Pikachu escaped the battle screen and brought the polygons with it.

---

## Status

**Early Beta / Compatibility Test Build**

This is not a final stable release. It is ready for testing, bug reports, screenshots, and compatibility feedback.

---

## Recommended Setup

- Gen1Recomp modern build
- DRAMALESS_SHAPE v2.x
- STADIUM_BATTLE_FX v2.1.7+ for battle models/effects
- Stadium Overworld DX for overworld/follower models

---

## Currently Working in Testing

- Gen1Recomp Imported Files workflow
- Pokémon Stadium ROM import through the Mod Manager row
- STADIUM ROM FILE reaches READY
- DRAMALESS_SHAPE overworld voxel 3D remains active
- Lead-party followers render as Stadium-style 3D models
- Tested lead followers:
  - Pikachu
  - Rattata
  - Pidgey
  - Mankey
- Pokémon Center Chansey renders in 3D
- Viridian Pokémon Center remains voxel 3D
- Battle Pokémon Stadium models work when STADIUM_BATTLE_FX is enabled
- Battle effects work when STADIUM_BATTLE_FX is enabled
- Fixed Red yellow/gold artifact from earlier compatibility tests
- Coexists with DRAMALESS_SHAPE v2.x and STADIUM_BATTLE_FX in current testing

---

## Known Issues / Limitations

- Static overworld Pokémon mappings are incomplete.
  - Pewter Nidoran may still appear 2D.
  - Viridian Speary/Spearow may still appear 2D.
- Non-Pikachu Yellow follower interaction/emotion bubbles still use Pikachu-style behavior.
- Multi-follower behavior should come from compatible follower mods such as Wilds of Kanto or Followers EX.
- Users may currently need to import the Pokémon Stadium ROM separately for this mod and STADIUM_BATTLE_FX.
- Compatibility is focused on DRAMALESS_SHAPE v2.x. Other voxel mods are not fully tested.
- Battle rendering is owned by STADIUM_BATTLE_FX / DRAMALESS_SHAPE. If battle Pokémon appear late, partially, or with missing textures, test with Stadium Overworld DX disabled before reporting here.

---

## Mod Manager Imported Files

This beta uses Gen1Recomp's modern **Imported Files** workflow.

Current beta flow:

1. Import/install **Stadium Overworld DX**.
2. In the Mod Manager, use this mod's **Imported Files** option.
3. Select your own legally obtained Pokémon Stadium (USA) v1.0 ROM.
4. Launch Pokémon Yellow/Red/Blue.
5. Open `Start → Options`.
6. If `STADIUM ROM FILE` says `IMPORT`, press confirm on that row to build/refresh the overworld model cache.
7. Once complete, the row should show `READY`.

Note: STADIUM_BATTLE_FX handles battle models/effects separately. Stadium Overworld DX focuses on overworld and follower Pokémon models.

---

## Battles

This mod does **not** try to own the modern battle presentation layer.

For battle Pokémon models, battle animations, cameras, effects, and Stadium-style battle presentation, use:

- STADIUM_BATTLE_FX

Stadium Overworld DX focuses on:

- overworld Pokémon
- follower Pokémon
- static overworld Pokémon compatibility work

---

## Legal / ROM Notice

No Pokémon Stadium ROM, Pokémon ROM, extracted Nintendo assets, or generated ROM-derived caches are included.

Users must provide their own legally obtained compatible Pokémon Stadium ROM.

Do not redistribute ROMs or generated ROM-derived cache files.

---

## Bug Reports

Please include:

- Gen1Recomp version
- DRAMALESS_SHAPE version
- STADIUM_BATTLE_FX version
- Other follower/overworld mods enabled
- Map/location
- Pokémon/species
- What happened
- Screenshot or video if possible

---

## Credits

Modern DRAMALESS v2 compatibility work and beta packaging by **Pewter Crunchy**.

Based on the original **3D Pokémon Sprites / Stadium Overworld Models** project by **randyadr**.

Includes/derives compatibility work from the DRAMALESS_SHAPE / Dramatic Shape ecosystem and related Stadium runtime files. See `CREDITS.md` and `LICENSE.md` for details.

---

## Official Pewter Crunchy Links

- https://pewtercrunchy.com
- https://discord.gg/kzqBWMqu6K
- https://twitch.tv/pewtercrunchy
- https://instagram.com/pewtercrunchy
- https://tiktok.com/@pewtercrunchy
- https://facebook.com/PewterCrunchy
- https://x.com/pewtercrunchy