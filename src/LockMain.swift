import AppKit

final class LockWatcher: NSObject, NSApplicationDelegate {
    private var observer: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        observer = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            print("SYSTEM LOCK RECEIVED"); fflush(stdout)
            if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.ScreenSaver.Engine").isEmpty {
                print("STARTING MOUNTAIN CAMS"); fflush(stdout)
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
            }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        return false
    }
    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    }
}

@main
struct LockApplication {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.arguments.contains("--watch") {
            let watcher = LockWatcher()
            app.delegate = watcher
            withExtendedLifetime(watcher) { app.run() }
        } else {
            let launched = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
            if !launched {
                let alert = NSAlert()
                alert.messageText = L("无法启动系统屏保", "Could not start the screen saver")
                alert.informativeText = L("请在系统设置 → 墙纸 → 屏幕保护程序中选择 Mountain Cams。", "Choose Mountain Cams in System Settings → Wallpaper → Screen Saver.")
                alert.runModal()
            }
        }
    }
}
