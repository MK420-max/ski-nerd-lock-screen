#!/bin/zsh
set -eu
cd "${0:A:h}"
destination="${PWD:h}/build"
mkdir -p "$destination"
output=$(mktemp -d /tmp/mountain-cams-build.XXXXXX)
trap 'rm -rf "$output"' EXIT
saver="$output/Mountain Cams.saver"
preview="$output/Ski Nerd Lock Screen.app"
mkdir -p "$saver/Contents/MacOS" "$preview/Contents/MacOS" "$saver/Contents/Resources" "$preview/Contents/Resources"
cp Resources/WhistlerLogo.png Resources/CypressLogo.png "$saver/Contents/Resources/"
cp Resources/WhistlerLogo.png Resources/CypressLogo.png "$preview/Contents/Resources/"
cat > "$saver/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.skinerd.lockscreen</string>
<key>CFBundleName</key><string>Mountain Cams</string>
<key>CFBundleExecutable</key><string>MountainCams</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>36</string>
<key>NSPrincipalClass</key><string>MountainCamsView</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST
cat > "$preview/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.skinerd.lockscreen.Preview</string>
<key>CFBundleName</key><string>Ski Nerd Lock Screen</string>
<key>CFBundleExecutable</key><string>MountainCamsPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>36</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDisplayName</key><string>Ski Nerd Lock Screen</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST
xcrun swiftc -O -target arm64-apple-macos26.0 -emit-library -module-name MountainCams -framework AppKit -framework ScreenSaver -framework AVFoundation Localization.swift CamWall.swift Forecast.swift SnowStake.swift ResortSettings.swift -o "$saver/Contents/MacOS/MountainCams"
xcrun swiftc -O -target arm64-apple-macos26.0 -framework AppKit -framework ScreenSaver -framework AVFoundation Localization.swift CamWall.swift Forecast.swift SnowStake.swift ResortSettings.swift SettingsWindow.swift main.swift -o "$preview/Contents/MacOS/MountainCamsPreview"
xattr -cr "$saver" "$preview"
codesign --force --sign - "$saver"
codesign --force --sign - "$preview"
launcher="$output/Ski Nerd Lock Screen Helper.app"
ditto "$preview" "$launcher"
rm -rf "$launcher/Contents/Resources"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.skinerd.lockscreen.Lock' "$launcher/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName 雪场锁屏' "$launcher/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.0' "$launcher/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 36' "$launcher/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$launcher/Contents/Info.plist"
xcrun swiftc -O -target arm64-apple-macos26.0 -framework AppKit Localization.swift LockMain.swift -o "$launcher/Contents/MacOS/MountainCamsPreview"
codesign --force --sign - "$launcher"
# Verify the sealed build before Desktop's file provider adds Finder metadata to copies.
codesign --verify --deep --strict "$saver"
codesign --verify --deep --strict "$preview"
codesign --verify --deep --strict "$launcher"
# Remove the retired map from earlier merged build outputs before copying the signed bundles.
rm -f "$destination/Mountain Cams.saver/Contents/Resources/CypressRoadMap.png" "$destination/Ski Nerd Lock Screen.app/Contents/Resources/CypressRoadMap.png"
ditto "$saver" "$destination/Mountain Cams.saver"
ditto "$preview" "$destination/Ski Nerd Lock Screen.app"
ditto "$launcher" "$destination/Ski Nerd Lock Screen Helper.app"
xattr -cr "$destination/Mountain Cams.saver" "$destination/Ski Nerd Lock Screen.app" "$destination/Ski Nerd Lock Screen Helper.app"
echo "Built Ski Nerd Lock Screen bundles"
