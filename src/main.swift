import AppKit

final class PreviewDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var saver: MountainCamsView?
    private var settingsWindow: SettingsWindowController?
    private var displayWindows: [NSWindow] = []
    private var displaySavers: [MountainCamsView] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppText.language = (try? WallSettings.read().language) ?? .system
        updateMenu()
        if ProcessInfo.processInfo.arguments.contains("--verify-displays") { previewAllDisplays() }
        else if ProcessInfo.processInfo.arguments.contains("--preview") { showPreview() }
        else { openSettings(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
    private func updateMenu() {
        let menu = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu()
        for (title, action, key) in [
            (L("摄像头设置…", "Camera Settings…"), #selector(openSettings(_:)), ","),
            (L("预览锁屏", "Preview Lock Screen"), #selector(showPreview), "p"),
            (L("在所有屏幕预览", "Preview on All Displays"), #selector(previewAllDisplays), "d"),
            (L("退出 Ski Nerd Lock Screen", "Quit Ski Nerd Lock Screen"), #selector(NSApplication.terminate(_:)), "q")
        ] {
            let item = appMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            if key != "q" { item.target = self }
            if key == "d" { item.keyEquivalentModifierMask = [.command, .shift] }
        }
        root.submenu = appMenu; menu.addItem(root); NSApp.mainMenu = menu
    }
    @objc func showPreview() {
        if window == nil {
            let preview = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1244, height: 810), styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            preview.title = L("Ski Nerd · 预览（此窗口不锁屏）", "Ski Nerd · Preview (does not lock the Mac)")
            preview.titleVisibility = .hidden
            preview.titlebarAppearsTransparent = true
            preview.isMovableByWindowBackground = true
            preview.minSize = NSSize(width: 1040, height: 700)
            preview.appearance = NSAppearance(named: .darkAqua)
            preview.isReleasedWhenClosed = false
            preview.delegate = self
            let view = MountainCamsView(frame: preview.contentView!.bounds, isPreview: true)!
            preview.contentView = view
            preview.center()
            window = preview; saver = view
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openSettings(_ sender: Any?) {
        if settingsWindow?.window?.isVisible != true {
            let controller = SettingsWindowController()
            controller.onSave = { [weak self] in self?.updateMenu(); self?.showPreview() }
            controller.onLanguageChange = { [weak self] in self?.updateMenu() }
            settingsWindow = controller
        }
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }
    @objc func previewAllDisplays() {
        guard displayWindows.isEmpty else { return }
        showPreview()
        for (index, screen) in NSScreen.screens.enumerated() {
            if index == 0 {
                window?.setFrame(screen.frame, display: true)
                window?.title = L("内置屏 · 锁屏布局预览", "Built-in Display · Lock Screen Preview")
                continue
            }
            let extra = NSWindow(contentRect: screen.frame, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            extra.title = L("外接屏", "External Display") + " \(index) · " + L("锁屏布局预览", "Lock Screen Preview")
            extra.titlebarAppearsTransparent = true
            extra.isReleasedWhenClosed = false
            extra.delegate = self
            let view = MountainCamsView(frame: extra.contentView!.bounds, isPreview: true)!
            extra.contentView = view
            extra.setFrame(screen.frame, display: true)
            extra.makeKeyAndOrderFront(nil)
            displayWindows.append(extra); displaySavers.append(view)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === window { saver?.stopAnimation(); saver = nil; window = nil }
        else if let index = displayWindows.firstIndex(where: { $0 === closing }) {
            displaySavers[index].stopAnimation()
            displaySavers.remove(at: index); displayWindows.remove(at: index)
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        saver?.stopAnimation(); displaySavers.forEach { $0.stopAnimation() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = PreviewDelegate()
app.delegate = delegate
app.run()
