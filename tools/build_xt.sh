#!/bin/bash

# xT Build Script
# Builds the xT app for iOS 26 on iPhone 17

echo "🔧 Starting xT build..."
echo "📱 Target: iOS 26.0 - iPhone 17"
echo "🏗️  Configuration: Debug"
echo ""

# Clean derived data
echo "🧹 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/xT-*

# Build the project
echo "🛠️  Building xT..."
cd /Users/starlacortes/Documents/xT

# Try building with explicit settings
xcodebuild \
  -scheme xT \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -configuration Debug \
  SYMROOT=$(PWD)/build \
  OBJROOT=$(PWD)/build \
  IPHONEOS_DEPLOYMENT_TARGET=26.0 \
  SWIFT_VERSION=5.0

BUILD_RESULT=$?

echo ""
if [ $BUILD_RESULT -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo "📁 Output location: $(PWD)/build"
else
    echo "❌ Build failed with exit code $BUILD_RESULT"
fi

echo ""
echo "🎯 Build complete"
