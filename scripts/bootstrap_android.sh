#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Flutter generates platform boilerplate; all product customization lives here.
# Keep --org and --project-name stable across builds to preserve package IDs.
if [[ ! -f android/app/build.gradle.kts ]]; then
  flutter create --platforms=android --org com.cruefan94 --project-name recipe_haven .
fi
# Flutter may generate its default template test when bootstrapping a platform.
# That template references MyApp and is not applicable to this project.
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
python3 scripts/configure_android_flavors.py
