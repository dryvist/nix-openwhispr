#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-$HOME/Applications/OpenWhispr.app}"
test -d "$app_path"
test -x "$app_path/Contents/MacOS/OpenWhispr"

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
printf 'bundle=%s version=%s\\n' "$bundle_id" "$version"

if launchctl print "gui/$(id -u)/com.dryvist.openwhispr" >/dev/null 2>&1; then
  echo 'launchd=open'
else
  echo 'launchd=not-loaded'
fi
