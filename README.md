# Recipe Haven

**One cooking and shopping app. No editions.**

**Active platform:** Android. All current feature development, on-device testing, bug fixes, downloads and release work target Recipe Haven for Android.

**Future platform:** iPhone / iOS. The same Recipe Haven experience is planned after the Android app is stable. The Flutter source and iOS bootstrap scripts are retained; a signed iPhone IPA, TestFlight release and App Store listing have **not** been created.

## Features

- **Find Recipes:** search recipes from available online sources and filter irrelevant dishes; 18 original step-by-step offline starter recipes are bundled.
- **My Cookbook:** save complete recipes, links, ingredients and cooking steps for offline use.
- **Add Recipe:** enter your own recipes or import supported HTTPS pages.
- **Cook With What I Have:** explore recipes based on pantry ingredients, including offline choices.
- **Shopping List:** add ingredients or manual grocery items and check them off without internet.
- **Find Ingredient:** selectable 2, 5, 10, 20, 30 or 50 km grocery-store search; a community-map directory and external Google Maps/retailer search fallbacks. Store listings **do not confirm product availability, inventory, price or size**.
- **Ingredient Alternatives:** offline suggestions with approximate substitution amounts and limitations.
- **Backup & Restore:** portable JSON full-kitchen backups, and import of earlier cookbook-only JSON files.
- **Private Cookbook:** a separate personal collection accessible from Options with a user-set password, not shown on the public home screen.

The Android UI uses the **Recipe Haven** name, one consistent dark theme, and Home / Find / Cookbook / Shopping navigation.

## Fresh Android APK for direct testing

The user explicitly requested a fresh installation and reported deleting the previous testing app. There is now **one Android application ID**:

`com.cruefan94.recipe_haven`

Older experimental Android package IDs are no longer release targets. This is a **new installation**, not an in-place update of any old package. Android does not automatically transfer the old app's private storage; only an existing exported JSON backup can be imported. The public-facing label is **Recipe Haven**.

The workflow [Recipe Haven — Fresh Android APK (Signed Test)](.github/workflows/android-apks.yml) runs on the active development branch. It analyzes, tests, builds one **release-signed** Android APK using the existing owner-supplied GitHub Actions signing secrets, verifies its package ID and public signing certificate, and publishes:

**`Recipe-Haven-Android-FRESH-INSTALL.apk`**

under the **Recipe-Haven-Android-FRESH-INSTALL** Actions artifact. The keystore and passwords are stored only as GitHub Secrets; they are not checked into Git. The existing permanent key is reused and must **not** be regenerated. Later releases should retain this new package ID and signing certificate for smooth updates.

The first new installer requires Android phone testing before being described as fully verified. Use the app to save recipes, check the shopping list, change the Find Ingredient radius, check nearby-store fallbacks, use backups, and open Offline Recipes.

## Run Android locally

Requires Flutter and the Android SDK:

```bash
flutter pub get
bash scripts/bootstrap_android.sh
flutter analyze
flutter test
flutter build apk --debug
```

For a signed release, load the owner's permanent signing keystore and password environment variables and run `flutter build apk --release`.

## Future iPhone roadmap

The future iPhone release will share the **Recipe Haven** brand and feature set; there will be no separate family or personalized edition.

Planned steps are adapting platform-specific file import, local storage, external links, sharing and foreground location; then testing on an iPhone, adding Apple privacy disclosures, configuring signing and provisioning, running TestFlight, and preparing for App Store review. Nothing is currently released for iPhone.

Optional iOS simulator bootstrap on a Mac with Xcode:

```bash
flutter pub get
bash scripts/bootstrap_ios.sh
flutter build ios --simulator --debug --no-codesign
```

The reserved iOS bundle identifier is `com.cruefan94.recipehaven`, iOS 14.0+. An iOS simulator build is **not** a device-installable IPA.

## Roadmap and limitations

1. Complete fresh Android phone installation and feature verification.
2. Further improve reliability of the in-app store directory, small-screen layout, keyboard behavior and usability.
3. Integrate authorized retailer product catalogs where available; never invent stock or prices.
4. Preserve permanent Android signing continuity for future APK upgrades and eventual store distribution.
5. Develop and test the future unified Recipe Haven iPhone application after Android completion.

All saved recipe and shopping information is local unless explicitly exported or shared. Location is requested only when searching for nearby stores. TheMealDB and other external providers may have commercial licensing restrictions that require review before a broader store launch.

**Active branch:** [Android development](https://github.com/cruefan94/Recipe-Haven/tree/feature/ingredient-products-and-cookbook-backup). The default branch is used for project coordination and the signed-release entry point until the current testing milestone is approved.
