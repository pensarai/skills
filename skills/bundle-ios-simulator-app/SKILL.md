---
name: bundle-ios-simulator-app
description: Build a standalone iOS Simulator .app from an iOS project and package it as a shareable .tar.gz with a checksum, manifest, and run instructions, so a third party (e.g. a pentester or QA team) can install it on an Xcode simulator without source code, signing, or a dev server. Supports native Xcode (Swift/Objective-C, CocoaPods, SPM), React Native, Expo, Flutter, and Capacitor. Use when the user wants to share, export, hand off, or send an iOS simulator build, a .app bundle, or a test build for pentesting or QA.
---

# Bundle iOS Simulator App

Produce a self-contained iOS Simulator build that anyone with a Mac and Xcode can install with `xcrun simctl install`, without access to source, signing certificates, or a running Metro/dev server.

The deliverable is the output of [scripts/package-sim-app.sh](scripts/package-sim-app.sh):

```
dist/simulator/
  <App>-<version>-<build>-sim-<commit>-<timestamp>.tar.gz          # the .app, at the archive root
  <App>-<version>-<build>-sim-<commit>-<timestamp>.tar.gz.sha256
  <App>-<version>-<build>-sim-<commit>-<timestamp>.manifest.json  # bundle ID, version, archs, min iOS, commit
  RUN.md                                                          # install + launch instructions for the recipient
  xcodebuild.log
```

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 1: Identify the project type and app scheme
- [ ] Step 2: Confirm the build target environment with the user
- [ ] Step 3: Build and package
- [ ] Step 4: Verify on a simulator
- [ ] Step 5: Hand off
```

### Step 1: Identify the project type and app scheme

| Signal | Project type | Build path |
|--------|--------------|------------|
| `*.xcodeproj` / `*.xcworkspace`, no JS or Dart | Native | Script builds directly |
| `Podfile` | Uses CocoaPods | Run `pod install` first, then build the `.xcworkspace` (never the `.xcodeproj`) |
| `package.json` with `react-native`, `ios/` exists | React Native | `pod install` in `ios/`, then script builds the workspace |
| `package.json` with `expo` | Expo | See [Expo](#expo) |
| `pubspec.yaml` | Flutter | See [Flutter](#flutter) |
| `capacitor.config.*` | Capacitor | `npx cap sync ios`, then build `ios/App/App.xcworkspace`, scheme `App` |

Find the app scheme with `xcodebuild -list -workspace <path>` (or `-project`). Pods and SPM add many library schemes; the app scheme usually matches the app or project name. If unsure, the right scheme is the one whose `-showBuildSettings` has `WRAPPER_EXTENSION = app`.

### Step 2: Confirm the build target environment with the user

The recipient gets whatever is baked in at build time, so ask before building:

- **Backend environment**: Which API, auth provider, and analytics keys should the build point at (staging, production, a dedicated test environment)? Find where they are configured (xcconfig files, build configurations, `.env` / `EXPO_PUBLIC_*` variables, `--dart-define`, Info.plist keys) and make sure the build picks up the intended values.
- **Configuration**: Default to `Release`. JavaScript-based apps (React Native, Expo) must use Release so the JS bundle is embedded; Debug builds expect a Metro server. Use Debug for native apps only if the user wants debug-only features (logging, debug menus) or Debug is the only configuration wired to the right backend.
- **Test accounts**: Note any credentials, feature flags, or setup steps the recipient will need (for example, Sign in with Apple requires an Apple Account signed in to the simulator's Settings). Credentials go in a separate channel, never in the artifact.

### Step 3: Build and package

Run the script from the project directory (where `git rev-parse` resolves to the app's repo):

```bash
SCRIPT=<path-to-this-skill>/scripts/package-sim-app.sh

# Native / CocoaPods / React Native / Expo (after prebuild) / Capacitor
$SCRIPT --workspace ios/MyApp.xcworkspace --scheme MyApp
$SCRIPT --project MyApp.xcodeproj --scheme MyApp

# Package a .app or tarball produced by another tool (Flutter, EAS, Xcode GUI)
$SCRIPT --from path/to/MyApp.app
```

What the script does:
- Builds with `-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'` into `dist/simulator/.derived-data`, with `ARCHS="arm64 x86_64"` so the app runs on both Apple Silicon and Intel Macs.
- Rejects bundles that are not simulator builds (checks `DTPlatformName` in `Info.plist`); device builds and `.ipa` files cannot run on a simulator.
- Archives the `.app` at the tarball root and writes the checksum, manifest, and `RUN.md`.

Options: `--configuration Debug`, `--out DIR`, `--arm64-only`, `--smoke-test`, and anything after `--` is passed to `xcodebuild` (e.g. `-- MY_API_URL=https://staging.example.com`).

Add `dist/` (or the chosen `--out`) to the project's `.gitignore` if it isn't already.

#### Expo

Expo apps can be built locally with Xcode or with EAS.

**Locally with Xcode**: if `ios/` doesn't exist, run `npx expo prebuild --platform ios` (this generates native code; if the repo doesn't commit `ios/`, leave it untracked). Export the `EXPO_PUBLIC_*` variables for the target environment in the same shell, then run the script against `ios/<Name>.xcworkspace` with the app scheme. The JS bundling build phase reads those variables at build time.

**With EAS**: add a dedicated profile to `eas.json`:

```json
"simulator-share": {
  "distribution": "internal",
  "developmentClient": false,
  "ios": { "simulator": true },
  "env": { "EXPO_PUBLIC_API_URL": "https://staging.example.com" }
}
```

Run `eas build --platform ios --profile simulator-share --local --output build.tar.gz` (or drop `--local` and download the artifact), then package it with `$SCRIPT --from build.tar.gz`. `developmentClient: false` is required; dev-client builds open the Expo launcher instead of the app.

#### Flutter

Flutter only supports debug builds on the simulator. Pass environment config with `--dart-define`:

```bash
flutter build ios --simulator --dart-define=API_URL=https://staging.example.com
$SCRIPT --from build/ios/iphonesimulator/Runner.app
```

### Step 4: Verify on a simulator

Always run the smoke test before handing off. It extracts the tarball, installs the app on a booted (or the first available) iPhone simulator, launches it, and confirms it is still running after 8 seconds:

```bash
$SCRIPT --from dist/simulator/<artifact>.tar.gz --smoke-test
```

`--smoke-test` can also be added to the original build command. After it passes, take a screenshot (`xcrun simctl io booted screenshot /tmp/sim.png`) and check the app reached its first screen rather than an error or blank state.

### Step 5: Hand off

Tell the user what to send the recipient: the `.tar.gz`, its `.sha256`, and `RUN.md`. The manifest is for the user's records. Summarize the bundle ID, version, architectures, minimum iOS version, the backend environment the build points at, and any setup steps from Step 2.

Remind the user that a simulator `.app` is not encrypted: anyone who receives it can read every string, asset, and config value embedded in it (API keys, endpoints, feature flags). Only ship values that are safe for the recipient to see.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Signing for "X" requires a development team` | Simulator builds don't need a real identity. Retry with `-- CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=`. As a last resort use `-- CODE_SIGNING_ALLOWED=NO`, but entitlements (keychain sharing, app groups) are then dropped and keychain calls may fail at runtime. |
| `building for 'iOS-simulator', but linking in object file built for 'iOS'` or missing `x86_64` symbols | A binary dependency lacks an x86_64 simulator slice. Rebuild with `--arm64-only`; the build then won't run on Intel Macs, so tell the user. |
| `Unable to find module dependency` / Pods errors | Run `pod install` (or `bundle exec pod install`) in the directory with the `Podfile` and build the `.xcworkspace`. |
| App launches to a red screen or "No script URL provided" | React Native/Expo Debug build. Rebuild with `--configuration Release`. |
| App opens the Expo dev launcher | Built from a dev-client profile. Use an EAS profile with `"developmentClient": false`, or a Release Xcode build. |
| `was built for 'iphoneos', not the simulator` | The `.app` is a device build. Rebuild for the simulator; `.ipa` files and device builds can't be converted. |
| Smoke test: app exits right after launch | Check `~/Library/Logs/DiagnosticReports` for the crash, or stream logs with `xcrun simctl spawn booted log stream --predicate 'process == "<Executable>"'`. Missing env config is the usual cause. |
| `simctl install` fails on the recipient's Mac with a minimum OS error | Their simulator runtime is older than the app's `MinimumOSVersion` (in the manifest). They need a newer runtime from Xcode > Settings > Components. |
