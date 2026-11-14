#!/usr/bin/env python3
"""Customize the sole iOS target as For Mom and Dad (never Babe)."""
import plistlib
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
info_path = root / 'ios/Runner/Info.plist'
pbx_path = root / 'ios/Runner.xcodeproj/project.pbxproj'
if not info_path.exists() or not pbx_path.exists():
    raise SystemExit('iOS scaffold missing. Use bash scripts/bootstrap_ios_momdad.sh on macOS.')

with info_path.open('rb') as f:
    info = plistlib.load(f)
info['CFBundleDisplayName'] = 'For Mom and Dad'
info['CFBundleName'] = 'For Mom and Dad'
info['NSLocationWhenInUseUsageDescription'] = (
    'Use your location when you tap Find Ingredient to list grocery stores within 30 km.'
)
with info_path.open('wb') as f:
    plistlib.dump(info, f, sort_keys=False)

text = pbx_path.read_text()
# The Runner app and its tests must each have a stable, distinct identifier.
pattern = re.compile(r'(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)([^;]+)(;)')
found = 0

def set_bundle(match):
    global found
    found += 1
    current = match.group(2).strip('"').strip()
    bundle = ('com.cruefan94.recipehaven.momdad.RunnerTests'
              if current.endswith('.RunnerTests') else
              'com.cruefan94.recipehaven.momdad')
    return f'{match.group(1)}{bundle}{match.group(3)}'

text = pattern.sub(set_bundle, text)
if found == 0:
    raise SystemExit('Unknown Xcode project template: missing PRODUCT_BUNDLE_IDENTIFIER.')
# file_picker v13 requires iOS 14+. Align the app and CocoaPods targets.
text = re.sub(r'(IPHONEOS_DEPLOYMENT_TARGET\s*=\s*)[0-9.]+(;)',
              r'\g<1>14.0\2', text)
pbx_path.write_text(text)

podfile = root / 'ios/Podfile'
if podfile.exists():
    content = podfile.read_text()
    pattern_ios = re.compile(r"""(?m)^\s*#?\s*platform\s+:ios,\s*['"][0-9.]+['"]\s*$""")
    if pattern_ios.search(content):
        content = pattern_ios.sub("platform :ios, '14.0'", content, count=1)
    else:
        content = "platform :ios, '14.0'\n" + content
    podfile.write_text(content)

print('iOS: For Mom and Dad, iOS 14 minimum, stable bundle ID, foreground-only location permission.')
