# aj-hud

A NoPixel 4.0–style HUD for QBCore: status pills, a segmented speed/fuel gauge, a key-hint bar, a round minimap with N/E/S/W letters, a heading box, and zone/street names. Every option can be changed in-game from a settings menu.

---

## Features

**Player status (bottom-left)**
- Mic badge. The ring changes color while you talk (yellow) or use the radio (red), and the icon switches to a headset on a radio channel.
- **HEALTH / ARMOR** pills fill with white to match the value. At 0 a pill turns solid dark, and it turns red when you are dead.
- A thin bar with an icon under each pill shows hunger, thirst, stress and oxygen.
- ENGINE and NOS pills appear only in a vehicle.
- Status chips for armed, harness, cruise, parachute and dev mode.

**Vehicle**
- An SVG speed gauge with a cyan segmented fill and a separate fuel arc on the right. The fuel arc turns orange below 30% and red below 20%.
- Gear badge: `N` when stopped, `R` in reverse, otherwise the gear number.
- Zero-padded speed readout (`087`) with dimmed leading zeros. The unit is MPH or KPH, set in config.
- Key-hint bar for the driver: `L` Vehicle Lock, `H` Headlights, `E` Horn, `F` Exit. The `L` hint appears only if you have the keys.
- Clickable round buttons for headlights, seatbelt and door lock. Hold **ALT** while driving to get a cursor without losing steering.
- Altitude readout in helicopters and planes.

**Map & compass (top-right)**
- A round or square minimap with a dark ring frame.
- N/E/S/W letters ride the ring and rotate with the camera.
- A `072°` heading box above the map, which can show `NE`-style letters instead.
- Zone and street name under the map, for example **ALTA / OCCUPATION AVENUE**.

**Other**
- Cash and bank pills with +/− change animations.
- A stress system: gained from speeding and shooting, with blur and ragdoll effects at high stress.
- Cinematic mode (black bars, HUD hidden).
- Every size is in `vh`, so the layout scales to any 16:9 resolution.

---

## Requirements

| Resource | Why |
|---|---|
| `qb-core` | Player data, callbacks, notifications |
| `pma-voice` | Talking range and radio state for the mic badge |
| `qb-fuel` (or any resource that `provide`s `LegacyFuel`) | Fuel level. If it is missing, the HUD falls back to the native fuel value |
| `interact-sound` | Menu and alert sounds (optional) |
| `qb-smallresources` | Seatbelt, cruise and harness events, plus the `toggleseatbelt` command |
| `qb-vehiclekeys` | Lock hint and lock button (optional) |

The HUD uses Vue 3, jQuery and Font Awesome from public CDNs, so clients need internet access for icons and scripts.

---

## Installation

1. Put the `aj-hud` folder in your resources, e.g. `resources/[aj]/aj-hud`.
2. Make sure it starts **after** `qb-core`, e.g. `ensure [qb]` before `ensure [aj]` in `server.cfg`.
3. Restart the server, or run `ensure aj-hud`.

---

## Commands & keybinds

| Key / command | What it does |
|---|---|
| **I** / `/hudmenu` | Open the settings menu (key set by `Config.OpenMenu`) |
| **LALT** | Toggle a mouse cursor while driving to click the HUD buttons |
| `/resethud` | Reload the HUD in place |
| `/cash` · `/bank` | Show your cash or bank balance |
| `/dev` | Toggle dev mode (admin only) |

Players can rebind the keys in **GTA Settings → Key Bindings → FiveM**.

---

## Settings menu

Open it with **I**. Changes apply instantly and are saved per player using client KVP.

| Tab | Options |
|---|---|
| **Minimap** | Minimap on/off · Round or square · Frame · N/E/S/W letters · Only in vehicle |
| **Compass & Streets** | Heading box · Degrees vs. letters · Zone & street names · Follow camera · Only in vehicle |
| **Status Bars** | Always show health, armor, hunger, thirst, stress, oxygen, engine, nitro (off = only when relevant) |
| **Display** | Optimized HUD refresh · Optimized compass · Cinematic mode |
| **Sound & Alerts** | Menu, click and reset sounds · Low fuel alert · Minimap and cinematic notifications |

- **Search** filters across all tabs.
- **Reload HUD** refreshes the HUD in place.
- **Reset to defaults** takes two clicks to confirm and restores `Config.Menu` from `config.lua`.

---

## Configuration (`config.lua`)

| Option | Default | Description |
|---|---|---|
| `Config.OpenMenu` | `'I'` | Default key for the settings menu |
| `Config.UseMPH` | `false` | `true` = MPH, `false` = KPH. The gauge label updates automatically |
| `Config.DisableStress` | `false` | Turn the stress system off completely |
| `Config.StressChance` | `0.1` | Chance (0–1) to gain stress per shot |
| `Config.MinimumStress` | `50` | Stress level where screen effects start |
| `Config.MinimumSpeed` / `MinimumSpeedUnbuckled` | `100` / `50` | Speed that causes stress, buckled or unbuckled |
| `Config.WhitelistedWeaponArmed` | melee, throwables… | Weapons that don't show the *armed* chip |
| `Config.WhitelistedWeaponStress` | petrol can… | Weapons that don't cause stress |
| `Config.VehClassStress` | per class | Vehicle classes that cause speeding stress |
| `Config.WhitelistedJobs` | `leo`, `ambulance` | Jobs or job types that never gain stress |
| `Config.Theme` | see file | Accent color plus OK/warn/critical colors and thresholds |
| `Config.Menu` | see file | **Default** value of every settings-menu option for new players |

### Theme

`Config.Theme.accent` colors the speed gauge, menu highlights and glows. Any hex color works, e.g. `'#00E5FF'`. Status colors and thresholds, such as fuel `warnBelow = 30` and `criticalBelow = 20`, are in the same table. You don't need to edit any CSS.

> Players who already have saved settings keep their own values. Changing `Config.Menu` only affects new players, or players who press **Reset to defaults**.

---

## Events for other resources

**Client events (trigger on the client):**

| Event | Arguments | Purpose |
|---|---|---|
| `hud:client:UpdateNeeds` | `hunger, thirst` | Update the hunger/thirst bars (qb-core sends this) |
| `hud:client:UpdateStress` | `stress` | Update the stress bar |
| `hud:client:UpdateNitrous` | `level, isActive` | NOS pill level and active (red) state |
| `hud:client:UpdateHarness` | `harnessHp` | Harness durability |
| `hud:client:ShowAccounts` | `'cash'|'bank', amount` | Briefly show a balance |
| `hud:client:OnMoneyChange` | `'cash'|'bank', amount, isMinus` | +/− money animation |
| `hud:client:ToggleAirHud` | – | Toggle the altitude readout |
| `hud:client:ToggleShowSeatbelt` | – | Toggle the seatbelt button |
| `hud:client:LoadMap` | – | Re-apply the minimap shape and position |
| `seatbelt:client:ToggleSeatbelt` / `seatbelt:client:ToggleCruise` | – | Sent by qb-smallresources |

**Server events:**

| Event | Arguments | Purpose |
|---|---|---|
| `hud:server:GainStress` | `amount` | Add stress to the source player |
| `hud:server:RelieveStress` | `amount` (1–100) | Remove stress, e.g. from food, weed or relaxing items |

Example: relieve stress from an item.

```lua
TriggerServerEvent('hud:server:RelieveStress', math.random(10, 20))
```

---

## File layout

```
aj-hud/
├── client.lua        HUD loops, minimap placement, menu callbacks, settings save/load
├── server.lua        /cash /bank /dev, stress events, menu defaults callback
├── config.lua        All options (see above)
├── locales/          Notification texts (en, fa, de, …)
├── stream/           Round and square minimap masks (circlemap/squaremap .ytd)
└── html/
    ├── index.html    HUD + settings menu markup (Vue 3)
    ├── app.js        HUD logic, gauge math, menu definitions (MENU_TABS)
    ├── theme.css     Color tokens (overwritten from Config.Theme)
    ├── styles.css    HUD and menu styles
    └── responsive.css  Minimap frame position
```

---

## Troubleshooting

- **The ring frame isn't exactly on the minimap.** The native minimap position comes from `ApplyMinimapPosition` in `client.lua`. The HTML frame position is in `html/responsive.css` (`.circle` / `.square` → `top`, `right`, `width`, `height`, all in `vh`). Adjust them in-game until the two line up.
- **Icons are empty squares.** The client couldn't reach the Font Awesome CDN (internet or firewall).
- **The minimap is still square for a player.** They have an old saved setting. Saves made before the NoPixel update are migrated to round automatically on the next load; otherwise use **Round minimap** in the menu, or **Reset to defaults**.
- **The fuel arc shows 0.** Check that `qb-fuel` (or another `LegacyFuel` provider) is started before `aj-hud`.
- **Don't add `backdrop-filter` to the CSS.** FiveM's browser renders it as solid black over the game.
`html/responsive.css`.
