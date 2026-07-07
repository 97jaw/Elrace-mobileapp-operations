#!/bin/sh
# Fast fix for iOS device build errors:
# - objective_c.dylib missing (stale .dart_tool/flutter_build cache)
# - invalid signature on objective_c.framework after partial cache deletes
#
# Usage: ./scripts/fix_ios_native_assets.sh
set -e
cd "$(dirname "$0")/.."

echo "Clearing stale Flutter native-asset caches..."
rm -rf .dart_tool/flutter_build .dart_tool/hooks_runner build/native_assets build/ios

echo "Regenerating dependencies..."
flutter pub get

echo "Done. Now run: flutter run -d <your-iphone>"
