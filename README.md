# DorqUtilities

DorqUtilities is a lightweight World of Warcraft addon for Midnight `12.0.7`.
It focuses on a small set of practical dungeon alerts and quality-of-life tools.

## Features

### Low Resource Alerts

DorqUtilities shows MSBT-style scrolling warnings when your health or mana drops
below the configured threshold. The defaults include bundled warning sounds and
large notification text.

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

### Warcraft Logs Profile Helper

Player context menus include a `Copy Warcraft Logs Profile` option when
DorqUtilities can resolve the player's character and realm. The option opens a
copyable Warcraft Logs character URL.

Supported menu contexts include target, party, raid, friends, guild,
Battle.net friends, LFG search results, and applicant entries when the game API
provides enough character information.

### Feature Toggles

Open the DorqUtilities settings panel with:

```text
/dorqutilities
```

The settings panel lets you enable or disable:

- Low health warning
- Low mana warning
- Bloodlust ready alert
- Combat potion ready alert
- Warcraft Logs context menu

It also includes a `Reset Toggles` button to restore the default feature states.

## Debug Commands

```text
/dorqutilities bl
/dorqutilities pot
/dorqutilities bltest
```

## Supported Game Version

DorqUtilities currently supports only World of Warcraft: Midnight `12.0.7`.

The TOC interface is:

```text
120007
```

## Bundled Libraries and Media

DorqUtilities embeds `LibStub`, `CallbackHandler-1.0`, and
`LibSharedMedia-3.0`. It also ships bundled fonts and alert sounds used by the
default notification styles.
