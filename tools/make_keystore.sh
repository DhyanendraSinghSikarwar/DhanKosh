#!/usr/bin/env bash
# Creates the permanent DhanKosh release key ONCE and prints what to put in
# GitHub (Settings -> Secrets and variables -> Actions). Keep the .jks file and
# the password somewhere safe: a lost key means users must uninstall to update.
# Needs Java's keytool. Never commit the .jks (the .gitignore blocks it).
set -euo pipefail
out="${1:-dhankosh-release.jks}"
alias_name="${HISAAB_KEY_ALIAS:-hisaab}"
read -r -s -p "Choose a keystore password (min 6 chars): " pw; echo
keytool -genkeypair -v -keystore "$out" -alias "$alias_name" -keyalg RSA -keysize 4096 \
  -validity 10000 -storepass "$pw" -keypass "$pw" -dname "CN=DhanKosh, O=DhanKosh, C=IN"
echo
echo "Add these repository secrets:"
echo "  HISAAB_KEYSTORE_PASSWORD = the password you just typed"
echo "  HISAAB_KEY_ALIAS         = $alias_name"
echo "  HISAAB_RELEASE_KEYSTORE  = the single line below (base64 of $out)"
base64 -w0 "$out" 2>/dev/null || base64 "$out" | tr -d '\n'
echo
