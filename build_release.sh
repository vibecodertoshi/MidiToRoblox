#!/bin/bash

# Build release version of MidiToRoblox
echo "Building MidiToRoblox Release Version..."

# Clean build folder
xcodebuild clean -project MidiToRoblox.xcodeproj -configuration Release

# Build for release
xcodebuild build \
  -project MidiToRoblox.xcodeproj \
  -scheme MidiToRoblox \
  -configuration Release \
  -derivedDataPath ./build \
  ONLY_ACTIVE_ARCH=NO

# The built app will be in ./build/Build/Products/Release/MidiToRoblox.app
echo "Build complete! App location:"
echo "./build/Build/Products/Release/MidiToRoblox.app"

# Optional: Copy to Applications folder
# cp -R ./build/Build/Products/Release/MidiToRoblox.app /Applications/