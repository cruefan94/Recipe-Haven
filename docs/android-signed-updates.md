# Babe Android — update continuity without deleting the old app

## What we verified

Two previously generated Babe debug APKs were examined. Their APK v2 signing certificate SHA-256 fingerprints are different:

- Original test build: `06d32dc17e70e371309ce062b2153437453c94f3004e910cb262d3ae5d63cdd9`
- Later test build: `17077c58f65e1a09267f19a33d23d3abe4108e169dfc2fcbd15884b2649c8c76`

Android requires the **same package ID and signing certificate** to install an APK as an update. The earlier GitHub Actions debug private keys have not been retained, so there is no supported way to replace the existing APK in place with a differently signed APK. Raising versionCode does not fix signing mismatches.

## Keep the existing app and recipes

The previously installed Babe test package is `com.cruefan94.recipe_haven.babe`.

The new Babe Stable flavor has package ID `com.cruefan94.recipe_haven.babe.stable` and a temporary app label **Recipe Haven 💛 New**.

A separate package ID means **both apps can coexist**. No uninstall is necessary to install Babe Stable. Storage is isolated: Android does not automatically transfer app data between package IDs.

Migration after a signed Babe Stable APK exists:

1. Leave the existing Babe app installed.
2. Open **Backup & Restore** in the old app. Export the JSON cookbook backup (or copy the text into a private note). Keep this file private.
3. Open **Shopping List → Copy to share** if you need saved grocery items. The current cookbook JSON does not contain shopping-list data.
4. Install signed Babe Stable. It appears as **Recipe Haven 💛 New** alongside the old app.
5. In Babe Stable, import the cookbook JSON file, then confirm the saved recipes. Shopping items can be entered or copied manually.
6. Keep the old app unless and until you choose to remove it. Later Babe Stable APKs signed with the **same** permanent key can install in place over Babe Stable.

## Signing secrets required before first Stable APK

Create a long-lived keystore on a trusted computer. For example:

`keytool -genkeypair -v -keystore recipe-haven-release.jks -alias recipe-haven -keyalg RSA -keysize 3072 -validity 10000`

Back up the keystore and its passwords **privately**. Do not commit or send private keys or passwords to this chat.

In GitHub Settings → Secrets and variables → Actions, add:

- `RECIPE_HAVEN_RELEASE_KEYSTORE_B64` — single-line base64 of the JKS keystore
- `RECIPE_HAVEN_RELEASE_STORE_PASSWORD`
- `RECIPE_HAVEN_RELEASE_KEY_ALIAS`
- `RECIPE_HAVEN_RELEASE_KEY_PASSWORD`

The `.github/workflows/android-signed-release.yml` workflow only runs by manual dispatch. It builds **Babe Stable only**, checks Flutter analysis/tests, verifies APK signatures and publishes the signed APK artifact. Its build number increases with the GitHub workflow run number.

Keep the secrets **unchanged** for future releases. The GitHub connector cannot configure Secrets and the signing key has not been supplied yet, so **a stable signed APK is not available yet**.

## Current development scope

The automatic Android test workflow builds **Babe only**. The other editions remain in the source tree but are paused. Test APKs still use ephemeral GitHub debug keys, so they are for installation/testing only and may not update one another.

Do not claim successful stable in-place upgrades until two consecutively signed Babe Stable APKs have been installed as an update on a real device and its cookbook has been preserved.
