# RetreatUI TBC

RetreatUI for World of Warcraft: The Burning Crusade Classic Anniversary.

This repository is the standalone TBC edition of RetreatUI. It is intentionally separated from the Conquest of Azeroth addon repository so TBC can use its own addon structure, release cadence, installer logic and profiles without affecting CoA.

## Current status

Beta. The Druid HUD is delivered as real WeakAuras displays created and updated by the RetreatUI installer through the WeakAuras data API. The old native Druid runtime has been removed.

The three HUD layers are centered in the same screen space used by RetreatUI CoA between the ElvUI player and target frames:

- Resource bar: center X, HUD root +44 Y
- Main ability row: center X, HUD root +12 Y
- Utility row: center X, HUD root -25 Y

With the default RetreatUI HUD root Y of 27, that resolves to Y 71, 39 and 2. The package tracks the current Druid power/form, learned spell ranks, cooldowns and player/target auras and verifies the installed WeakAuras hierarchy and geometry before the installer reports success.

ElvUI and Details integration are included. Plater remains optional and is only offered when an embedded profile is available.

## Installation

Use the RetreatUI Launcher and select **The Burning Crusade**. Manual beta builds install the `RetreatUI` folder into the TBC Anniversary `Interface/AddOns` directory.

For the Druid HUD, enable WeakAuras before running `/ruitbc`, leave **Druid WeakAuras HUD** enabled, choose **INSTALL SELECTED**, then reload the UI.

## Author

Retreat
