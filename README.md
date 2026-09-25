# Simulator Location Sync

[繁體中文](README.zh-TW.md)

![Simulator Location Sync app icon](SimulatorLocationSync/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png)

A lightweight macOS menu bar app that periodically synchronizes your Mac's current location to every booted simulator in Xcode Device Hub.

## Features

- Lives entirely in the macOS menu bar and stays out of the Dock
- Uses Core Location to obtain the Mac's current location
- Automatically detects all booted and available simulators
- Synchronizes every 5 seconds, 10 seconds, 30 seconds, 1 minute, or 5 minutes
- Supports pausing automatic sync and triggering a sync manually
- Displays the latest coordinate, sync time, simulator count, and errors
- Runs natively on both Apple Silicon and Intel Macs

## Requirements

- macOS 13 or later
- Xcode with at least one Simulator runtime installed
- Location Services enabled for Simulator Location Sync

## Install a local build

1. Clone this repository.
2. Run the release build script:

   ```sh
   ./scripts/build-release.sh
   ```

3. Open `dist/SimulatorLocationSync.dmg`.
4. Drag **SimulatorLocationSync** into **Applications**.
5. Launch the app and allow location access when prompted.

After launch, the app appears only as a location icon in the menu bar. Start one or more simulators and the app will synchronize the location every 10 seconds by default.

You can also open `SimulatorLocationSync.xcodeproj` in Xcode, select **My Mac**, and run the app directly.

## How it works

The app obtains the Mac's location through Core Location, discovers booted simulators using:

```sh
xcrun simctl list devices booted --json
```

It then applies the coordinate to each simulator with:

```sh
xcrun simctl location <simulator-udid> set <latitude>,<longitude>
```

Location data stays on your Mac and is not sent over the network. App Sandbox is intentionally disabled because the app needs to execute Xcode's `simctl` command-line tool.

## Distribution

The build script creates a Universal App and signs it ad hoc for local use. Public GitHub releases should be signed with an Apple Developer ID certificate and notarized by Apple to avoid Gatekeeper warnings on other Macs.

## Project structure

```text
SimulatorLocationSync/          SwiftUI app source and assets
SimulatorLocationSync.xcodeproj Xcode project
scripts/build-release.sh        Universal App and DMG build script
```

## License

No license has been added yet. Add a license before accepting external contributions or redistributing the project.
