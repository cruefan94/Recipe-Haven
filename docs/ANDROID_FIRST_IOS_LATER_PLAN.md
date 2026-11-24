# Northern Circuit Studios — Android-first, iPhone-next validation plan

**Decision:** Validate and stabilize working Android editions before initiating iOS compilation, signing, or TestFlight. This is a release sequence, not an indefinite cancellation of iPhone support. Maintain clean Flutter business logic where feasible so iOS can reuse it later.

**Audience constraint:** Most people in the owner's immediate circle have iPhones, so Android-only household testing is insufficient evidence of market fit. The existing website beta application is explicitly Android-only; do not misrepresent it as iOS-ready. Recruit external Android testers now and open an iPhone tester cohort only when an iOS build exists.

## Parallel priority tracks

1. **Tradesman Pro:** Most promising initial revenue pilot for solo tradespeople, part-time/side-job contractors, startup contractors, and crews of roughly 1–5. Target a simple offline **customer -> itemized quote -> PDF -> job status -> invoice -> paid/unpaid** workflow, not enterprise integrations. Start with fictional demo customers until storage/privacy review. Ask a small number of consenting Android users in this audience to try their real workflow, identify where they get stuck, and report bugs. Validate willingness to pay separately rather than asserting demand.
2. **Recipe Haven Professional and Full:** Finish Android usability, original recipe links, accessible cooking screens, ingredient substitution, cooking timers, grocery lists, edition isolation, import/restore and build verification. Do not add feature creep before stability. The proposed recipe-search dietary filters are **parked for future evaluation**, not part of the release promise or implemented features.
3. **JobProof and Rental Inspector:** Keep independent Android builds, resolve photo/report/storage issues, test on devices and verify data/privacy handling before inviting real business users. Rental Inspector's ownership transfer/acquisition is a possible separate commercial route, not an assumed buyer.
4. **Block Chat:** First validate actual live backend, authorization, moderation and privacy controls before recruiting users. Android UI compilation is not an adequate readiness test.

## Android readiness gate (for each product)

- Reproducible CI build with checks and tests passing on the actual release-candidate commit.
- Stable, backed-up **product-specific signing identity** and a reliable upgrade path. Current three-business-app CI APKs are **temporary/debug signed test installers**, unsuitable for stable customer upgrades.
- Physical Android smoke test and regression tests: launch, navigation, screen sizes/accessibility, offline use where promised, data persistence, backup/restore and failure handling; camera and share flows if applicable.
- Secure storage, permissions, privacy notice, safe data deletion/export and customer-information handling verified where applicable; **do not use real client data on current unencrypted business-test builds**.
- Working end-to-end primary user task; PDF and money calculations independently checked with CAD/tax caveats, no unsupported legal or payment claims.
- Small Android beta cohort with clearly tracked bugs, reproducible steps, acceptance criteria and a stop/go decision. The website's Android-only beta and private, post-acceptance NDA process stay unchanged unless deliberately revised.

## Deferred studio-wide diagnostics and crash reporting — production roadmap note (2026-11-24)

**Decision: Documentation only. Do not implement or deploy the Cloudflare receiver, database, dashboard, telemetry upload, or notification service now.** Revisit per application as it becomes otherwise ready for production or broader beta. This idea applies to all five Northern Circuit Studios apps: Recipe Haven (Professional/Full), Tradesman Pro, JobProof, Rental Inspector and Block Chat.

- **Proposed architecture, not a live service:** One separate private Cloudflare Worker for ingest, D1 storage with bounded retention, and an Access-protected Northern Circuit Studios dashboard; optional alerts containing no report details. Keep it isolated from the website and existing Flipper AI Worker. Reassess Cloudflare pricing, capacity, hosting location, and any applicable legal requirements at implementation time.
- **Minimize and strictly allowlist fields:** app identity and version, generic error category and affected feature area, coarse technical state necessary for diagnosis, time, and a test-event flag. Do not transmit customer names, contacts, photos, invoice content, locations, free-form exception messages, raw stack traces, paths, credentials, or arbitrary identifiers. Review whether timestamps, IP addresses, and platform metadata could still constitute personal information; suppress or minimize them in storage/logs.
- **Privacy and security before activation:** meaningful in-app notice, appropriate consent and controls, transport security, authenticated/abuse-resistant ingestion, dashboard access controls, encrypted storage, rate limiting, deletion/retention rules, and a documented incident response. Perform the jurisdiction-specific privacy review before any automatic upload.
- **Reliability:** add bounded, protected local queuing only if necessary; a hard crash might require delivery on the next launch. Separate handled Flutter errors from uncaught platform/native crashes and account for Android/iOS differences.
- **Pre-release verification when implemented:** generate controlled test exceptions and safe simulated crashes, test disabled/no-consent paths, inspect exact outbound payload and receiver storage, confirm no synthetic secret strings leak, verify offline/retry/duplicate behavior, and exercise auth, retention and deletion. Then run a real-device end-to-end test before external distribution.
- **Current status:** The shared Flutter foundation has an allowlisted diagnostic report model and unit-test fixture with a fake in-memory sink, but **no production sender, Cloudflare endpoint or verified real-device end-to-end reporting**. Leave collection disabled. Neither passing unit tests nor this roadmap note establishes deployment or legal compliance.

**Priority:** Keep focus on finishing, securing and validating the Android apps; only activate centralized diagnostics after explicit review of an individual app's readiness and the privacy/security gates above.

## iPhone phase, after Android gates pass

- Maintain platform-neutral Flutter logic and avoid Android-only dependencies without an iOS alternative; assess plugins and permissions individually.
- Obtain access to macOS/Xcode or a suitable macOS CI service; configure iOS app bundle identifiers, Apple signing/provisioning and developer account as needed for wider distribution.
- Compile distinct iOS builds; perform real-iPhone checks for navigation, permissions, persistent data, file export/sharing, notifications, billing and accessibility.
- Invite a separate iPhone cohort (use TestFlight when appropriate); clarify tester eligibility, privacy information and any review requirements. **Do not advertise iPhone availability until a build and distribution route are verified.**
- Reevaluate product pricing and storefront policy before public sales. The Android website beta form must not silently accept iOS applicants under the Android-only terms.

## Evidence and next practical actions

- First Tradesman Pro user test: create fictional customer, create an itemized quote, share PDF, create job, change status, generate invoice, prevent duplicate final invoice for the same estimate, mark paid, share invoice. Record defects and usability friction.
- Prioritize plain language, large touch targets, accurate cost/tax math, simple navigation and no unnecessary account requirement.
- Check tests and CI after each relevant code change; passing static tests is not equivalent to real-device validation.
- Preserve Recipe Haven's two-edition rules and separate packaging. Keep all five products individually releasable; do not bundle their ownership or release timelines.

**Status:** Development/testing plan recorded; no iOS build, Play Store release or public beta is implied by this document.
