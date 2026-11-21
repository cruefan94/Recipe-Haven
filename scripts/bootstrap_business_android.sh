#!/usr/bin/env bash
set -euo pipefail
app="${1:?Provide: tradesman_pro, jobproof or rental_inspector}"
case "$app" in
  tradesman_pro) label="Tradesman Pro"; color="#DFAE3B"; icon="trade";;
  jobproof) label="JobProof"; color="#36B4D5"; icon="photo";;
  rental_inspector) label="Rental Inspector"; color="#419F70"; icon="rental";;
  *) echo "Unsupported product"; exit 2;;
esac
cd "$(dirname "$0")/../examples/$app"
test -s pubspec.yaml && test -s lib/main.dart
before_main="$(sha256sum lib/main.dart | cut -d' ' -f1)"
flutter create --platforms=android --org com.cruefan94 --project-name "$app" .
after_main="$(sha256sum lib/main.dart | cut -d' ' -f1)"
if [[ "$before_main" != "$after_main" ]]; then
  echo "::error::Flutter bootstrap altered the existing app entry point"; exit 1
fi
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
python3 - "$label" "$color" "$icon" "$app" <<'PY'
from pathlib import Path
import re
import sys
label,color,icon,app=sys.argv[1:]
base=Path('android/app/src/main')
manifest=base/'AndroidManifest.xml'
s=manifest.read_text()
s,n=re.subn(r'android:label="[^"]*"', 'android:label="'+label+'"', s, count=1)
if n!=1:
    raise SystemExit('Cannot set Android application label')
s=s.replace('android:icon="@mipmap/ic_launcher"','android:icon="@drawable/business_launcher"')
manifest.write_text(s)
paths={
 'trade': 'M12,16h24v4H12z M16,24h16v4H16z M10,8h28v30H10z',
 'photo': 'M7,14h9l4,-5h9l4,5h8v24H7z M24,19a7,7 0,1 0,0.1,0z',
 'rental': 'M5,23L24,7l19,16H38V41H10V23z M19,28h10v13H19z',
}
drawable=base/'res/drawable'
drawable.mkdir(parents=True,exist_ok=True)
(drawable/'business_launcher.xml').write_text(
 '<?xml version="1.0" encoding="utf-8"?>\n'
 '<vector xmlns:android="http://schemas.android.com/apk/res/android" '
 'android:width="48dp" android:height="48dp" '
 'android:viewportWidth="48" android:viewportHeight="48">\n'
 '<path android:fillColor="#111F2D" android:pathData="M0,0h48v48H0z"/>\n'
 '<path android:fillColor="'+color+'" android:pathData="'+paths[icon]+'"/>\n'
 '</vector>\n')
gradle=Path('android/app/build.gradle.kts')
if not gradle.exists():
    raise SystemExit('Missing Gradle Kotlin build file')
expected='com.cruefan94.'+app
if expected not in gradle.read_text():
    raise SystemExit('Unexpected package namespace/application ID: '+expected)
# Android Gradle Lint's CommentDetector crashes on image_picker_android
# ExifDataCopier.java in the current hosted runner (NoSuchMethodError:
# java.util.List.removeLast). Limit the workaround to that plugin's
# lintVitalAnalyzeRelease task; keep Dart tests, other Android build checks,
# signature checks, and app lint unaffected.
root_gradle=Path('android/build.gradle.kts')
if icon in ('photo', 'rental'):
    original=root_gradle.read_text()
    original += '\n' + (
        'subprojects {\n'
        '  if (name == "image_picker_android") {\n'
        '    tasks.matching { it.name == "lintVitalAnalyzeRelease" }.configureEach {\n'
        '      enabled = false\n'
        '    }\n'
        '  }\n'
        '}\n')
    root_gradle.write_text(original)

print('Configured distinct package: '+expected+'; launcher: '+label)
PY
flutter pub get
