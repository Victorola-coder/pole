# Pole

SwiftUI starter codebase for an iOS-first "Mole-like" cleanup assistant.

## What is included

- SwiftUI app shell with tab navigation
- Dashboard with quick health indicators
- Storage breakdown screen (mock data)
- Settings screen scaffold
- MVVM-style folders ready for scaling
- XcodeGen config to generate an Xcode project

## Requirements

- Xcode 16+
- iOS 17+
- Optional: XcodeGen (`brew install xcodegen`)

## Run

1. Generate project:
   - `xcodegen generate`
2. Open:
   - `open Pole.xcodeproj`
3. Build and run on iOS Simulator.

## Notes

This codebase intentionally uses mock scanning data first so product flows can be built safely before wiring real Apple framework integrations like PhotoKit and FileProvider.

## Production docs

- `PRIVACY.md`
- `TELEMETRY.md`
- `TESTFLIGHT_CHECKLIST.md`
