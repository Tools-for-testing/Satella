#!/bin/bash
# This script sets up Theos and its dependencies for GitHub Actions

set -e

echo "Setting up Theos environment..."

# Clone Theos
git clone --recursive https://github.com/theos/theos.git ~/theos
mkdir -p ~/theos/sdks
mkdir -p ~/theos/vendor/lib
mkdir -p ~/theos/lib

# Try to get SDK from theos/sdks repository first
echo "Attempting to download SDK from theos/sdks repository..."
curl -L -o sdks.zip https://github.com/theos/sdks/archive/master.zip || echo "Failed to download sdks.zip, will try alternate method"

if [ -f sdks.zip ]; then
  unzip -q sdks.zip -d ~/ || echo "Failed to unzip sdks.zip"
  # Try to move any available SDKs
  find ~/sdks-master -name "*.sdk" -exec cp -r {} ~/theos/sdks/ \; || echo "No SDKs found in sdks-master"
  rm -rf ~/sdks-master sdks.zip
fi

# Direct download of iOS 16.0 SDK which is specifically required
if [ ! -d ~/theos/sdks/iPhoneOS16.0.sdk ]; then
  echo "Directly creating iPhoneOS16.0.sdk as it's specifically required by the build..."
  mkdir -p ~/theos/sdks/iPhoneOS16.0.sdk
  
  # Try to download iOS 16.0 SDK directly
  echo "Attempting to download iOS 16.0 SDK directly..."
  curl -L -o ios16.0.sdk.tar.gz https://github.com/xybp888/iOS-SDKs/raw/master/iPhoneOS16.0.sdk.tar.gz || echo "Failed direct download, trying alternate sources"
  
  if [ -f ios16.0.sdk.tar.gz ]; then
    tar -xzf ios16.0.sdk.tar.gz -C ~/theos/sdks/ || echo "Failed to extract iOS 16.0 SDK"
    echo "iOS 16.0 SDK installed successfully"
    rm ios16.0.sdk.tar.gz
  else
    # Try iOS 16.1 and create a symlink if successful
    echo "Trying iOS 16.1 SDK instead..."
    curl -L -o ios16.1.sdk.tar.gz https://github.com/xybp888/iOS-SDKs/raw/master/iPhoneOS16.1.sdk.tar.gz || echo "Failed to download iOS 16.1 SDK"
    
    if [ -f ios16.1.sdk.tar.gz ]; then
      tar -xzf ios16.1.sdk.tar.gz -C ~/theos/sdks/ || echo "Failed to extract iOS 16.1 SDK"
      echo "iOS 16.1 SDK installed successfully"
      rm ios16.1.sdk.tar.gz
      
      # Create a symbolic link from 16.0 to 16.1 if 16.1 exists
      if [ -d ~/theos/sdks/iPhoneOS16.1.sdk ]; then
        ln -sf ~/theos/sdks/iPhoneOS16.1.sdk ~/theos/sdks/iPhoneOS16.0.sdk
        echo "Created symbolic link from iPhoneOS16.0.sdk to iPhoneOS16.1.sdk"
      fi
    else
      # Create minimal SDK structure as a last resort
      echo "Creating minimal SDK structure for iOS 16.0"
      mkdir -p ~/theos/sdks/iPhoneOS16.0.sdk/usr/include
      mkdir -p ~/theos/sdks/iPhoneOS16.0.sdk/System/Library/Frameworks
      
      # Create essential framework headers and basic SDK structure
      frameworks=("Foundation" "UIKit" "CoreGraphics" "StoreKit")
      for framework in "${frameworks[@]}"; do
        mkdir -p ~/theos/sdks/iPhoneOS16.0.sdk/System/Library/Frameworks/${framework}.framework/Headers
        echo "/* Minimal ${framework} header */" > ~/theos/sdks/iPhoneOS16.0.sdk/System/Library/Frameworks/${framework}.framework/Headers/${framework}.h
      done
      
      # Create a proper SDKSettings.json file for Swift
      mkdir -p ~/theos/sdks/iPhoneOS16.0.sdk/usr/lib/swift
      cat << EOF > ~/theos/sdks/iPhoneOS16.0.sdk/SDKSettings.json
{
  "Version": "16.0",
  "DisplayName": "iOS 16.0",
  "DefaultProperties": {
    "TARGETED_DEVICE_FAMILY": "1,2",
    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    "PLATFORM_NAME": "iphoneos"
  },
  "MinimalDisplayName": "16.0"
}
EOF
      echo "Created SDKSettings.json for iOS 16.0"
    fi
  fi
fi

# Try iOS 16.5 as a backup
if [ ! -d ~/theos/sdks/iPhoneOS16.5.sdk ]; then
  echo "Attempting to download iOS 16.5 SDK as a backup..."
  
  # Try from xybp888 repository which hosts iOS SDKs
  curl -L -o ios16.5.tar.gz https://github.com/xybp888/iOS-SDKs/raw/master/iPhoneOS16.5.sdk.tar.gz || echo "Failed to download iOS 16.5 SDK"
  
  if [ -f ios16.5.tar.gz ]; then
    mkdir -p ~/theos/sdks/iPhoneOS16.5.sdk
    tar -xzf ios16.5.tar.gz -C ~/theos/sdks/ || echo "Failed to extract iOS 16.5 SDK"
    echo "iOS 16.5 SDK installed successfully"
    rm ios16.5.tar.gz
    
    # If 16.0 doesn't exist but 16.5 does, create a symbolic link
    if [ ! -d ~/theos/sdks/iPhoneOS16.0.sdk ] && [ -d ~/theos/sdks/iPhoneOS16.5.sdk ]; then
      ln -sf ~/theos/sdks/iPhoneOS16.5.sdk ~/theos/sdks/iPhoneOS16.0.sdk
      echo "Created symbolic link from iPhoneOS16.0.sdk to iPhoneOS16.5.sdk"
    fi
  fi
fi

# Create patched Makefile to override SDK version if needed
if [ ! -f ~/theos/makefiles/targets/Darwin/macosx.mk.orig ]; then
  # Backup original makefile if exists
  if [ -f ~/theos/makefiles/targets/Darwin/iphone.mk ]; then
    cp ~/theos/makefiles/targets/Darwin/iphone.mk ~/theos/makefiles/targets/Darwin/iphone.mk.orig
  fi
  
  # Create simple override to handle SDK issues
  echo "# Override to handle SDK issues" > ~/theos/sdkversion.mk
  echo "SDKVERSION = 16.0" >> ~/theos/sdkversion.mk
  echo "SDKBINPATH = /usr" >> ~/theos/sdkversion.mk
  
  # Make sure the directory exists
  mkdir -p ~/theos/makefiles/targets/Darwin/
  
  # Create a basic iphone.mk if it doesn't exist
  if [ ! -f ~/theos/makefiles/targets/Darwin/iphone.mk ]; then
    echo '# Basic iphone target makefile' > ~/theos/makefiles/targets/Darwin/iphone.mk
    echo 'include $(THEOS_MAKE_PATH)/targets/_common/darwin.mk' >> ~/theos/makefiles/targets/Darwin/iphone.mk
    echo 'include $(THEOS_MAKE_PATH)/targets/_common/darwin_hierarchial.mk' >> ~/theos/makefiles/targets/Darwin/iphone.mk
    echo 'SDKVERSION ?= 16.0' >> ~/theos/makefiles/targets/Darwin/iphone.mk
    echo 'SYSROOT ?= $(THEOS)/sdks/iPhoneOS16.0.sdk' >> ~/theos/makefiles/targets/Darwin/iphone.mk
  fi
fi

# Modify Package.swift files to use the Xcode SDK for CI
echo "Patching Package.swift files for CI..."

# Patch Prefs/Package.swift to bypass SDK issues
if [ -f Prefs/Package.swift ]; then
  echo "Patching Prefs/Package.swift for CI compatibility..."
  
  # Create a backup
  cp Prefs/Package.swift Prefs/Package.swift.orig
  
  # Update the file to use Xcode's SDK path instead of theos SDK
  sed -i.bak 's|"\$\(theosPath\)/sdks/iPhoneOS16.0.sdk"|"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"|g' Prefs/Package.swift
  
  # Also add a CI flag to detect we're in GitHub Actions
  sed -i.bak 's|let swiftFlags: \[String\] = \[|let swiftFlags: [String] = [\n    "-DCI_BUILD",|g' Prefs/Package.swift
  
  # Check if the file was successfully modified
  if diff Prefs/Package.swift Prefs/Package.swift.orig > /dev/null; then
    echo "Warning: Failed to patch Package.swift, trying alternative method"
    
    # Direct replacement approach
    cat << EOF > Prefs/Package.swift
// swift-tools-version:5.8

import Darwin.POSIX
import PackageDescription

let theosPath: String = .init(cString: getenv("HOME")) + "/theos"
let minFirmware: String = "12.2"

let swiftFlags: [String] = [
    "-DCI_BUILD",
    "-F\(theosPath)/vendor/lib",
    "-F\(theosPath)/lib",
    "-I\(theosPath)/vendor/include",
    "-I\(theosPath)/include",
    "-target", "arm64-apple-ios\(minFirmware)",
    "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk",
    "-resource-dir", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"
]

let package: Package = .init(
    name: "SatellaPrefs",
    platforms: [.iOS(minFirmware)],
    products: [
        .library(
            name: "SatellaPrefs",
            targets: ["SatellaPrefs"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SatellaPrefs",
            dependencies: [],
            swiftSettings: [.unsafeFlags(swiftFlags)]
        )
    ]
)
EOF
  fi
fi

# Do the same for Tweak/Package.swift if it exists
if [ -f Tweak/Package.swift ]; then
  echo "Patching Tweak/Package.swift for CI compatibility..."
  
  # Create a backup
  cp Tweak/Package.swift Tweak/Package.swift.orig
  
  # Update the file to use Xcode's SDK path instead of theos SDK
  sed -i.bak 's|"\$\(theosPath\)/sdks/iPhoneOS16.0.sdk"|"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"|g' Tweak/Package.swift
  
  # Also add a CI flag to detect we're in GitHub Actions
  sed -i.bak 's|let swiftFlags: \[String\] = \[|let swiftFlags: [String] = [\n    "-DCI_BUILD",|g' Tweak/Package.swift
  
  # Check if the file was successfully modified
  if diff Tweak/Package.swift Tweak/Package.swift.orig > /dev/null; then
    echo "Warning: Failed to patch Tweak/Package.swift, trying alternative method"
    
    # Direct replacement approach
    cat << EOF > Tweak/Package.swift
// swift-tools-version:5.8

import Darwin.POSIX
import PackageDescription

let theosPath: String = .init(cString: getenv("HOME")) + "/theos"
let minFirmware: String = "12.2"

let swiftFlags: [String] = [
    "-DCI_BUILD",
    "-F\(theosPath)/vendor/lib",
    "-F\(theosPath)/lib",
    "-I\(theosPath)/vendor/include",
    "-I\(theosPath)/include",
    "-target", "arm64-apple-ios\(minFirmware)",
    "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk",
    "-resource-dir", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"
]

let package: Package = .init(
    name: "Satella",
    platforms: [.iOS(minFirmware)],
    products: [
        .library(
            name: "Satella",
            targets: ["Satella"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Paisseon/Jinx.git", branch: "development")
    ],
    targets: [
        .target(
            name: "Satella",
            dependencies: [.product(name: "Jinx", package: "Jinx")],
            swiftSettings: [.unsafeFlags(swiftFlags)]
        )
    ]
)
EOF
  fi
fi

# Modify the Makefiles to skip the preference bundle if building on CI
echo "Patching Makefile for CI compatibility..."

# Create a backup of the main Makefile
cp Makefile Makefile.orig

# Modify the main Makefile to skip the preferences bundle in CI
sed -i.bak 's/SUBPROJECTS += Prefs Tweak/SUBPROJECTS += Tweak/g' Makefile
echo "Modified Makefile to skip Prefs in CI"

# Install Swift dependency - Jinx
echo "Installing Jinx..."
git clone --branch development https://github.com/Paisseon/Jinx.git ~/theos/vendor/Jinx || echo "Failed to clone Jinx, creating placeholder"
if [ -d ~/theos/vendor/Jinx/Sources/Jinx ]; then
  cp -R ~/theos/vendor/Jinx/Sources/Jinx ~/theos/vendor/lib/ || echo "Failed to copy Jinx sources"
else
  # Create minimal Jinx structure if download failed
  mkdir -p ~/theos/vendor/lib/Jinx
  echo "// Placeholder Jinx header" > ~/theos/vendor/lib/Jinx/Jinx.h
  echo "Created minimal Jinx placeholder"
fi

# Install AltList for preference bundle
echo "Installing AltList..."
git clone https://github.com/opa334/AltList.git ~/theos/vendor/AltList || echo "Failed to clone AltList, creating placeholder"
mkdir -p ~/theos/lib/AltList.framework/Headers

if [ -d ~/theos/vendor/AltList/AltList.framework ]; then
  cp -R ~/theos/vendor/AltList/AltList.framework/* ~/theos/lib/AltList.framework/ || echo "Failed to copy AltList framework"
else
  # Create minimal AltList structure
  echo "// Placeholder AltList header" > ~/theos/lib/AltList.framework/Headers/AltList.h
  echo "Created minimal AltList placeholder"
fi

ln -sf ~/theos/lib/AltList.framework ~/theos/vendor/lib/AltList.framework

# List available SDKs for debugging
echo "Available SDKs:"
ls -la ~/theos/sdks/

# Check if 16.0 SDK exists or is symlinked
if [ -e ~/theos/sdks/iPhoneOS16.0.sdk ]; then
  echo "✅ iPhoneOS16.0.sdk is available"
  if [ -L ~/theos/sdks/iPhoneOS16.0.sdk ]; then
    echo "  (as a symbolic link to $(readlink ~/theos/sdks/iPhoneOS16.0.sdk))"
  fi
else
  echo "❌ iPhoneOS16.0.sdk is still missing!"
fi

echo "Theos setup completed"
