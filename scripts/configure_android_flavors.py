#!/usr/bin/env python3
"""Idempotently configure the Mom & Dad + Babe Android variants."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
gradle = root / 'android/app/build.gradle.kts'
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not gradle.exists() or not manifest.exists():
    raise SystemExit('Android scaffold missing. First run: bash scripts/bootstrap_android.sh')

s = gradle.read_text()
# Upgrade early source trees that already used the old "standard" flavor.
s = s.replace('create("standard")', 'create("momdad")')
if 'create("babe")' not in s:
    flavors = '''android {
    flavorDimensions += "edition"
    productFlavors {
        create("momdad") {
            dimension = "edition"
        }
        create("babe") {
            dimension = "edition"
            applicationIdSuffix = ".babe"
        }
    }
'''
    if 'android {' not in s:
        raise SystemExit('Unknown Flutter Gradle template; cannot insert product flavors.')
    s = s.replace('android {', flavors, 1)
elif 'create("momdad")' not in s:
    s = s.replace('productFlavors {',
                  'productFlavors {\n        create("momdad") { dimension = "edition" }', 1)
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

gradle.write_text(s)

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
# either edition. This adds no storage or new dangerous permissions.
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

for flavor, label in [('momdad', 'For Mom and Dad'), ('babe', 'Recipe Haven 💛')]:
    strings = root / 'android/app/src' / flavor / 'res/values/strings.xml'
    strings.parent.mkdir(parents=True, exist_ok=True)
    strings.write_text('<?xml version="1.0" encoding="utf-8"?>\n'
                       '<resources><string name="app_name">%s</string></resources>\n' % label)
print('Android: Mom & Dad and Babe flavors configured with distinct labels and package IDs.')
