# Recipe Haven — development checkpoint 2026-11-13

## Current edition policy in source

- **Babe 💛** is Android-only and opens on `made just for you babe 💛`.
- **For Mom and Dad** opens on `for mom and dad` and targets Android and iPhone/iOS.
- Both editions share **all five screens**: Find Recipes, My Cookbook, Add Recipe, Marijuana Cookbook, Find Ingredient.
- The original Standard flavor has been renamed to Mom and Dad but retains the original Android package ID for continuity; Babe has its own package ID. iOS has a distinct Mom and Dad bundle ID.

## Source changes performed

- Centralized edition rules with iOS-only Mom and Dad validation and specific title strings (`lib/config/edition.dart`).
- Unified the home screen and marijuana cookbook features in both editions; shared recipe saving, internet search and 30-km ingredient/store search.
- Added separate Mom and Dad welcome screen in `lib/main.dart`.
- Added Android Mom and Dad/Babe flavors and clearly named APK workflow (`scripts/configure_android_flavors.py`, `.github/workflows/android-apks.yml`).
- Added Mac bootstrap script with iOS app display name, stable bundle ID and foreground location description (`scripts/bootstrap_ios_momdad.sh`, `scripts/configure_ios_momdad.py`).
- Added a **Mom and Dad only** iOS simulator workflow (`.github/workflows/momdad-ios-simulator.yml`).
- Added edition tests (`test/edition_test.dart`).

## Verification status

- Local Python syntax and script smoke checks may be performed in this workspace.
- Flutter SDK, Xcode and iOS simulator are unavailable in the current container, so **no Flutter analysis, Dart tests, compiled Android APK, compiled iOS app, phone installation, or Apple-signed IPA is yet independently verified**.
- Neither live Google Places pricing nor automatic store catalog lookup is implemented. Maps links and retailer-site searches do not certify inventory or prices.
- No separate GitHub repository is currently connected/created for this app, so the workflows have not run on GitHub.

## Next milestone

Create `cruefan94/Recipe-Haven` separately from the Flipper projects; push this source; run the Android and unsigned iOS simulator GitHub Actions jobs; fix any CI errors; phone-test both editions; set up secure Android signing and real iOS signing/distribution. Review Apple's App Store policies regarding adult cannabis recipes before App Store submission.

## Flipper Android UI reference integration

The latest Flipper AI Android Satellite `fix/android-chat-continuity-secure-cloud-settings-v241` branch was inspected as a **design reference only**. Recipe Haven now uses a single dashboard of five cards, dedicated screens, a simple back route, dark/high-contrast surfaces and orange/amber accents. The Flutter codebase remains independent so Mom and Dad can build for iOS. This has not been Flutter-compiled in the current environment.
