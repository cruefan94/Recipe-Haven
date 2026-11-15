# Babe 💛 Stable — permanent signing setup

## Current status

The default-branch manual release workflow now exists in .github/workflows/babe-stable-release.yml. It runs only after the owner clicks Run workflow and explicitly confirms the private key was backed up. It checks out the Babe Android development branch, analyzes and tests the app, builds a signed release, verifies the Android package ID and APK certificate fingerprint against the provided keystore, and publishes the APK artifact.

The permanent secrets have NOT been confirmed or created by the assistant. The release refuses to build without all four secrets.

## Why the existing Babe app cannot be updated directly

Earlier Babe test APKs used different short-lived GitHub runner debug certificates. Android requires the same application ID and matching signing certificate for a normal update. Raising the build number is not sufficient.

The new Babe Stable package ID is com.cruefan94.recipe_haven.babe.stable. The old test app is com.cruefan94.recipe_haven.babe. Both can be installed on one phone, keeping old data in its original installation. Stable has its own data storage, so importing a backup is required. All later Stable releases must use the same permanent keystore.

## Easiest path using Android Termux

Only run these commands on your OWN trusted phone or Raspberry Pi. Never paste the key, base64 contents, or passwords into ChatGPT or a public GitHub file.

1. Install the tools in Termux:

    pkg update && pkg install openjdk-17 gh coreutils

2. Authenticate to your own GitHub account:

    gh auth login

3. Download the helper from your own Recipe-Haven development branch or clone the repository and check out feature/ingredient-products-and-cookbook-backup.

4. Inspect and run:

    bash scripts/setup_babe_signing.sh

5. The helper prompts you for a strong password, then generates the private key at ~/.recipe-haven-private/babe-release.jks. If the key already exists, the script refuses to regenerate it. It asks before uploading any secrets.

6. After confirmation, the helper encrypts and uploads these FOUR repository secrets using the GitHub CLI:

    RECIPE_HAVEN_RELEASE_KEYSTORE_B64
    RECIPE_HAVEN_RELEASE_STORE_PASSWORD
    RECIPE_HAVEN_RELEASE_KEY_ALIAS
    RECIPE_HAVEN_RELEASE_KEY_PASSWORD

    The selected alias is babe-release, and the helper uses the same password for the keystore and key. The value of a secret cannot be retrieved after submission.

7. Make an independent, PRIVATE, encrypted backup of the original .jks keystore. Store your password separately in a password manager. DO NOT lose either.

You can also create the four secrets manually in [GitHub Actions Secrets](https://github.com/cruefan94/Recipe-Haven/settings/secrets/actions) under Settings → Secrets and variables → Actions → New repository secret.

## Manually build the permanently signed APK

1. Open the [Babe Stable Release workflow](https://github.com/cruefan94/Recipe-Haven/actions/workflows/babe-stable-release.yml).
2. Click Run workflow on the main branch and confirm your signing key was backed up.
3. The workflow checks out the Babe development branch, runs Flutter analysis and tests, compiles a release APK, and compares the APK signer certificate with the private keystore.
4. When all steps succeed, download the Babe-STABLE-Permanently-Signed-APK artifact.
5. Install Babe Stable beside the original Babe test app. Use Backup & Restore to migrate saved recipes and the shopping list where supported by the old app.
6. Keep the old app until you have verified the migration.
7. For subsequent updates, reuse the SAME secrets and run the workflow again. A higher version code is assigned, allowing in-place Stable APK upgrades.

## Important limits

- The disposable CI signing smoke workflow does NOT use your permanent key and does NOT publish its APK.
- GitHub CI success is NOT proof of successful on-phone migration or upgrading.
- Preview APKs still use disposable keys and may not update earlier Preview installs.
- The signed workflow builds source from the feature branch, which remains unmerged into main. Review the branch source before approving a signed release.
- Do not create another keystore after the first Stable release. Losing the key or password can break update continuity.

## Visible or pasteable password entry

The Termux setup helper now asks whether to use **Visible (V)** or **Hidden (H)** password entry. **Visible is the default**: you can see the characters you type or paste, including when entering or confirming an existing keystore password. You can paste passwords in **both** modes; Hidden only prevents characters from appearing on screen. The script does not print the password again after entry, record it in shell history, or add it to project files.

**Privacy:** Visible passwords may appear in screen recordings, screenshots, Android clipboard history, or to people nearby. Choose Hidden when in public or while sharing your screen. If the password is sensitive, keep it in a password manager and never send it to this chat. The same password must be kept for future Stable APK releases.
