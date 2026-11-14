#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'iOS builds require macOS with Xcode. Run on a Mac or the macOS GitHub Actions runner.' >&2
  exit 1
fi
# Only the Mom & Dad edition is generated and built on iOS.
if [[ ! -f ios/Runner/Info.plist ]]; then
  flutter create --platforms=ios --org com.cruefan94 --project-name recipe_haven .
fi
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
python3 scripts/configure_ios_momdad.py
