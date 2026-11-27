# Three Android-only business starters

Source-only Flutter demonstration apps derived from the shared `packages/android_app_foundation` package.

1. `tradesman_pro/`: contractor estimate form and local saved quotes. Amounts are integer CAD cents and exclude tax. Percentage settings are user input. No invoices or PDF export yet.
2. `jobproof/`: camera capture tagged Before/During/After, local owned-file copy, and on-device gallery. No tamper evidence, client signatures, photo export or report generation yet.
3. `rental_inspector/`: property/room condition entry, inspection type, local inspection history. No inspection photo checklist, signature or reports yet.

**Temporary names**: these are source identifiers only. Customer branding is still pending final name and trademark review.

## Build instructions (Android only)

These examples contain Flutter Dart source and package manifests, **not** generated Android platform directories. In a verified Flutter environment create a new Android project for each independent commercial app, preserving the provided `lib/`, `test/` and `pubspec.yaml` files and maintaining the relative local package dependency or vendoring the foundation as needed. Review each app's final unique package ID and signing key.

Run:
```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
Only call an APK usable after compilation, package/signature verification and real Android device testing. No Flutter SDK or Android device was available during this source authoring step.

No iOS support, no Copilot, no debug or development notes in customer interfaces.

Data privacy: customer records, property information and photos are stored locally without database encryption at this stage. Do not distribute as a commercial release until access controls, backups, permission handling, retention/deletion, file recovery and legal/privacy requirements have been reviewed. Source-only testing cannot demonstrate reliability.
