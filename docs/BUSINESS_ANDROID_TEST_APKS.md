# Android-only business app test distribution

Each independent product builds its own Android release-mode APK, signed with a temporary runner debug-signing key.

- Contractor: `com.cruefan94.tradesman_pro`
- Job documentation: `com.cruefan94.jobproof`
- Property inspections: `com.cruefan94.rental_inspector`

**Important:** Test APK signing identity is NOT stable across workflow runs. Fresh-install testing only. Never uninstall a data-bearing app to change signing keys. Before public release, configure a distinct permanent signing key for each product in protected secrets and verify its certificate.

Do not use Recipe Haven signing secrets. The original cooking app, its editions and package IDs are unchanged.

CI creates Android platform code independently, checks source, builds TEST APKs, verifies package identity and APK signatures, then uploads three separate artifacts and SHA-256 sums.

These are evaluation builds, not published releases. Customer data is not encrypted at rest yet; use fictional records only until privacy requirements are implemented and validated.
