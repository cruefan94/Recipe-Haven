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
manifest.write_text(m)
for flavor, label in [('momdad', 'For Mom and Dad'), ('babe', 'Recipe Haven 💛')]:
    strings = root / 'android/app/src' / flavor / 'res/values/strings.xml'
    strings.parent.mkdir(parents=True, exist_ok=True)
    strings.write_text('<?xml version="1.0" encoding="utf-8"?>\n'
                       '<resources><string name="app_name">%s</string></resources>\n' % label)
print('Android: Mom & Dad and Babe flavors configured with distinct labels and package IDs.')
