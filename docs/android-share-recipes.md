# Android: Share recipe links into Recipe Haven

The Android editions can register as an optional share destination for HTTPS recipe URLs. No separate account, cloud relay, or extra dangerous permission is required.

## Usage

1. Open a recipe site in Chrome or another Android browser.
2. Choose **Share**, then **Recipe Haven 💛** or **For Mom and Dad**.
3. Recipe Haven opens **Add Recipe** with the URL prefilled. Choose the cookbook collection and tap Save.
4. If the browser does not list Recipe Haven, copy its URL and use **Add Recipe → Paste recipe link**.

Import uses the existing schema.org JSON-LD recipe extraction. If no supported ingredients or instructions are available, the recipe remains a link to its original website. Nothing is saved automatically from another app.

## Implementation

- platform/android/MainActivity.kt: native FlutterActivity handling ACTION_SEND and text/plain, with EXTRA_TEXT extracted and restricted to HTTPS URLs. The Activity buffers a cold-start share and sends warm shares across a MethodChannel.
- scripts/configure_android_flavors.py: installs the native activity into Flutter-generated Android scaffolding and adds the share intent filter to the main activity. Both Android product flavors inherit it.
- lib/services/incoming_recipe_share.dart: Flutter singleton queue that receives a pending shared URL, validates HTTPS, and notifies HomeScreen.
- lib/screens/home_screen.dart: routes the user into Add Recipe with a prefilled URL and a user-controlled collection selection. It also offers clipboard paste.

### Scope / privacy

- Only shared text URLs are accepted. Images, PDFs, attachments, arbitrary files and HTTP links are not imported.
- Shared text is not written to persistent storage until the user explicitly saves the recipe.
- Full source fetching happens after the user taps Save; a blocked/unsupported website remains a link.
- The iPhone edition is unchanged; this particular share intent receiver is Android-specific.
- The app may offer both installed Android editions in the Android Share sheet.

### Status

**Source-only**, on the draft development branch. Not compiled, installed or device-tested, as requested. The last successfully built APKs on main do not include this feature.

## References

- Android ACTION_SEND / EXTRA_TEXT: https://developer.android.com/guide/components/intents-filters
- Flutter Android method channels: https://docs.flutter.dev/platform-integration/platform-channels
