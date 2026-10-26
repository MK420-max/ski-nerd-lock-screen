#!/bin/zsh
set -eu
root="${0:A:h}"
if [[ ! -d "$root/Ski Nerd Lock Screen.app" ]]; then root="${root:h}/build"; fi
[[ -d "$root/Ski Nerd Lock Screen.app" && -d "$root/ResolverRuntime" ]] || { print "Release files missing / 请解压完整发布包。"; exit 1; }
[[ "$(uname -m)" == arm64 ]] || { print "Apple silicon is required / 当前安装包需要 Apple 芯片。"; exit 1; }
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 26 )) || { print "macOS 26 or later is required / 需要 macOS 26 或更新版本。"; exit 1; }
support="$HOME/Library/Application Support/MountainCams"
mkdir -p "$HOME/Applications" "$HOME/Library/Screen Savers" "$HOME/Library/LaunchAgents" "$support/Backups"
backup="$support/Backups/$(date +%Y%m%d-%H%M%S)-1.0"
mkdir -p "$backup"
for label in io.skinerd.lockscreen.Resolver io.skinerd.lockscreen.LockWatcher; do
    launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
done
install_item() {
    local source="$1" target="$2" stage="$2.installing-$$"
    ditto "$source" "$stage"
    if [[ -d "$stage/Contents" ]]; then codesign --verify --deep --strict "$stage"; fi
    if [[ -e "$target" ]]; then mv "$target" "$backup/${target:t}"; fi
    mv "$stage" "$target"
}
install_item "$root/Ski Nerd Lock Screen.app" "$HOME/Applications/Ski Nerd Lock Screen.app"
install_item "$root/Ski Nerd Lock Screen Helper.app" "$HOME/Applications/Ski Nerd Lock Screen Helper.app"
install_item "$root/Mountain Cams.saver" "$HOME/Library/Screen Savers/Mountain Cams.saver"
install_item "$root/ResolverRuntime" "$support/ResolverRuntime"
write_agent() {
    local label="$1" executable="$2" plist="$HOME/Library/LaunchAgents/$1.plist"
    /usr/bin/plutil -create xml1 "$plist"
    /usr/libexec/PlistBuddy -c "Add :Label string $label" "$plist"
    /usr/libexec/PlistBuddy -c 'Add :ProgramArguments array' "$plist"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string $executable" "$plist"
    if [[ "$label" == *.LockWatcher ]]; then /usr/libexec/PlistBuddy -c 'Add :ProgramArguments:1 string --watch' "$plist"; fi
    /usr/libexec/PlistBuddy -c 'Add :RunAtLoad bool true' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :KeepAlive bool true' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :ThrottleInterval integer 10' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :LimitLoadToSessionType string Aqua' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :EnvironmentVariables dict' "$plist"
    /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:SKI_NERD_NODE string $support/ResolverRuntime/node" "$plist"
    /usr/libexec/PlistBuddy -c "Add :StandardOutPath string $support/$label.log" "$plist"
    /usr/libexec/PlistBuddy -c "Add :StandardErrorPath string $support/$label.log" "$plist"
    launchctl bootstrap "gui/$(id -u)" "$plist"
    launchctl print "gui/$(id -u)/$label" >/dev/null
}
write_agent io.skinerd.lockscreen.Resolver "$support/ResolverRuntime/SkiNerdResolver"
write_agent io.skinerd.lockscreen.LockWatcher "$HOME/Applications/Ski Nerd Lock Screen Helper.app/Contents/MacOS/MountainCamsPreview"
print "Installed / 安装完成。"
print "Open / 打开： $HOME/Applications/Ski Nerd Lock Screen.app"
print "System Settings → Wallpaper → Screen Saver → Mountain Cams"
print "系统设置 → 墙纸 → 屏幕保护程序 → Mountain Cams"
print "Existing camera settings are preserved / 已保留现有摄像头配置。"
