# Reusing the Flipper AI Android Satellite app's interface approach

The separate, public `cruefan94/Flipper-AI-Android-Satellite` repository was consulted at branch `fix/android-chat-continuity-secure-cloud-settings-v241`, specifically `SatelliteUi.java` and `DashboardActivity.java` (checked 2026-11-13). Its Android app is native Java/Kotlin/Gradle, whereas Recipe Haven is Flutter to retain iOS compatibility for **For Mom and Dad**.

## Patterns adapted (not copied source)

- **One obvious dashboard:** five large, readable cards, each opening exactly one feature. Avoid crowded five-item bottom navigation on compact displays.
- **Full-screen tasks:** recipe search, general cookbook, add recipe, cannabis cookbook, ingredient finder.
- **Consistent return path:** AppBar's back button and Android system back return to Kitchen Home.
- **Reliable tap targets and contrast:** minimum 84-pixel-high dashboard cards, accessible icon+text, dark card surfaces with a warm amber accent.
- **Reliable app identity:** two independent Android application IDs; an iOS build only for Mom and Dad.

No Flipper Bluetooth pairing, cloud tokens, AI models, hardware controls, firmware or other feature source is imported or coupled to this app. Modifying Recipe Haven does not change Flipper AI. This is an **interface pattern adaptation**, not a wholesale Android codebase fork, because the latter would lose the shared iPhone target and duplicate maintenance.

## Verification required

Run `flutter analyze`, `flutter test`, both Android flavor APKs, iOS simulator compilation and device checks. No claim is made that a native Flipper Android file compiles as Flutter.
