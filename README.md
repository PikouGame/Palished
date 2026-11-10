# Palished

Small UI improvements for a smoother day in Palworld.

- **R** repairs the selected item at a repair bench.
- **Ctrl+R** opens the normal **Repair All** confirmation.
- Repair buttons show their keyboard shortcuts while preserving the game's current language.
- The main weapon tile shows Palworld's own fist and localized Unarmed name when you select your bare hands.
- A compact bar and percentage show the equipped tool's durability in the weapon HUD. Blue normally, orange below 30%, red below 10%.
- Accessory and Food slots align with Weapon, with consistent spacing between the three equipment sections.
- The right equipment column has evenly spaced groups, with Sphere Module's bottom aligned to the last accessory row.

Repair shortcuts only act in the repair-bench menu. Disabled buttons remain disabled, the pending-repair overlay blocks repeat requests, and the game/server keeps its normal repair costs. The HUD reads durability; it does not change it.

## Install

**Client only.** Requires a compatible [UE4SS Experimental (Palworld)](https://www.nexusmods.com/palworld/mods/2237) installation; no server mod is required. UE4SS is not bundled. The loader must provide `ExecuteInGameThreadWithDelay` and `LoopInGameThreadWithDelay` (available in the tested Palworld fork **2281fa31**); otherwise Palished stops at load with a message in the log.

1. Close Palworld. Extract the `Palished` folder into your existing UE4SS `Mods` folder, usually `Pal/Binaries/Win64/ue4ss/Mods/`.
2. Use the loader you already have. For a Workshop-installed UE4SS loader, its mod folder may instead be `Mods/NativeMods/UE4SS/Mods/`.
3. Keep the included `enabled.txt`. If your loader uses an explicit mods list, enable `Palished` there without replacing the other entries.
4. UE4SS hot reload uses Ctrl+R by default, which conflicts with Repair All. In your existing `UE4SS-settings.ini`, set `EnableHotReloadSystem = 0`, or change `HotReloadKey`.
5. Restart Palworld. Open a repair bench to use R or Ctrl+R; equip a tool to see its durability.

**Updating from 1.1.2 or earlier?** Delete the old mod folder and its line in the loader's mods list first, so that two copies never run together; see `INSTALL.txt`.

Remove only the `Palished` folder and its loader-list entry while the game is closed. No direct save or item edits are performed.

## Version and testing

Current release: **1.1.2-alpha**. Equipment alignment in both columns and the unarmed HUD were confirmed in game.
Tested on Palworld **1.0.5.102999**, UE4SS Palworld fork **2281fa31**, running Windows executables through Wine/Proton. The author confirmed R, Ctrl+R and the durability display in game. Automated checks cover menu/disabled-button guards, native repair routes, Ctrl priority, cooldown, localized button hints, the durability HUD, the unarmed icon and the equipment layout.

Not verified across other game/loader versions, native Windows OS installations, controller bindings, or other HUD mods. UI names may change in future game updates. The durability HUD is for the equipped tool/weapon, not every inventory item.

## Share your experience

We’d love to hear how Palished feels in your game! Leave a comment, share your experience, or [report a bug](https://github.com/PikouGame/Palished/issues) so we can investigate and improve it. For bugs, include your game/UE4SS versions, what you expected, and steps to reproduce. Remove personal information before sharing logs.

## Credits and permissions

Made with OpenAI Codex and Claude under lelorax's direction. The Lua code, tests and documentation are AI-generated. The author tested the mod in game. The screenshot is actual gameplay, not generated imagery. No AI service runs inside the mod.

Unofficial Palworld mod, not affiliated with Pocketpair. All rights reserved; download and use are allowed. Reuploads, published modifications and reuse require permission. See [LICENSE.txt](LICENSE.txt).

## Build

```sh
lua tests/test_repair.lua ./
lua tests/test_durability.lua ./
lua tests/test_unarmed.lua ./
lua tests/test_equipment_layout.lua ./
python3 tools/package.py
```

The archive contains only the mod's Lua scripts, enable marker, installation notes and license. Development tools and game assets are not bundled.
