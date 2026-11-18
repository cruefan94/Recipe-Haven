# Android commercial-app foundation (source-only)

Derived by extracting **generalizable patterns** from the existing Recipe Haven Flutter source:
Material 3 theme configuration, dedicated full-screen navigation, local structured records,
and versioned/validated JSON backups. This is *not* a copy of the cooking UI or recipe data.

This folder is an independent local Flutter package. It does not alter the existing
Recipe Haven app, its Professional/Full edition separation, signing, model, settings, or source.

## Intended consumers

- Tradesman Pro (placeholder): job estimates and work tracking
- JobProof (placeholder): evidence, timestamps, before/after photos and reports
- Rental Inspector (placeholder): inspections, property records and condition reports

All three products are **Android-only**. Each app must have a separate Android package ID,
final brand, icon, storage, signing key and release stream. Names remain temporary.

## What exists

- Configurable brand/theme and accessible full-screen feature navigation
- Local SQLite record repository with save/list/remove
- Versioned, bounded JSON record codec with validation and duplicate checks
- Starter apps in `examples/` showing real domain-specific local workflows
- A small pure Dart/Flutter unit test suite

## Important limitations and next gates

- Source created on an isolated branch. Flutter/Dart toolchain not available in authoring runtime.
- No `flutter analyze`, `flutter test`, APK compilation or Android device tests yet.
- The `examples` do NOT yet contain generated `android/` Gradle platform projects.
  For each consumer, generate its own Android platform with Flutter CLI and verify package ID
  **without overwriting the supplied lib files**.
- SQLite and JSON exports are **not encrypted**. Do not store confidential customer material
  or distribute public builds before security, file privacy and secure export review.
- Photo handling, immutable evidence audit, signatures, pricing/tax rules, polished screen
  design, PDF export and commercial release workflows are separate feature milestones.
- Protect the original Recipe Haven branch and its signed Android release workflows.
- No Copilot, iOS, debug notices, or development metadata on customer-facing screens.

## Usage

Each `examples/<product>/pubspec.yaml` refers to this package with a local `path:`
dependency. Run `flutter pub get`, `flutter analyze`, `flutter test` once a verified
Flutter Android environment is available. Generate native Android folders in a clean
project before APK/AAB builds. No code from the old private cookbook is imported.

Source baseline: `feature/ingredient-products-and-cookbook-backup` at
`f09f792e088d95e1c30ef6098d5db44e92fca0ff`.
