#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../examples/block_chat"
test -s pubspec.yaml && test -s lib/main.dart
before="$(sha256sum lib/main.dart | cut -d' ' -f1)"
flutter create --platforms=android --org com.cruefan94 --project-name block_chat .
after="$(sha256sum lib/main.dart | cut -d' ' -f1)"
if [[ "$before" != "$after" ]]; then
  echo "::error::Flutter bootstrap replaced the app source"; exit 1
fi
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
python3 - <<'PY'
from pathlib import Path
import re
base=Path('android/app/src/main')
manifest=base/'AndroidManifest.xml'
text=manifest.read_text()
text,n=re.subn(r'android:label="[^"]*"', 'android:label="Block Chat"', text, count=1)
if n!=1: raise SystemExit('Cannot find launcher label')
text=text.replace('android:icon="@mipmap/ic_launcher"',
  'android:icon="@drawable/block_chat_launcher"')
if 'android.permission.INTERNET' not in text:
    text=text.replace('<application',
      '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
      1)
manifest.write_text(text)
drawable=base/'res/drawable'
drawable.mkdir(parents=True,exist_ok=True)
(drawable/'block_chat_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#0D1923" android:pathData="M0,0h48v48H0z"/>
    <path android:fillColor="#68D9C8"
        android:pathData="M6,23L24,8l18,15h-5v17H11V23z"/>
    <path android:fillColor="#0D1923"
        android:pathData="M17,25h14v8H24l-5,5v-5h-2z"/>
</vector>
''')
gradle=Path('android/app/build.gradle.kts')
if 'com.cruefan94.block_chat' not in gradle.read_text():
    raise SystemExit('Block Chat has an unexpected Android package identity')
assert 'android.permission.INTERNET' in manifest.read_text()
print('Independent Android Block Chat package configured.')
PY
flutter pub get
