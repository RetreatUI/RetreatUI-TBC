# RetreatUI TBC

RetreatUI for World of Warcraft: The Burning Crusade Classic Anniversary.

This repository is the standalone TBC edition of RetreatUI. It is intentionally separated from the Conquest of Azeroth addon repository so TBC can use its own addon structure, release cadence, installer logic and profiles without affecting CoA.

## Current status

Beta. The Druid HUD is delivered as real WeakAuras displays created and updated by the RetreatUI installer through the WeakAuras data API. The old native Druid runtime has been removed.

The three HUD layers use the same live RetreatUI CoA center-HUD geometry between the ElvUI player and target frames:

- Resource bar: X 0 / Y -152, 360 × 16
- Main ability row: X 0 / Y -183, 38 px icons
- Utility row: X 0 / Y -224, 32 px icons
- Ability spacing: 1 px

The WeakAuras package also uses the RetreatUI ElvUI font/texture family, follows the current Druid power/form, resolves learned ranks by spell name, tracks cooldowns and player/target auras, and verifies the installed WeakAuras hierarchy and root geometry before the installer reports success.

ElvUI and Details integration are included. Plater remains optional and is only offered when an embedded profile is available.

## Installation

Use the RetreatUI Launcher and select **The Burning Crusade**. Manual beta builds install the `RetreatUI` folder into the TBC Anniversary `Interface/AddOns` directory.

For the Druid HUD, enable WeakAuras before running `/ruitbc`, leave **Druid WeakAuras HUD** enabled, choose **INSTALL SELECTED**, then reload the UI.

## Author

Retreat
