#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  app_path="$1"
else
  app_path=""
  for candidate in \
    "$HOME/Applications/OpenWhispr.app" \
    "$HOME/Applications/Home Manager Apps/OpenWhispr.app" \
    "$HOME/.nix-profile/Applications/OpenWhispr.app" \
    "/Applications/OpenWhispr.app"; do
    if [[ -d "$candidate" ]]; then app_path="$candidate"; break; fi
  done
  [[ -n "$app_path" ]] || app_path="$HOME/Applications/OpenWhispr.app"
fi
test -d "$app_path"
test -x "$app_path/Contents/MacOS/OpenWhispr"
/usr/bin/codesign --verify --deep --strict "$app_path"
/usr/sbin/spctl --assess --type execute "$app_path"

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
printf 'bundle=%s version=%s\n' "$bundle_id" "$version"

if launchctl print "gui/$(id -u)/com.dryvist.nix-openwhispr" >/dev/null 2>&1; then
  echo 'launchd=open'
else
  echo 'launchd=not-loaded'
fi
