# DorqUtilities

DorqUtilities is a lightweight World of Warcraft addon for Midnight `12.0.7`.
It focuses on a small set of practical dungeon alerts and quality-of-life tools.

## Features

### Low Resource Alerts

DorqUtilities shows a large notification and warning sound when your health or
mana drops below the configured threshold.

- Low health warning for all classes.
- Low mana warning for mana-using classes.
- Repeat delay protection so the same warning does not spam continuously.

### Bloodlust Ready Alert

In dungeon and Mythic+ contexts, DorqUtilities can show a static `BL READY`
message when your character or pet can provide a Bloodlust-style effect.

The alert checks for class and pet access where relevant, and hides while you are
locked out by effects such as Sated, Exhaustion, Temporal Displacement, Insanity,
or Fatigued.

### Combat Potion Ready Alert

DorqUtilities can show a static `POT READY` message for DPS players in dungeon
and Mythic+ contexts when a tracked Midnight combat potion is in your bags and
ready to use.

### M+ / Raid Loadout Warning

DorqUtilities can show a static top-screen warning when your current equipment
set or selected talent loadout does not match the current M+ or raid context.

The warning only activates when you have relevant presets:

- In Mythic+, equipment sets and talent loadouts with `mp` in their names are
  treated as M+ presets.
- In raids, equipment sets and talent loadouts with `raid` in their names are
  treated as raid presets.

For example, if you are in a raid and have a talent loadout named
`raid no interrupt`, the alert expects that saved raid loadout to be selected.

### Black Attunement Warning

Augmentation Evokers with Draconic Attunements talented can show a static
top-screen warning when Black Attunement is not active.

The aura check is skipped unless you are currently Augmentation and the talent is
selected.

### Ebon Might Tracker

Augmentation Evokers can show a cursor-following Ebon Might reminder. The icon
appears when Ebon Might is missing in combat or when the shortest remaining
Ebon Might buff is inside its `4` second refresh window. The window accounts for
Ebon Might's `3` second pandemic period plus roughly `1` second of cast time.

### Warcraft Logs Profile Helper

Player context menus include a `Copy Warcraft Logs Profile` option when
DorqUtilities can resolve the player's character and realm. The option opens a
copyable Warcraft Logs character URL.

Supported menu contexts include target, party, raid, friends, guild,
Battle.net friends, LFG search results, and applicant entries when the game API
provides enough character information.

### Sound Channel Override

DorqUtilities can keep WoW's `Sound_NumChannels` CVar set to exactly `96`. This
overrides other addons that raise or lower the value.

### Feature Toggles

Open the DorqUtilities settings panel with:

```text
/dorq
```

The settings panel lets you enable or disable:

- Low health warning
- Low mana warning
- Bloodlust ready alert
- Combat potion ready alert
- M+ / raid loadout warning
- Black Attunement warning
- Ebon Might tracker
- Warcraft Logs context menu
- Sound channel override

It also includes a `Reset Toggles` button to restore the default feature states.

## Debug Commands

```text
/dorq bl
/dorq pot
/dorq loadout
/dorq sound
/dorq ebon
/dorq black
```

## Supported Game Version

DorqUtilities currently supports only World of Warcraft: Midnight `12.0.7`.

The TOC interface is:

```text
120007
```

## Bundled Media

DorqUtilities ships only the alert sounds used by the default low health and low
mana warnings.
