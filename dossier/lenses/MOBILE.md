# Lens — Mobile

For native and cross-platform mobile work — iOS (Swift / SwiftUI),
Android (Kotlin / Compose), React Native, Flutter — where
simulator runs, snapshot images, and OS-version drift dominate.

## Surface vocabulary

- **Unit:** screen / view / widget (`OnboardingView`, `ProfileScreen`).
- **Output:** snapshot image, accessibility tree, navigation stack, native log line.
- **Contract:** view hierarchy + a11y labels + supported OS range + entitlements / permissions + bundle size.

## Specific gates (meta-gate extensions)

- **A11y label coverage.** Every interactive view has a label / `accessibilityLabel`. Meta-gate walks the view tree (or runs an a11y audit in tests).
- **Min OS version pinned.** `Info.plist` `LSMinimumSystemVersion` / `minSdk` declared; meta-gate asserts floor.
- **Entitlements / permissions allowlist.** App declares only the permissions it uses; meta-gate diffs `Info.plist` requests vs code.
- **Bundle / IPA / APK size budget.** Meta-gate parses build artefact size, asserts under floor.
- **Asset density coverage.** For every named asset, `1x/2x/3x` / `mdpi/hdpi/xhdpi/...` exist. Meta-gate.
- **Localizable strings completeness.** Every `Localizable.strings` key present in every supported locale. Meta-gate diffs key sets.
- **Dynamic Type support (iOS).** No fixed font size on body text. Meta-gate regex on `.font(.system(size:`.
- **No print() / NSLog in production.** Meta-gate greps; allow in test targets.

## Output rebaseline specifics

| Step            | Command                                                       |
| --------------- | ------------------------------------------------------------- |
| Build           | `xcodebuild -scheme App` / `./gradlew assembleDebug`          |
| Snapshot runner | `xcodebuild test` (with swift-snapshot-testing) / Paparazzi   |
| Unbaselined run | snapshot tests fail with image diffs                          |
| Read failures   | inspect `__Snapshots__/<test>.png` vs `_FailureDiffs/`        |
| Accept          | `record: true` flag (then back to false) / `recordMode = ALL` |

Goldens: `__Snapshots__/*.png`, `app/src/test/snapshots/images/*.png`.

## Probe specifics

- File: `_probe-<slug>Tests.swift` / `_probe<Slug>Test.kt`
- Runner: simulator-attached test target with verbose log
- Dump shape: print accessibility hierarchy, view-bounds, computed font, navigation stack, bundle path, locale.
- Common dump targets: `view.subviews.map(\.accessibilityIdentifier)`, `rootViewController.children`, current `Locale.current`, `UIScreen.main.scale`.

## Stack footguns

- **Simulator vs device snapshot drift.** Same code renders differently. → pin to simulator class in CI; meta-gate.
- **Dark-mode snapshot drift.** Snapshot taken in light mode locally; CI in dark. → snapshot both modes; meta-gate.
- **Locale-dependent snapshot.** Currency / date formatting bakes the runner's locale. → force `Locale(identifier: "en_US_POSIX")` in tests.
- **Async loading races snapshot.** Snapshot fires before image / data loaded. → wait on explicit signal (expectation), not fixed delay.
- **`@MainActor` test runs off-main.** State updates dropped. → annotate test method `@MainActor`.
- **Auto Layout vs SwiftUI sizing.** SwiftUI inspects intrinsic; Auto Layout doesn't. → snapshot under both layout systems if mixing.
- **Permissions prompt blocks first run.** Test waits for prompt. → grant permission via `xcrun simctl privacy` in test setup.
- **Keychain leaks across test runs.** Test #2 sees test #1's data. → reset keychain in `setUp`; meta-gate on Keychain access in non-test code.
- **Push notification entitlement signed but not used.** App Store rejects. → meta-gate on entitlements vs code use.
- **Background-mode `audio` left from old feature.** Battery drain warning. → meta-gate on `UIBackgroundModes`.

## Phase shape hint

Typical sub-phases for a mobile phase:

- P0 — snapshot test scaffold (fastlane / paparazzi / swift-snapshot-testing)
- P1 — meta-gates (a11y, entitlements, asset density, locale)
- P2 — dark-mode + Dynamic Type baseline
- P3 — feature work (per-screen TDD rounds with snapshots)
- P4 — bundle-size + perf gate
- P5 — release / cut + changeset (package variant for SDK; service variant for app)
