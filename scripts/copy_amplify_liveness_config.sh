#!/usr/bin/env bash
# Copy Cognito/Amplify config into Android + iOS paths for face_liveness_detector.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/config/amplify/amplifyconfiguration.json"
IOS_SRC="$ROOT/config/amplify/awsconfiguration.json"

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC"
  echo "Copy config/amplify/amplifyconfiguration.json.example and set your Identity Pool ID."
  exit 1
fi
if grep -q "REPLACE_WITH" "$SRC"; then
  echo "Edit $SRC — replace REPLACE_WITH_IDENTITY_POOL_UUID first."
  exit 1
fi
if grep -qE 'ap-south-1:ap-south-1:' "$SRC"; then
  echo "ERROR: PoolId has duplicate region (ap-south-1:ap-south-1:...)."
  echo "Use AWS console value only once: ap-south-1:uuid"
  exit 1
fi

mkdir -p "$ROOT/android/app/src/main/res/raw"
cp "$SRC" "$ROOT/android/app/src/main/res/raw/amplifyconfiguration.json"
echo "Wrote android/app/src/main/res/raw/amplifyconfiguration.json"

mkdir -p "$ROOT/ios/Runner"
cp "$SRC" "$ROOT/ios/Runner/amplifyconfiguration.json"
echo "Wrote ios/Runner/amplifyconfiguration.json"

if [[ -f "$IOS_SRC" ]]; then
  if grep -qE 'ap-south-1:ap-south-1:' "$IOS_SRC"; then
    echo "ERROR: awsconfiguration.json has duplicate region prefix."
    exit 1
  fi
  cp "$IOS_SRC" "$ROOT/ios/Runner/awsconfiguration.json"
  echo "Wrote ios/Runner/awsconfiguration.json"
else
  cp "$SRC" "$ROOT/ios/Runner/awsconfiguration.json"
  echo "Wrote ios/Runner/awsconfiguration.json (from amplifyconfiguration.json)"
fi

echo "Rebuild iOS: cd ios && pod install && cd .. && flutter run"
