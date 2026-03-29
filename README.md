# Pole

SwiftUI app for an iOS-first storage cleanup assistant (dashboard, storage breakdown, settings).

## Requirements

- **macOS** with **Xcode 16+**
- **iPhone or iPad** on **iOS 17+** (simulator or physical device)
- Optional: **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** if you change `project.yml` and need to regenerate the Xcode project (`brew install xcodegen`)

## Run locally (Simulator)

1. Clone the repository and open the project folder in Terminal.
2. If `Pole.xcodeproj` is missing or you edited `project.yml`, generate it:
   ```bash
   xcodegen generate
   ```
3. Open the project:
   ```bash
   open Pole.xcodeproj
   ```
4. In Xcode, select an **iOS Simulator** (e.g. iPhone 16) as the run destination.
5. Press **⌘R** (Product → Run).

## Run on your own iPhone or iPad

You need an **Apple ID** (free account works for personal device testing).

1. Complete the steps above so the project opens in Xcode.
2. Connect your device with a USB cable (or use a device on the same network for wireless debugging after pairing once).
3. In the Xcode toolbar, choose your **physical device** as the run destination (not a simulator).
4. Select the **Pole** target → **Signing & Capabilities**:
   - Enable **Automatically manage signing**.
   - Set **Team** to your Apple ID / personal team.
   - If the bundle identifier `com.victor.pole` is taken, change it under **Signing** (and match it in `project.yml` if you use XcodeGen, then run `xcodegen generate` again).
5. Press **⌘R** to build and install.
6. On the device, if prompted: **Settings → General → VPN & Device Management** → trust your developer certificate.
7. The first launch may ask for **Photos** (and other) permissions—grant them to exercise scanning features.

### Troubleshooting (device)

- **“Failed to register bundle identifier”**: Pick a unique bundle ID for your team in Signing settings.
- **Untrusted developer**: Trust the app under **Device Management** as above.
- **Could not launch**: Unlock the device, accept any “Trust This Computer?” prompts, and ensure the device’s iOS version is at least **17.0**.

## Development

- **Tests**: In Xcode, **⌘U** or Product → Test. CI may run `xcodebuild` with the **Pole** scheme (see `.github/workflows/` if present).
- **Project generation**: The repo includes `Pole.xcodeproj`. Regenerate with `xcodegen generate` only after changing `project.yml`.

## Repository layout

- `MoleiOS/` — Swift source, assets, app entry
- `PoleTests/` — unit tests
- `project.yml` — XcodeGen project definition

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for branch workflow, expectations, and how to submit changes.

## Additional docs

- `PRIVACY.md`
- `TELEMETRY.md`
- `TESTFLIGHT_CHECKLIST.md`
