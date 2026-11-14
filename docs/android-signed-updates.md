# Stable Android APK signing — configuration for a future release

**Source-only setup. No release has been built or installed from this branch.** The manual GitHub workflow will become selectable on the default branch when the development branch is ready to merge.

## Why this matters

Every Android installation has a signing certificate. Future updates must use the **same application ID** and the **same signing certificate**, with a higher version code.

Recipe Haven retains two distinct application IDs:
- Mom and Dad: com.cruefan94.recipe_haven
- Babe: com.cruefan94.recipe_haven.babe

Both can share one securely backed-up signing keystore, while remaining independently installable apps.

The earlier GitHub debug APKs were signed using a temporary CI debug key. Those older APKs **cannot be updated in place** with the new release key. Users will need a one-time uninstall/install transition, so export and back up the cookbook first. Subsequent releases signed using the same keystore can install as updates.

## Prepare the signing key

Generate one long-lived Android keystore on a trusted personal machine and back it up securely. A possible example:

    keytool -genkeypair -v -keystore recipe-haven-release.jks -alias recipe-haven -keyalg RSA -keysize 3072 -validity 10000

Use strong private passwords. Never commit the keystore, passwords or base64 value into Git, a public issue, or this chat.

In your GitHub repository go to Settings > Secrets and variables > Actions and create these **repository secrets**:

1. RECIPE_HAVEN_RELEASE_KEYSTORE_B64: a single-line base64 encoding of the .jks bytes.
2. RECIPE_HAVEN_RELEASE_STORE_PASSWORD: keystore password.
3. RECIPE_HAVEN_RELEASE_KEY_ALIAS: alias chosen when generating the key.
4. RECIPE_HAVEN_RELEASE_KEY_PASSWORD: key password.

Keep a private backup of the keystore **and** passwords. Without the exact same key, Android will reject future in-place updates. If the key is lost, release continuity is lost.

## Workflow

The manual action at .github/workflows/android-signed-release.yml:
- downloads Flutter/Java dependencies;
- generates two Android flavors with scripts/bootstrap_android.sh;
- reads protected signing secrets into a temporary key file on the runner;
- generates separate release APKs for both editions using an increasing version code;
- uploads clearly labeled signed **unverified** APK artifacts for review.

The signing patch in scripts/configure_android_flavors.py only activates when RECIPE_HAVEN_RELEASE_KEYSTORE is present. The Android debug build flow remains unchanged.

**This is not an automatic release and it has not been verified.** Do not distribute as final production apps without compilation, signing-certificate verification, installation/upgrade checks and functional device testing.

## Security

Never add signing files to repository or workflow artifacts. Never print passwords or the base64 secret in logs. Only trusted people should have permission to trigger protected release workflows.

References: https://developer.android.com/studio/publish/app-signing
