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
