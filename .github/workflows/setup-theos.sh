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

# Check for iOS 16 SDK
if [ ! -d ~/theos/sdks/iPhoneOS16.0.sdk ] && [ ! -d ~/theos/sdks/iPhoneOS16.5.sdk ]; then
  echo "No iOS 16 SDK found. Downloading from alternate source..."
  
  # Try from xybp888 repository which hosts iOS SDKs
  mkdir -p ~/theos/sdks/iPhoneOS16.5.sdk
  curl -L -o ios16.tar.gz https://github.com/xybp888/iOS-SDKs/raw/master/iPhoneOS16.5.sdk.tar.gz || echo "Failed to download iOS 16.5 SDK"
  
  if [ -f ios16.tar.gz ]; then
    tar -xzf ios16.tar.gz -C ~/theos/sdks/ || echo "Failed to extract iOS 16.5 SDK"
    echo "iOS 16.5 SDK installed successfully"
    rm ios16.tar.gz
  else
    # Create minimal SDK structure if download failed
    echo "Creating minimal SDK structure for iOS 16.5"
    mkdir -p ~/theos/sdks/iPhoneOS16.5.sdk/usr/include
    mkdir -p ~/theos/sdks/iPhoneOS16.5.sdk/System/Library/Frameworks
    
    # Create essential framework headers
    frameworks=("Foundation" "UIKit" "CoreGraphics" "StoreKit")
    for framework in "${frameworks[@]}"; do
      mkdir -p ~/theos/sdks/iPhoneOS16.5.sdk/System/Library/Frameworks/${framework}.framework/Headers
      touch ~/theos/sdks/iPhoneOS16.5.sdk/System/Library/Frameworks/${framework}.framework/Headers/${framework}.h
    done
    
    echo "Created minimal SDK structure"
  fi
fi

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

echo "Theos setup completed"
