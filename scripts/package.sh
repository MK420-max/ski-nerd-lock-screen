#!/bin/zsh
set -eu
cd "${0:A:h:h}"
[[ "$(uname -m)" == arm64 ]] || { print "Release packaging requires Apple silicon."; exit 1; }
command -v node >/dev/null
zsh src/build.sh
python3 scripts/prepare-runtime.py build/runtime-config
python3 -m PyInstaller --paths build/runtime-config --noconfirm --clean --onedir --name SkiNerdResolver --distpath build/resolver --workpath build/pyinstaller --specpath build --collect-all yt_dlp src/Resolver.py
bundle="dist/Ski Nerd Lock Screen 1.0"
mkdir -p "$bundle"
for name in 'Ski Nerd Lock Screen.app' 'Ski Nerd Lock Screen Helper.app' 'Mountain Cams.saver'; do ditto "build/$name" "$bundle/$name"; done
ditto build/resolver/SkiNerdResolver "$bundle/ResolverRuntime"
cp "$(command -v node)" "$bundle/ResolverRuntime/node"
codesign --force --sign - "$bundle/ResolverRuntime/node"
python3 scripts/collect-licenses.py "$bundle/ThirdPartyLicenses"
cp scripts/install.command "$bundle/Install.command"
cp README.md README.zh-CN.md LICENSE THIRD_PARTY_NOTICES.md "$bundle/"
ditto docs "$bundle/docs"
cd dist
ditto -c -k --keepParent --norsrc --noextattr 'Ski Nerd Lock Screen 1.0' 'Ski-Nerd-Lock-Screen-1.0-macOS-arm64.zip'
shasum -a 256 Ski-Nerd-Lock-Screen-1.0-macOS-arm64.zip > SHA256SUMS.txt
