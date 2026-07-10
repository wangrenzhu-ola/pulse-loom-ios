#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
info_plist="$repo_root/PulseLoom/Info.plist"
project_file="$repo_root/PulseLoom.xcodeproj/project.pbxproj"
storekit_file="$repo_root/PulseLoom/Configuration.storekit"

if /usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$info_plist" >/dev/null 2>&1; then
  echo "FAIL microphone usage description is present"
  exit 1
fi

if rg -n 'AVAudio|AVCaptureAudio|requestRecordPermission|NSMicrophoneUsageDescription' "$repo_root/PulseLoom" --glob '*.swift' --glob '*.plist'; then
  echo "FAIL microphone or audio capture symbol found"
  exit 1
fi

rg -q 'IPHONEOS_DEPLOYMENT_TARGET = 14.0' "$project_file"
rg -q 'SWIFT_VERSION = 5.0' "$project_file"
rg -q 'com\.wangrenzhu\.pulseloom\.fullpractice' "$storekit_file"
rg -q 'type" : "NonConsumable"' "$storekit_file"
rg -q 'NSPrivacyTracking' "$repo_root/PulseLoom/PrivacyInfo.xcprivacy"
rg -q 'No microphone, audio recording, camera, account, cloud sync, AI coach' "$repo_root/PulseLoom/SettingsAndHistoryView.swift"

for screen in HomeView PatternLibraryView PatternEditorView CountdownView PracticeRunView AttemptReviewView PremiumSettingsView; do
  rg -q "struct $screen" "$repo_root/PulseLoom"
done

if rg -n '[一-龥]' "$repo_root/PulseLoom" "$repo_root/AppStoreMetadata" --glob '*.swift' --glob '*.strings' --glob '*.txt'; then
  echo "FAIL non-en-US reader-facing copy found"
  exit 1
fi

echo "PASS Swift 5 / iOS 14 project settings"
echo "PASS seven required SwiftUI surfaces"
echo "PASS local-only privacy boundary and no microphone usage description"
echo "PASS en-US source, localization, paywall, privacy, and App Store metadata scan"
echo "PASS StoreKit non-consumable product configuration"

