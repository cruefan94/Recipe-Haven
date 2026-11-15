# Recipe Haven

**Two editions. One cooking platform.** The active product is **Recipe Haven for Android**; iPhone development remains on the roadmap after Android validation.

| Edition | Android launcher name | Cooking features | Separate personal cookbook | Current APK |
| --- | --- | --- | --- | --- |
| **Professional** | **Recipe Haven** | Recipes, offline recipes, cookbook, ingredient finder, substitutions, shopping list, backup/restore | **Not included. No visible references or entry points.** | **Next signed APK for phone testing** |
| **Full** | **Recipe Haven Full** | All Professional features | Includes a separate password-protected personal collection and its shopping list | Separate APK can be built later |

The Professional edition is suitable for workplace and general-purpose cooking contexts. It does not show the Full edition's extra collection in the home screen, Options, recipe entry, backup messaging, or navigation. Importing a backup containing unsupported collection entries is rejected with a neutral message before any data is changed; Professional exports only its everyday recipes and shopping items.

**The next downloadable APK is Professional only.** The Full edition remains implemented in shared Flutter source as a distinct Android flavor, but is not included in the next download artifact. Both editions can be installed side by side without mixing their private app storage.

## Android identities and signing

- Professional: `com.cruefan94.recipe_haven` — fresh-install package
- Full: `com.cruefan94.recipe_haven.full` — distinct package for future use

Both reuse the owner's existing permanent Android signing keystore through protected GitHub Actions secrets. Its contents and passwords are never committed. The build assigns increasing version codes. After the first Professional APK is installed, subsequent Professional builds with the same package ID and signer can be installed as in-place updates. Old experimental installation IDs are no longer distribution targets; Android doesn't migrate data between different package IDs automatically.

## Features shared by both editions

- Find Recipes: search online sources with title relevance filtering; see 18 original recipes offline.
- My Cookbook: save dishes with ingredients and instructions for offline use.
- Add Recipe: manual input and supported HTTPS recipe link import.
- Cook With What I Have: discover options using pantry ingredients.
- Shopping List: add groceries manually or from recipes; check items off offline.
- Find Ingredient: selectable 2, 5, 10, 20, 30 or 50 km distance, in-app public-store directory, fallback Google Maps and retailer searches; **no verified live product prices or inventory**.
- Ingredient Alternatives: context-specific offline substitution reference.
- Backup & Restore: validated full-kitchen JSON file/clipboard transfer; legacy cookbook-only JSON supported.
- Professional UI: cleaner Material 3 dark theme, Home / Find / Cookbook / Shopping navigation, responsive recipe cards and clearer store/shopping summaries.

## Build and test

The automatic [Professional Android APK workflow](.github/workflows/android-apks.yml) is triggered on the Android development branch. It runs Flutter analysis and tests, compiles one **permanently signed Professional APK** and checks its Android package ID and certificate against the existing private keystore before uploading the installer artifact.

**Download artifact:** `Recipe-Haven-Professional-Android-TEST`, containing `Recipe-Haven-Professional-Android-TEST.apk`.

Manual Flutter commands after `flutter pub get` and `bash scripts/bootstrap_android.sh`:

```bash
flutter analyze
flutter test
flutter build apk --debug --flavor professional --dart-define=RECIPE_HAVEN_EDITION=professional
flutter build apk --debug --flavor full --dart-define=RECIPE_HAVEN_EDITION=full
```

Production-key-signed release builds require the owner-managed private signing variables. Do not use a disposable debug key when distributing a Professional release with the same package ID.

The first Professional APK still needs **hands-on Android validation**: startup, cooking and recipe searches, Find Ingredient distance selector, nearby in-app store list, grocery checkoff, recipe saves, file-picker backups and imports. CI compilation does not certify actual device behavior.

## Future iPhone app

**iOS remains a planned platform, not an active release.** Future iPhone builds should carry the same two-edition product distinction, adapt Flutter screens and shared features to iOS, and complete Xcode signing, real-device testing, privacy review and TestFlight. Neither edition currently has a signed, installable iPhone IPA.

The repository retains an iOS preparation scaffold for future use. On macOS/Xcode, `bash scripts/bootstrap_ios.sh` sets the future shared Recipe Haven iPhone target; no iOS development should delay finishing Android.

## Next development priorities

1. Test the new Professional APK on a phone, including confirming the excluded feature is absent.
2. Fix any in-app grocery-store list gaps, keyboard flicker, layout clipping and search issues observed on Android.
3. Continue polish for professional everyday use and confirm reliable backups.
4. Preserve permanent-signing continuity for subsequent releases.
5. Release the Full edition separately after Professional is verified, then pursue iPhone support.

The Recipe Haven project is independent from the user's Flipper and other unrelated repositories.
