#!/usr/bin/env bash
set -euo pipefail

# Configuration
BUNDLE_ID="com.mechanicpart.mechanicPart"
TEAM_ID="75U4C4C87J"
WORKSPACE="ios/Runner.xcworkspace"
SCHEME="Runner"
ARCHIVE_PATH="$PWD/build/ios/xcarchive/Runner.xcarchive"
IPA_DIR="$PWD/build/ios/ipa"
EXPORT_PLIST="$PWD/build/ios/exportOptions.plist"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

log() { echo "[build_and_export_ipa] $*"; }

select_app_store_profile() {
  local candidate="" candidate_ts=0
  shopt -s nullglob
  for f in "$PROFILE_DIR"/*.mobileprovision; do
    # Decode to XML
    local xml
    if ! xml=$(security cms -D -i "$f" 2>/dev/null); then continue; fi

    # Parse fields
    local app_id name get_task_allow team_id
    app_id=$(echo "$xml" | /usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin 2>/dev/null || echo "")
    name=$(echo "$xml" | /usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin 2>/dev/null || echo "")
    get_task_allow=$(echo "$xml" | /usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' /dev/stdin 2>/dev/null || echo "")
    team_id=$(echo "$xml" | /usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' /dev/stdin 2>/dev/null || echo "")

    # Match Team and Bundle ID
    if [[ "$app_id" != "${TEAM_ID}.${BUNDLE_ID}" ]]; then continue; fi
    if [[ "$team_id" != "$TEAM_ID" ]]; then continue; fi

    # App Store profile: no ProvisionedDevices and get-task-allow = false
    if echo "$xml" | grep -q '<key>ProvisionedDevices</key>'; then continue; fi
    if [[ "$get_task_allow" == "true" ]]; then continue; fi

    # Pick most recent
    local ts
    ts=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    if (( ts > candidate_ts )); then
      candidate_ts=$ts
      candidate="$f"
    fi
  done
  if [[ -z "$candidate" ]]; then
    log "ERROR: No matching App Store provisioning profile found for $TEAM_ID.$BUNDLE_ID in $PROFILE_DIR"
    return 1
  fi
  PROFILE_FILE="$candidate"
  PROFILE_NAME=$(security cms -D -i "$PROFILE_FILE" | /usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin)
  PROFILE_UUID=$(security cms -D -i "$PROFILE_FILE" | /usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin)
  log "Using provisioning profile: $PROFILE_NAME ($PROFILE_FILE)"
}

main() {
  log "Running pod install"
  pushd ios >/dev/null
  pod repo update
  pod install
  popd >/dev/null

  # Apply Codemagic profiles to Xcode project (Runner target)
  if command -v xcode-project >/dev/null 2>&1; then
    log "Applying profiles with xcode-project use-profiles"
    xcode-project use-profiles || true
  fi

  # Resolve App Store provisioning profile
  select_app_store_profile

  mkdir -p "$IPA_DIR" "$(dirname "$ARCHIVE_PATH")" "$(dirname "$EXPORT_PLIST")"

  # Show effective signing settings before archive
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release -sdk iphoneos -showBuildSettings | egrep -i "^(\s*CODE_SIGN|\s*PROVISIONING_PROFILE|\s*PRODUCT_BUNDLE_IDENTIFIER|\s*DEVELOPMENT_TEAM)" || true

  log "Archiving (manual signing for Runner; Pods remain unsigned)"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk iphoneos \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
    PROVISIONING_PROFILE="$PROFILE_UUID" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    archive | xcpretty || true

  log "Creating export options plist"
  cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$BUNDLE_ID</key><string>$PROFILE_NAME</string>
  </dict>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
PLIST

  log "Exporting IPA"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$IPA_DIR" | xcpretty || true

  log "IPA output:"
  ls -al "$IPA_DIR"
}

main "$@"
