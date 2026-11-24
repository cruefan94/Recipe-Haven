# Northern Circuit Studios — diagnostics security and pre-beta crash testing

**Status (2026-11-24):** Required release gate and a proof-of-concept in the shared Flutter business foundation. **No production collector, email reporting, network transmission, or automatic live-app crash capture is enabled.** Do not market this as fully implemented for customers. Current app test builds remain unsuitable for real client information until other privacy and signing issues are resolved.

## Studio-wide policy: all five apps

Applies to Recipe Haven Professional and Full, Tradesman Pro, JobProof, Rental Inspector, and Block Chat. The current reusable `android_app_foundation` diagnostic code is accessible to Tradesman Pro, JobProof, and Rental Inspector; Recipe Haven and Block Chat need separate integration and equivalent tests.

Use a **closed list of diagnostic fields**: numeric schema version, app identifier from a fixed enum, app version in a strict numeric format, screen/feature category from a fixed enum, event category, coarse error type, test-event flag and UTC timestamp. The code currently sends **only these fields** to its injected test receiver. No arbitrary `Map<String,dynamic>` metadata from the app is permitted.

Never send names, emails, phone numbers, address or precise/coarse device location, customer details, job descriptions, invoice text, photos, saved recipes, account/login tokens, hardware IDs, IP addresses added by the client, clipboard contents, full exception messages, stack traces, file paths, request bodies or third-party SDK identifiers in our custom payload. Real HTTP requests inherently expose network metadata such as source IP to the receiving infrastructure; operational controls and retention must address it. Error messages/stack traces can contain private data even when the crash is benign.

**Privacy default:** no transmissions or collection until a suitable notice, meaningful consent/user controls, receiver security, retention policy and store disclosures have been reviewed. Data minimization applies even to testers. Test-only crash injection must not be included in public production builds. Disclosing diagnostics and allowing simple refusal wherever appropriate is preferable to hiding transmission.

## Controlled automated crash test implemented

`packages/android_app_foundation/test/diagnostics_test.dart` throws a synthetic `StateError` with fake name, address and invoice data, creates a restricted `DiagnosticReport`, and sends serialized JSON to an **in-memory recording receiver**. It asserts that only the eight allowlisted keys arrive and that no fake customer terms leak. It also tests default-deny behavior, missing consent, and rejection of malformed version text.

The test uses an intentionally caught exception so CI does not abort. This validates **report construction and the send interface**, **not a real fatal process crash**, not Android or iOS platform exception-hook behavior, and not remote network delivery.

The Android business app CI matrix executes this test before building the three temporary-signed APKs. Verify the latest workflow run is green; a committed test is not a passing test.

## Remaining pre-beta checks — mandatory

1. **Actual collector and delivery:** provision an isolated TLS diagnostic endpoint with restricted access, server-side field/schema validation, authentication, abuse/rate limiting, minimal retention, redaction and audit logs; make sure it does not accidentally log full request bodies or retain identifiable IPs beyond necessity. Separate test and production. Document who can access reports and how users withdraw consent.
2. **App integration:** use guarded Flutter framework/async error hooks and platform crash mechanisms with no raw exception strings in the transmitted data. Capture crashes on the next safe launch if a fatal crash prevents an immediate send. Verify storage encryption where reports are queued. Implement opt-in/notice before enabling transmission.
3. **Synthetic failure injection:** in a dev-only build, trigger a controlled Flutter UI exception and a separate fatal/restart scenario on a test device. Never use a customer's device. Verify event received at the test endpoint; inspect **both client payload and server logs** for forbidden data. Check no infinite crash/retry loop.
4. **Negative and privacy tests:** prove opt-out sends zero requests, app works offline, queue expiration/retry limits, no secrets in exceptions, rejection of extra fields, transport TLS/certificate failures, and separation between two app editions.
5. **Real-device acceptance:** verify reporting on the owner's Android device; test app startup, invoice flow and diagnostic failures; then expand to other apps. Apple TestFlight's built-in crash service is a separate source with its own policies; don't claim the same custom reporter works on iOS without testing.
6. **Beta release signoff:** Android release signing must be stable, sensitive local data protected, privacy policy/store Data safety/App Privacy declarations accurate, security checks passed, and testers briefed. Only then send installers/invitations.

## Privacy source references to check before release

- Canada OPC meaningful consent: https://www.priv.gc.ca/en/privacy-topics/privacy-for-businesses/appropriate-handling-of-personal-information/collecting-personal-information-and-consent/consent/gl_omc_201805/
- Google Play user data and Data safety: https://support.google.com/googleplay/android-developer/answer/10144311
- Apple App Privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Apple TestFlight crash reports: https://developer.apple.com/documentation/Xcode/acquiring-crash-reports-and-diagnostic-logs

This document does **not** by itself determine legality in every Canadian province, device platform or distribution channel; obtain a privacy review before enabling automatic collection.
