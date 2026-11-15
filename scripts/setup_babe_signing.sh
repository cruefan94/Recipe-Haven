#!/usr/bin/env bash
# Run on your OWN Android Termux or Linux computer.
# Generates the signing keystore locally and encrypts GitHub Actions secrets.
# Never commits or prints a private key.
set -euo pipefail
umask 077

repo="cruefan94/Recipe-Haven"
alias_name="babe-release"
key_dir="$HOME/.recipe-haven-private"
key_file="$key_dir/babe-release.jks"

for executable in keytool gh base64 tr; do
  if ! command -v "$executable" >/dev/null 2>&1; then
    echo "Missing $executable."
    echo "Install in Termux: pkg install openjdk-17 gh coreutils"
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "Please authenticate first with: gh auth login"
  exit 1
fi

# Visible input echoes characters so users can see and paste a password.
# Hidden input remains available for privacy. Neither mode puts passwords
# into shell command history or writes them into repository source.
echo
echo "Password entry mode:"
echo "  V = Visible: characters appear while typing or pasting (default)"
echo "  H = Hidden: password is still pasteable, but characters are not shown"
echo "WARNING: Visible passwords may appear in screenshots or screen recordings."
printf "Choose [V/h]: "
IFS= read -r password_mode
case "${password_mode:-V}" in
  V|v) password_mode="visible" ;;
  H|h) password_mode="hidden" ;;
  *) echo "Choose V or H, then rerun the setup."; exit 1 ;;
esac

read_signing_password() {
  local prompt="$1"
  printf '%s' "$prompt"
  if [[ "$password_mode" == "visible" ]]; then
    IFS= read -r REPLY
  else
    IFS= read -rs REPLY
    printf '\n'
  fi
}

mkdir -p "$key_dir"
chmod 700 "$key_dir"
echo "Private key location: $key_file"
echo "Keep this same file and its password for ALL future Babe Stable updates."
if [[ -e "$key_file" ]]; then
  echo "Existing key found. Will NOT generate or overwrite it."
  read_signing_password "Existing keystore password: "
  password="$REPLY"
  unset REPLY
else
  read_signing_password "Choose NEW signing password (minimum 12 characters): "
  password="$REPLY"
  unset REPLY
  if [[ ${#password} -lt 12 ]]; then
    echo "Password too short."
    exit 1
  fi
  read_signing_password "Repeat or paste the same signing password: "
  confirm="$REPLY"
  unset REPLY
  if [[ "$password" != "$confirm" ]]; then
    echo "Passwords do not match."
    exit 1
  fi
  unset confirm
  keytool -genkeypair -noprompt -storetype PKCS12 \
    -keystore "$key_file" -alias "$alias_name" \
    -keyalg RSA -keysize 3072 -validity 10000 \
    -dname "CN=Babe Stable,O=Recipe Haven,C=CA" \
    -storepass "$password" -keypass "$password" >/dev/null 2>&1
  chmod 600 "$key_file"
  echo "Private signing key created on this device."
fi

if ! keytool -list -keystore "$key_file" -alias "$alias_name" \
    -storepass "$password" >/dev/null 2>&1; then
  echo "Could not verify keystore with this password; nothing uploaded."
  unset password
  exit 1
fi

echo
echo "Upload four encrypted GitHub Actions Secrets to $repo?"
echo "The keystore file remains on THIS device. Keep a private, encrypted backup."
printf "To continue, type YES: "
IFS= read -r approval
if [[ "$approval" != "YES" ]]; then
  echo "Canceled. Existing private keystore remains on disk."
  unset password
  exit 0
fi

base64 "$key_file" | tr -d '\n' |
  gh secret set RECIPE_HAVEN_RELEASE_KEYSTORE_B64 -R "$repo"
printf '%s' "$password" |
  gh secret set RECIPE_HAVEN_RELEASE_STORE_PASSWORD -R "$repo"
printf '%s' "$password" |
  gh secret set RECIPE_HAVEN_RELEASE_KEY_PASSWORD -R "$repo"
printf '%s' "$alias_name" |
  gh secret set RECIPE_HAVEN_RELEASE_KEY_ALIAS -R "$repo"
unset password

echo
echo "Four GitHub secret NAMES saved; private key and password were not printed."
gh secret list -R "$repo"
echo
echo "IMPORTANT: Back up the JKS file to trusted ENCRYPTED private storage."
echo "Store the password separately in a password manager."
echo "The password was never printed by the script after entry."
echo "Next: GitHub Actions > Babe Stable - Permanently Signed APK (Manual)"
