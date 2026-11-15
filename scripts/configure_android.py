#!/usr/bin/env python3
"""Configure two Recipe Haven Android variants: Professional and Full."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
gradle = root / 'android/app/build.gradle.kts'
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not gradle.exists() or not manifest.exists():
    raise SystemExit('Android scaffold missing; run bash scripts/bootstrap_android.sh')

s = gradle.read_text()
if 'applicationId = "com.cruefan94.recipe_haven"' not in s:
    raise SystemExit('Unexpected Android application ID: expected com.cruefan94.recipe_haven.')
# Two Recipe Haven variants: Professional keeps the base package ID.
# Full installs independently with its own app data.
if 'create("professional")' not in s:
    s = s.replace('android {', '''android {
    flavorDimensions += "edition"
    productFlavors {
        create("professional") {
            dimension = "edition"
        }
        create("full") {
            dimension = "edition"
            applicationIdSuffix = ".full"
        }
    }
''', 1)

# Persistent release signing is optional and never activated for normal debug
# builds. The keystore remains outside the repository and is supplied by
# protected GitHub Actions secrets (or a local environment).
if 'recipeHavenSignedRelease' not in s:
    signing = '''android {
    val releaseKeyFile = System.getenv("RECIPE_HAVEN_RELEASE_KEYSTORE")
    if (!releaseKeyFile.isNullOrBlank()) {
        signingConfigs {
            create("recipeHavenSignedRelease") {
                storeFile = file(releaseKeyFile)
                storePassword = System.getenv("RECIPE_HAVEN_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("RECIPE_HAVEN_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("RECIPE_HAVEN_RELEASE_KEY_PASSWORD")
            }
        }
        buildTypes {
            getByName("release") {
                signingConfig = signingConfigs.getByName("recipeHavenSignedRelease")
            }
        }
    }
'''
    # Apply signing after Flutter's default release build type, otherwise
    # Flutter's generated debug-signing fallback would overwrite it.
    s += '\n' + signing + '}\n'

# Android Gradle lintVital currently crashes inside JavaDocParser on the
# Flutter 3.50 Linux runner, unrelated to application lint findings. Keep
# normal Android lint enabled. A very narrowly scoped CI release-build flag
# can skip only the broken release lintVital task until tooling is updated.
if 'RECIPE_HAVEN_RELEASE_LINT_WORKAROUND' not in s:
    s += '''
// Temporary CI-only workaround for a Flutter/Android lint JavaDocParser crash.
// DO NOT leave enabled after the upstream toolchain is fixed.
android {
    lint {
        if (System.getenv("RECIPE_HAVEN_RELEASE_LINT_WORKAROUND") == "1") {
            checkReleaseBuilds = false
        }
    }
}
'''
gradle.write_text(s)

# The observed JavaDoc parser crash is in :url_launcher_android, a library
# module, so changing only app lint cannot prevent it. Disable only the
# broken lintVitalAnalyze tasks across projects for CI signing checks.
# Ordinary local builds and other Gradle/Flutter checks are unaffected.
root_gradle = root / 'android/build.gradle.kts'
root_text = root_gradle.read_text()
if 'RECIPE_HAVEN_CI_LINT_VITAL_TASK_FIX' not in root_text:
    root_text += '''
// RECIPE_HAVEN_CI_LINT_VITAL_TASK_FIX
// Temporary workaround: Flutter 3.50 + AndroidLintWorkAction crashes in
// a third-party Android library's JavaDocParser. Remove when fixed.
if (System.getenv("RECIPE_HAVEN_RELEASE_LINT_WORKAROUND") == "1") {
    subprojects {
        tasks.configureEach {
            if (name.startsWith("lintVitalAnalyze")) {
                enabled = false
            }
        }
    }
}
'''
    root_gradle.write_text(root_text)

m = manifest.read_text()
m, count = re.subn(r'android:label="[^"]+"', 'android:label="@string/app_name"', m, count=1)
if count == 0:
    raise SystemExit('Unknown Android manifest template: missing application label.')
for permission in [
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
]:
    if permission not in m:
        m = m.replace('<application', f'<uses-permission android:name="{permission}" />\n    <application', 1)
# Android's Share menu can deliver text/plain recipe URLs directly to
# Recipe Haven. This adds no storage or new dangerous permissions.
if 'android.intent.action.SEND' not in m:
    if '</activity>' not in m:
        raise SystemExit('Unknown Android manifest template: missing main activity end tag.')
    share_filter = '''        <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
        '''
    m = m.replace('</activity>', share_filter + '</activity>', 1)

manifest.write_text(m)

# Flutter generates a default MainActivity during bootstrap. Replace only
# that generated Android entry point with our dedicated share receiver.
template = root / 'platform/android/MainActivity.kt'
target = root / 'android/app/src/main/kotlin/com/cruefan94/recipe_haven/MainActivity.kt'
if not template.is_file():
    raise SystemExit('Missing Android share receiver template.')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(template.read_text())


for flavor, label in [
    ('professional', 'Recipe Haven'),
    ('full', 'Recipe Haven Full'),
]:
    strings = root / 'android/app/src' / flavor / 'res/values/strings.xml'
    strings.parent.mkdir(parents=True, exist_ok=True)
    strings.write_text('<?xml version="1.0" encoding="utf-8"?>\\n'
                       '<resources><string name="app_name">%s</string></resources>\\n'
                       % label)
print('Recipe Haven Android: Professional and Full variants ready.')
