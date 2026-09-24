# Stretheo

Privacy-first iOS stress monitoring using Apple Health and Apple Watch biometrics. Stress scoring runs on-device; no third-party analytics SDKs; optional iCloud sync and optional Sign in with Apple.

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 26+ |
| iOS deployment | 26.5+ |
| watchOS deployment | 26.5+ |
| Swift | 6 (strict concurrency) |

Physical iPhone + Apple Watch recommended for HealthKit and WatchConnectivity testing.

### Free Apple Developer account (default)

Paid-program capabilities are **off** via `Stretheo/Core/FeatureFlags.swift`:

```swift
static let iCloudSyncEnabled = false
static let signInWithAppleEnabled = false
```

The app runs fully on-device: local SwiftData, bundled article seeds, manual profile editing, HealthKit, and export. iCloud and Sign in with Apple UI are hidden; CloudKit APIs are not invoked.

`Stretheo/Stretheo.entitlements` omits iCloud and Sign in with Apple so the project signs on a free team. HealthKit entitlements remain.

### Enabling iCloud + Sign in with Apple (paid account)

1. Set both flags to `true` in `FeatureFlags.swift`.
2. Re-add to `Stretheo/Stretheo.entitlements`:
   - `com.apple.developer.icloud-container-identifiers` → `iCloud.com.zapreff.Stretheo`
   - `com.apple.developer.icloud-services` → `CloudKit`
   - `com.apple.developer.applesignin` → `Default`
3. Turn on **iCloud (CloudKit)** and **Sign in with Apple** for the Stretheo target in Xcode.
4. Restart the app after enabling iCloud sync in Settings (SwiftData CloudKit mode is fixed at launch).

## Bundle identifiers

| Component | Identifier |
|-----------|------------|
| iOS app | `com.zapreff.Stretheo` |
| watchOS app | `com.zapreff.Stretheo.watchkitapp` |
| HealthKit background (iOS) | HRV observer + `UIBackgroundModes: healthkit` (backup path) |
| HealthKit background (watchOS) | HRV observer + `.immediate` delivery + `WKBackgroundModes: processing` |
| CloudKit container | `iCloud.com.zapreff.Stretheo` |
| URL scheme | `stretheo://` |

## Quick start

1. Open `Stretheo.xcodeproj` in Xcode.
2. Select your **Development Team** for **Stretheo**, **StretheoWatch Watch App**, and test targets.
3. Enable capabilities on the **Stretheo** iOS target (see [Capabilities](#capabilities)).
4. Build and run **Stretheo** on a device (simulator has limited HealthKit).
5. Install **StretheoWatch Watch App** on a paired Apple Watch (see [Watch + iPhone background monitoring](#watch--iphone-background-monitoring-testing)).

## Project structure

```
Stretheo/                          # iOS app (synchronized root group)
├── StretheoApp.swift              # Entry, dual containers, BG tasks
├── AppDependencies.swift          # Composition root
├── Core/
│   ├── Data/                      # SwiftData models, repositories, CloudKit
│   ├── Domain/                    # Use cases, HealthInput, algorithms input
│   └── Services/                  # HealthKit, notifications, export, sync
├── DesignSystem/                  # Tokens, components, modifiers
├── Features/                      # Home, Mood, History, Articles, Settings, Onboarding
├── Navigation/                    # AppRouter, MainTabView, deep links
└── Resources/
    ├── PrivacyInfo.xcprivacy      # App Store privacy manifest
    └── Localizable.xcstrings      # All user-facing strings (205 keys)

Config/
├── Stretheo-Info.plist            # iOS Info.plist (not copied into app bundle)
└── StretheoWatch-Info.plist       # watchOS companion Info.plist

StretheoShared/                    # Compiled into iOS + watchOS targets
├── HealthInput.swift, StressResult.swift, StressAlgorithmEngine.swift
├── WatchConnectivityManager.swift, WatchConnectivityPayload.swift
└── StressDomainEnums.swift, StressReferenceRanges.swift

StretheoWatch Watch App/           # watchOS companion (do not rename target folder)
├── StretheoWatchApp.swift         # WC activate + WatchHealthManager on launch
├── WatchHealthManager.swift       # Primary background HRV pipeline on Watch
├── WatchHomeView.swift
├── WatchStressStore.swift
└── Complications/StressComplication.swift
```

## Architecture

```
SwiftUI Views → ViewModels (@Observable) → Use Cases → Repositories / Services → SwiftData (+ optional CloudKit)
```

- **Dual `ModelContainer`:** `UserData` (stress, mood, profile, logs; optional CloudKit private sync at launch) and `Articles` (local cache only).
- **`HealthKitManager`:** actor-isolated reads only.
- **`StressAlgorithmEngine`:** pure Swift, weighted HRV/HR/sleep/respiratory/activity scoring with age/sex calibration.
- **Watch-primary background:** `WatchHealthManager` on watchOS uses HRV `.immediate` background delivery, runs `StressAlgorithmEngine`, and sends results to iPhone via `WatchConnectivityManager` (`sendMessage` or `transferUserInfo`).
- **iPhone backup:** `HealthKitManager` + `BackgroundStressCoordinator` keep an hourly HRV observer when Health Sync is enabled (Watch not worn or not paired).
- **Zero third-party SPM packages.**

## Capabilities

Enable on the **Stretheo** iOS target in Xcode:

| Capability | Purpose |
|------------|---------|
| HealthKit | Read HRV, heart rate, sleep, respiratory rate, activity (backup + manual Measure Now) |
| HealthKit background delivery | iPhone backup path when Watch is unavailable |

Enable on the **StretheoWatch Watch App** target:

| Capability | Purpose |
|------------|---------|
| HealthKit | Read HRV, heart rate, respiratory rate, wrist temperature, activity on Watch |
| HealthKit background delivery | Required for `.immediate` HRV observer wake-ups |
| Background Modes | **Background processing** (`WKBackgroundModes: processing` in `Config/StretheoWatch-Info.plist`) |

After adding Watch HealthKit entitlements, **regenerate the watchOS provisioning profile** in Xcode (Signing & Capabilities) or signed builds will fail.
| iCloud / CloudKit | Optional — requires `FeatureFlags.iCloudSyncEnabled` and paid program |
| Sign in with Apple | Optional — requires `FeatureFlags.signInWithAppleEnabled` and paid program |
| Background Modes | **Background fetch**, **Background processing** (matches `UIBackgroundModes` in Info.plist) |
| Push Notifications | Not used for remote push; local notifications only |

### CloudKit Dashboard (articles)

Create a public **Article** record type with fields: `title`, `category`, `summary`, `content`, `author`, `publishedDate`, `imageURL`, `isFeatured`. If the type is missing, the app falls back to bundled seed articles in `Localizable.xcstrings`.

### Background tasks

Register `com.zapreff.Stretheo.stress.refresh` in the scheme’s **Background Fetch** debugger. Permitted identifiers are declared in `Config/Stretheo-Info.plist`.

## Info.plist (iOS)

`Config/Stretheo-Info.plist` is the target Info.plist (`GENERATE_INFOPLIST_FILE = NO` to avoid duplicate bundle copies from the synchronized `Stretheo/` folder). It includes:

- **NSHealthShareUsageDescription** / **NSHealthUpdateUsageDescription**
- **NSPhotoLibraryUsageDescription**
- **NSUserNotificationsUsageDescription**
- **CFBundleURLTypes** (`stretheo://home`, `stretheo://breathing`, etc.)
- **UIBackgroundModes:** `healthkit` (Watch sync wake; no BGAppRefresh polling)
- **ITSAppUsesNonExemptEncryption:** `false`

## Privacy manifest

`Stretheo/Resources/PrivacyInfo.xcprivacy` declares:

- **No tracking** (`NSPrivacyTracking` = false)
- **Collected data types** (App Functionality only, not linked, not used for tracking): Health & Fitness, Name, Email, Photos (profile avatar — all optional except health when user measures)
- **Required reason APIs:** UserDefaults (`CA92.1`), file timestamps (`C617.1`) for SwiftData / settings

No third-party analytics or advertising networks are integrated.

## Localization

All UI strings use `String(localized:)` with keys in `Stretheo/Resources/Localizable.xcstrings` (English source, 205 keys). Covers tabs, onboarding, errors, notifications, export PDF labels, mood scale, article seeds, and algorithm breakdown hints.

## iCloud sync

Opt in via **Settings → Data & Privacy → iCloud Sync**. Persists `AppSettings.iCloudSyncEnabled` and `UserProfile.iCloudSyncEnabled`.

**Restart the app** after toggling sync so `ModelContainer` is created with the correct CloudKit mode (`ModelContainerFactory` reads the flag at launch).

## Watch app

- **Primary background path:** `WatchHealthManager` observes HRV on the Watch, scores stress locally, saves to `WatchStressStore`, and sends payloads to iPhone.
- **Display sync:** iPhone pushes latest stress + profile calibration via `WCSession.updateApplicationContext` after manual **Measure Now** (Watch complication / home gauge).
- **WatchHomeView:** circular gauge, category, last updated time.
- **StressComplication:** WidgetKit provider (`StressComplicationWidget`); add a **Watch Widget Extension** target and set `@main` on `StretheoWatchWidgetBundle` to ship complications on watch faces.

`Config/StretheoWatch-Info.plist` sets `WKCompanionAppBundleIdentifier` to `com.zapreff.Stretheo`.

## Deep links

| URL | Action |
|-----|--------|
| `stretheo://home` | Home tab |
| `stretheo://breathing` | Full-screen breathing session |
| `stretheo://settings` | Settings tab |
| `stretheo://article/{uuid}` | Articles tab (article selection) |

## Testing

```bash
# iOS
xcodebuild -scheme Stretheo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# watchOS
xcodebuild -scheme "StretheoWatch Watch App" -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build

# Algorithm unit tests
xcodebuild -scheme Stretheo -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:StretheoTests test
```

### Watch + iPhone background monitoring (testing)

Use a **physical iPhone and paired Apple Watch** on the same Apple ID. Simulators do not provide real HRV background delivery or reliable WatchConnectivity.

#### Prerequisites

1. Install **Stretheo** on iPhone and **StretheoWatch Watch App** on the Watch from Xcode (Debug).
2. On iPhone: **Settings → Stretheo → Health** — allow read access for Heart Rate and Heart Rate Variability.
3. On Watch: approve the Health permission prompt when the watch app first launches (or in the Watch app’s Health settings).
4. In Stretheo **Settings**, enable **Health Sync** (keeps the iPhone backup observer; Watch path runs independently once the watch app has launched).
5. Confirm **StretheoWatch Watch App** signing includes HealthKit + HealthKit Background Delivery (regenerate the provisioning profile if Xcode reports missing entitlements).
6. Wear the Watch unlocked on the wrist; background HRV updates require normal Apple Watch health sampling (not available in Airplane Mode with sensors off).

#### End-to-end flow (what should happen)

1. New HRV is written on the Watch (passive measurement during the day).
2. HealthKit wakes **StretheoWatch** with `.immediate` background delivery.
3. `WatchHealthManager` reads Watch metrics, runs `StressAlgorithmEngine`, and calls `WatchConnectivityManager.sendStressResult`.
4. iPhone receives the payload via `sendMessage` (foreground/reachable) or `transferUserInfo` (queued when unreachable).
5. iPhone `saveFromWatch` persists a measurement with trigger **Watch** (`automaticWatch`), posts `.newMeasurementSaved`, and Home refreshes via `@Query`.

#### Step-by-step manual test

| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open **StretheoWatch** on the Watch once (foreground). | Console: `[Watch] HRV observer registered`, `[Watch] Background delivery: true`. |
| 2 | Open **Stretheo** on iPhone once. | Console: `[WatchConnectivity] Activated`, Health Sync enables backup observer if enabled. |
| 3 | Lock both devices; keep Watch on wrist for 30–60+ minutes (or after a walk/workout that produces HRV). | Watch may wake briefly for background processing (budget ~4 updates/hour with an active complication). |
| 4 | Open iPhone Stretheo → **Home**. | New check-in with **Watch** trigger pill; stress level matches Watch computation. |
| 5 | Optional: keep iPhone app killed (swipe away), repeat step 3, then reopen iPhone app. | Queued `transferUserInfo` should still deliver; measurement appears after launch. |

#### Console log markers (Xcode → Devices and Simulators → open device log, or run attached)

Filter for these prefixes while testing:

| Prefix | Device | Meaning |
|--------|--------|---------|
| `[Watch] New HRV data` | Watch | Observer fired |
| `[Watch] Computed stress:` | Watch | Algorithm finished |
| `[Watch] Sent stress result` / `Queued result` | Watch | Payload sent or queued |
| `[iPhone] Received Watch measurement` | iPhone | Handler received payload |
| `[HealthKit] HRV observer` | iPhone | Backup path only (not Watch-primary) |

#### Verify Watch → iPhone without waiting for passive HRV

Passive HRV timing is not deterministic. To confirm connectivity and persistence:

1. Run both apps attached to Xcode on the same Mac.
2. On Watch, ensure the watch app has run once so monitoring is registered.
3. Use **Measure Now** on iPhone to validate the reverse path (iPhone → Watch `applicationContext` updates the Watch gauge).
4. For Watch → iPhone, rely on logs in step 3 above after a real HRV sample, or set a breakpoint in `WatchHealthManager.handleNewHRVData()` and continue after a HealthKit sample arrives.

#### Troubleshooting

| Symptom | Check |
|---------|--------|
| No Watch measurements on iPhone | Watch app never launched after install; Health denied on Watch; Watch not on wrist; dedupe window (5 min) skipped a second save. |
| `Background delivery: false` on Watch | HealthKit Background Delivery entitlement or provisioning profile; rebuild after enabling capability. |
| iPhone only shows **Auto**, never **Watch** | Payload came from iPhone backup observer (`BackgroundStressCoordinator`), not Watch — confirm Watch logs and pairing. |
| Build fails on Watch target signing | Regenerate **iOS Team Provisioning Profile** for `com.zapreff.Stretheo.watchkitapp` with HealthKit enabled. |
| Home does not update until pull-to-refresh | Should not happen — confirm `.newMeasurementSaved` fires; check `saveFromWatch` error logs. |

#### Privacy / battery notes

- All scoring stays on-device; Watch sends only stress level, category, timestamp, and a small set of metric values in the WC payload.
- watchOS shares background refresh budget with complications (~4 wakes/hour with an active watch face complication); without a complication, background delivery may be less frequent.
- iPhone hourly HRV observer remains a **backup** and does not replace Watch-primary processing when the Watch is worn and paired.

## License

Proprietary — All rights reserved.
