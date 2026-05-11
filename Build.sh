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

xcodebuild \
    -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Debug \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Debug-iphoneos/$APPLICATION_NAME.app"

else

xcodebuild \
    -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Release-iphoneos/$APPLICATION_NAME.app"

fi

TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"

echo "[*] Copying app..."
cp -R "$DD_APP_PATH" "$TARGET_APP"

echo "[*] Injecting tools..."

TOOLS_SOURCE="$WORKING_LOCATION/tools"
TOOLS_DEST="$TARGET_APP/tools"

mkdir -p "$TOOLS_DEST"

if [ -d "$TOOLS_SOURCE" ]; then
    cp -R "$TOOLS_SOURCE/"* "$TOOLS_DEST/" || true

    chmod +x "$TOOLS_DEST/"* || true

    echo "[+] tools injected into:"
    echo "$TOOLS_DEST"
else
    echo "[!] tools folder not found"
fi

echo "[*] Stripping signature..."

codesign --remove "$TARGET_APP"

if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

echo "[*] Packaging IPA..."

mkdir Payload

cp -R "$TARGET_APP" "Payload/$APPLICATION_NAME.app"

zip -vr "$APPLICATION_NAME.ipa" Payload

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
