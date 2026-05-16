#!/bin/bash

set -e

cd "$(dirname "$0")"

APPLICATION_NAME=Terminal

echo "[*] $APPLICATION_NAME Build Script"

rm -rf build

if ls *.ipa 1> /dev/null 2>&1; then
    rm -rf *.ipa
fi

WORKING_LOCATION="$(pwd)"
mkdir -p build
cd build

echo "[*] Building..."

if [[ $* == *--debug* ]]; then
    CONFIGURATION="Debug"
else
    CONFIGURATION="Release"
fi

SCHEME=$(xcodebuild -list -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" | awk '/Schemes:/ {getline; print $1}')
echo "[*] Using scheme: $SCHEME"

xcodebuild \
    -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED="NO"

APP_DIR="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/${CONFIGURATION}-iphoneos"

DD_APP_PATH=$(find "$APP_DIR" -maxdepth 1 -name "*.app" | head -n 1)

echo "[*] Found app: $DD_APP_PATH"

if [ -z "$DD_APP_PATH" ]; then
    echo "[!] ERROR: .app not found in $APP_DIR"
    exit 1
fi

TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"

echo "[*] Copying app..."
cp -R "$DD_APP_PATH" "$TARGET_APP"

echo "[*] Injecting tools..."

TOOLS_SOURCE="$WORKING_LOCATION/tools"
TOOLS_DEST="$TARGET_APP/tools"

mkdir -p "$TOOLS_DEST"

if [ -d "$TOOLS_SOURCE" ]; then
    cp -R "$TOOLS_SOURCE/"* "$TOOLS_DEST/" 2>/dev/null || true
    find "$TOOLS_DEST" -type f -exec chmod +x {} \; 2>/dev/null || true

    echo "[+] tools injected into:"
    echo "$TOOLS_DEST"
else
    echo "[!] tools folder not found"
fi

echo "[*] Stripping signature..."

codesign --remove "$TARGET_APP" 2>/dev/null || true

rm -rf "$TARGET_APP/_CodeSignature" 2>/dev/null || true
rm -rf "$TARGET_APP/embedded.mobileprovision" 2>/dev/null || true

echo "[*] Packaging IPA..."

mkdir -p Payload
cp -R "$TARGET_APP" "Payload/$APPLICATION_NAME.app"

zip -r "$APPLICATION_NAME.ipa" Payload > /dev/null

echo "[*] Cleaning..."

rm -rf Payload
cd ..

if [[ $* == *--debug* ]]; then
    mv "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa" \
       "./$APPLICATION_NAME.debug.ipa"
else
    mv "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa" .
fi

rm -rf "$WORKING_LOCATION/build"

echo "[+] Done"
