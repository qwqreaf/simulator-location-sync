#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
derived_data="${TMPDIR:-/tmp}/SimulatorLocationSyncDerivedData"
release_dir="$project_root/dist"
staging_dir="${TMPDIR:-/tmp}/SimulatorLocationSyncDMG"

rm -rf "$derived_data" "$release_dir" "$staging_dir"
mkdir -p "$release_dir" "$staging_dir"

xcodebuild \
  -project "$project_root/SimulatorLocationSync.xcodeproj" \
  -scheme SimulatorLocationSync \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CONFIGURATION_BUILD_DIR="$release_dir" \
  CODE_SIGN_IDENTITY=- \
  build

cp -R "$release_dir/SimulatorLocationSync.app" "$staging_dir/"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
  -volname "Simulator Location Sync" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$release_dir/SimulatorLocationSync.dmg"

echo "Built: $release_dir/SimulatorLocationSync.dmg"
