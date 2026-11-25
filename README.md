# Catan Map — board generator for macOS and iPhone

A single SwiftUI app (one target) for Mac and iPhone/iPad. The app's UI is in Ukrainian.

## How to run
1. Unpack the archive and open `CatanMap.xcodeproj` in **Xcode 16 or newer**.
2. **Mac:** choose the *CatanMap → My Mac* scheme and press ⌘R.
3. **iPhone:** in the target settings (*Signing & Capabilities*), pick your Team (a free Apple ID works) and, if needed, change the Bundle Identifier (`com.example.CatanMap`) to your own unique one. Connect your iPhone and press ⌘R.

Requires: iOS 17+ / macOS 14+.

## Features
**Map**
- Board for 3–4 players (19 hexes) and for 5–6 players (30 hexes), with 3:1 and 2:1 harbors.
- Rule-based generator: no adjacent 6 and 8, no adjacent identical numbers, rare numbers (2, 3, 11, 12) don't cluster, no adjacent identical resources, equal resource probability, limit on "hot" intersections, desert in the center.
- Classic A–R spiral from the game rules + **starter map for beginners**.
- Presets: Tournament / Classic / Chaos.
- **Map code** (e.g. `S3F12-K9X2QA`): open the same map on any device.
- **Balance score 0–100** with an explanation of what's good and what's bad.
- **Intersection heat map** and **top 6 settlement spots** (accounting for the distance rule and harbors).
- Probability chart for each resource.
- Manual editing: swap tiles or numbers, place the robber.
- Export the map image via Share.

**Dice**
- Animated dice (with haptic feedback on iPhone); on Mac, roll with Space.
- "36-card deck" mode: a fair distribution without streaks of bad luck.
- Highlights hexes on the map that produce resources for the rolled number, taking the robber into account.
- Players, colors, turn order, random first player.
- Histogram of rolls compared with theoretical probability.

**History**
- Last 50 maps + favorites (★). Swipe or context menu for actions.

## Structure
- `Models.swift`: types, map codes, persistence
- `BoardLayout.swift`: hex, intersection and coastline geometry
- `BoardGenerator.swift`: deterministic generator (SplitMix64)
- `BoardAnalysis.swift`: balance and best-spot analysis
- `BoardView.swift`: map rendering (Canvas)
- `MapScreen.swift`, `DiceScreen.swift`, `HistoryScreen.swift`, `SettingsView.swift`: screens
