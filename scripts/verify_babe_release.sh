#!/usr/bin/env bash
# Verify Babe Stable package identity AND exact signing-key certificate.
set -euo pipefail

apk="${1:?Usage: verify_babe_release.sh PATH_TO_APK}"
test -s "$apk" || { echo "::error::Stable APK is missing or empty"; exit 1; }
: "$RECIPE_HAVEN_RELEASE_KEYSTORE"
: "$RECIPE_HAVEN_RELEASE_STORE_PASSWORD"
: "$RECIPE_HAVEN_RELEASE_KEY_ALIAS"

sdk="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
test -n "$sdk" && test -d "$sdk/build-tools" || {
  echo "::error::Android SDK Build Tools unavailable"; exit 1;
}
signer="$(find "$sdk/build-tools" -type f -name apksigner | sort -V | tail -1)"
aapt="$(find "$sdk/build-tools" -type f -name aapt | sort -V | tail -1)"
test -n "$signer" && test -n "$aapt" || {
  echo "::error::Missing apksigner or aapt"; exit 1;
}

badging="$("$aapt" dump badging "$apk")"
package="$(printf '%s\n' "$badging" | grep '^package: ' | head -1)"
case "$package" in
  *"name='com.cruefan94.recipe_haven.babe.stable'"*) ;;
  *) echo "::error::APK is not Babe Stable ($package)"; exit 1 ;;
esac
version="$(printf '%s\n' "$package" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")"
if [[ -z "$version" || "$version" -le 30000 ]]; then
  echo "::error::Invalid Babe Stable version code"; exit 1
fi

verify_output="$("$signer" verify --verbose --print-certs "$apk")"
actual="$(printf '%s\n' "$verify_output" | awk '/Signer #1 certificate SHA-256 digest:/ { print $NF; exit }')"
expected="$(keytool -list -v \
  -keystore "$RECIPE_HAVEN_RELEASE_KEYSTORE" \
  -alias "$RECIPE_HAVEN_RELEASE_KEY_ALIAS" \
  -storepass:env RECIPE_HAVEN_RELEASE_STORE_PASSWORD \
  | awk -F 'SHA256: ' '/SHA256:/ {print $2; exit}' \
  | tr -d ':\r' | tr '[:upper:]' '[:lower:]')"
# Certificate hashes are public; logging them helps diagnose signer selection.
echo "APK public certificate SHA-256: $actual"
echo "Keystore public certificate SHA-256: $expected"
if [[ -z "$actual" || -z "$expected" || "$actual" != "$expected" ]]; then
  echo "::error::APK signing certificate does not match supplied keystore"
  exit 1
fi

echo "Verified Babe Stable package ID, versionCode $version, signed APK and signing certificate."
echo "Public signing certificate SHA-256: $actual"
