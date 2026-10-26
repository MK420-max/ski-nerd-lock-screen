import AppKit
import UniformTypeIdentifiers

private final class ResortForm: NSView, NSTextFieldDelegate {
    private let preset = NSPopUpButton()
    private let name = NSTextField()
    private let latitude = NSTextField()
    private let longitude = NSTextField()
    private let logoLabel = NSTextField(labelWithString: L("未选择", "None"))
    private var logoAsset: String?
    private var logoPath: String?
    private var selectedLogo: URL?
    private let cameraNames = [NSTextField(), NSTextField()]
    private let elevations = [NSTextField(), NSTextField()]
    private let addresses = [NSTextField(), NSTextField()]
    private let kinds = [NSPopUpButton(), NSPopUpButton()]
    private let snow = NSTextField()
    private var labels: [(NSTextField, String, String)] = []
    private var buttons: [(NSButton, String, String)] = []
    private func label(_ zh: String, _ en: String) -> NSTextField {
        let value = NSTextField(labelWithString: L(zh, en))
        labels.append((value, zh, en)); return value
    }
    private func button(_ zh: String, _ en: String, action: Selector) -> NSButton {
        let value = NSButton(title: L(zh, en), target: self, action: action)
        buttons.append((value, zh, en)); return value
    }

    init(title: String, settings: ResortSettings) {
        super.init(frame: NSRect(x: 0, y: 0, width: 504, height: 610))
        let heading = label(title, title == "上排雪场" ? "Top-row resort" : "Bottom-row resort")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        heading.frame = NSRect(x: 4, y: 568, width: 250, height: 30)
        addSubview(heading)
        preset.addItems(withTitles: [L("当前配置", "Current"), "Whistler", "Cypress", L("空白雪场", "Custom resort")])
        preset.frame = NSRect(x: 304, y: 570, width: 180, height: 28)
        preset.target = self; preset.action = #selector(changePreset)
        addSubview(preset)
        row("雪场名称", field: name, y: 526)
        name.delegate = self
        text("天气位置", y: 482)
        latitude.frame = NSRect(x: 110, y: 482, width: 180, height: 26)
        longitude.frame = NSRect(x: 302, y: 482, width: 182, height: 26)
        latitude.placeholderString = "纬度（可留空）"
        longitude.placeholderString = "经度（可留空）"
        addSubview(latitude); addSubview(longitude)
        for (title, x) in [("纬度", CGFloat(110)), ("经度", CGFloat(302))] {
            let label = label(title, title == "纬度" ? "Latitude" : "Longitude")
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: x, y: 510, width: 170, height: 16)
            addSubview(label)
        }
        text("白色 Logo", y: 439)
        let choose = button("选择…", "Choose…", action: #selector(chooseLogo))
        choose.frame = NSRect(x: 108, y: 436, width: 78, height: 30)
        addSubview(choose)
        let clear = button("清除", "Clear", action: #selector(clearLogo))
        clear.frame = NSRect(x: 187, y: 436, width: 65, height: 30)
        addSubview(clear)
        logoLabel.font = .systemFont(ofSize: 12)
        logoLabel.lineBreakMode = .byTruncatingMiddle
        logoLabel.frame = NSRect(x: 258, y: 441, width: 225, height: 22)
        addSubview(logoLabel)
        for i in 0..<2 {
            let y = CGFloat(376 - i * 130)
            let label = label("画面 \(i + 1)", "Camera \(i + 1)")
            label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.frame = NSRect(x: 4, y: y + 19, width: 100, height: 22)
            addSubview(label)
            cameraNames[i].placeholderString = "机位名称"
            cameraNames[i].frame = NSRect(x: 110, y: y + 17, width: 235, height: 26)
            elevations[i].placeholderString = "海拔 m"
            elevations[i].frame = NSRect(x: 357, y: y + 17, width: 127, height: 26)
            addSubview(cameraNames[i]); addSubview(elevations[i])
            let altitudeLabel = self.label("海拔（米）", "Elevation (m)")
            altitudeLabel.font = .systemFont(ofSize: 11)
            altitudeLabel.textColor = .secondaryLabelColor
            altitudeLabel.frame = NSRect(x: 357, y: y + 44, width: 127, height: 16)
            addSubview(altitudeLabel)
            kinds[i].addItems(withTitles: [L("直播", "Live"), L("定时图片", "Snapshot")])
            kinds[i].frame = NSRect(x: 3, y: y - 26, width: 100, height: 28)
            addSubview(kinds[i])
            addresses[i].placeholderString = "公开直播或图片的 HTTPS 地址"
            addresses[i].frame = NSRect(x: 110, y: y - 25, width: 374, height: 26)
            addresses[i].toolTip = "直播支持直接 HLS (.m3u8)、YouTube 或 CamStreamer；定时图片每60秒读取。"
            addSubview(addresses[i])
        }
        row("雪尺图片", field: snow, y: 122)
        snow.placeholderString = "雪尺摄像头的 HTTPS 图片地址，可留空"
        let hint = label("天气按这里的位置和各机位海拔估算；位置留空时仅保留本地天气。没有摄像头来源可留空，画面会显示待设置。Logo 支持透明 PNG 或 PDF。", "Weather uses this location and each camera’s elevation. Leave both coordinates blank to hide resort weather. Empty camera URLs show an unconfigured state. Logos accept transparent PNG or PDF.")
        hint.maximumNumberOfLines = 0
        hint.cell?.wraps = true
        hint.cell?.isScrollable = false
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 4, y: 33, width: 480, height: 65)
        addSubview(hint)
        fill(settings)
        updateLanguage()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func text(_ title: String, y: CGFloat) {
        let label = label(title, ["雪场名称": "Resort name", "天气位置": "Weather", "白色 Logo": "White logo", "雪尺图片": "Snow image"][title] ?? title)
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 4, y: y + 3, width: 100, height: 22)
        addSubview(label)
    }
    private func row(_ title: String, field: NSTextField, y: CGFloat) {
        text(title, y: y)
        field.frame = NSRect(x: 110, y: y, width: 374, height: 26)
        addSubview(field)
    }
    func updateLanguage() {
        for (label, zh, en) in labels { label.stringValue = L(zh, en) }
        for (button, zh, en) in buttons { button.title = L(zh, en) }
        preset.item(at: 0)?.title = L("当前配置", "Current")
        preset.item(at: 3)?.title = L("空白雪场", "Custom resort")
        latitude.placeholderString = L("纬度（可留空）", "Latitude (optional)")
        longitude.placeholderString = L("经度（可留空）", "Longitude (optional)")
        for i in 0..<2 {
            cameraNames[i].placeholderString = L("机位名称", "Camera name")
            elevations[i].placeholderString = L("海拔 m", "Metres")
            addresses[i].placeholderString = L("公开直播或图片的 HTTPS 地址", "Public HTTPS stream or image URL")
            addresses[i].toolTip = L("直播支持直接 HLS (.m3u8)、YouTube 或 CamStreamer；定时图片每60秒读取。", "Live: direct HLS (.m3u8), YouTube or CamStreamer. Snapshots refresh every 60 seconds.")
            kinds[i].item(at: 0)?.title = L("直播", "Live")
            kinds[i].item(at: 1)?.title = L("定时图片", "Snapshot")
            cameraNames[i].setAccessibilityLabel(L("机位名称", "Camera name") + " \(i + 1)")
            addresses[i].setAccessibilityLabel(L("摄像头地址", "Camera URL") + " \(i + 1)")
            elevations[i].setAccessibilityLabel(L("海拔米数", "Elevation in metres") + " \(i + 1)")
        }
        name.setAccessibilityLabel(L("雪场名称", "Resort name"))
        latitude.setAccessibilityLabel(L("纬度", "Latitude"))
        longitude.setAccessibilityLabel(L("经度", "Longitude"))
        snow.setAccessibilityLabel(L("雪尺图片地址", "Snow-stake image URL"))
        snow.placeholderString = L("雪尺摄像头的 HTTPS 图片地址，可留空", "Public HTTPS snow-stake image URL (optional)")
        updateLogoLabel()
    }
    func fill(_ value: ResortSettings) {
        name.stringValue = value.name
        latitude.stringValue = value.latitude.map { String($0) } ?? ""
        longitude.stringValue = value.longitude.map { String($0) } ?? ""
        logoAsset = value.logoAsset; logoPath = value.logoPath; selectedLogo = nil
        updateLogoLabel()
        for i in 0..<2 {
            cameraNames[i].stringValue = value.cameras[i].name
            elevations[i].stringValue = String(format: "%.0f", value.cameras[i].elevation)
            addresses[i].stringValue = value.cameras[i].url
            kinds[i].selectItem(at: value.cameras[i].kind == .stream ? 0 : 1)
        }
        snow.stringValue = value.snowURL
        preset.selectItem(at: 0)
    }
    @objc private func changePreset() {
        switch preset.indexOfSelectedItem {
        case 1: fill(.whistler)
        case 2: fill(.cypress)
        case 3: fill(.empty)
        default: break
        }
    }
    func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSTextField === name, logoAsset != nil { clearLogo() }
    }
    @objc private func clearLogo() {
        logoAsset = nil; logoPath = nil; selectedLogo = nil
        updateLogoLabel()
    }
    private func updateLogoLabel() {
        logoLabel.stringValue = selectedLogo?.lastPathComponent ?? logoPath.map { _ in L("已选择的 Logo", "Selected logo") } ?? (logoAsset == "WhistlerLogo" ? L("Whistler 标志", "Whistler logo") : logoAsset == "CypressLogo" ? L("Cypress 标志", "Cypress logo") : L("未选择", "None"))
    }
    @objc private func chooseLogo() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .pdf]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L("选择雪场 Logo，透明背景最佳；预览中统一显示为白色。", "Choose a transparent resort logo. It will be displayed in white.")
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.selectedLogo = url
            self?.logoAsset = nil
            self?.updateLogoLabel()
        }
    }
    func value() throws -> ResortSettings {
        func trimmed(_ field: NSTextField) -> String { field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        func coordinate(_ field: NSTextField) throws -> Double? {
            let value = trimmed(field)
            if value.isEmpty { return nil }
            guard let number = Double(value) else { throw SettingsError(L("天气位置请输入数字经纬度，或同时留空。", "Use numeric latitude and longitude, or leave both blank.")) }
            return number
        }
        var cameras: [CameraSettings] = []
        for i in 0..<2 {
            guard let elevation = Double(trimmed(elevations[i])) else { throw SettingsError(L("机位海拔请输入米数。", "Enter camera elevation as a number in metres.")) }
            cameras.append(CameraSettings(name: trimmed(cameraNames[i]), elevation: elevation, url: trimmed(addresses[i]), kind: kinds[i].indexOfSelectedItem == 0 ? .stream : .image))
        }
        return ResortSettings(name: trimmed(name), latitude: try coordinate(latitude), longitude: try coordinate(longitude), cameras: cameras, snowURL: trimmed(snow), logoAsset: logoAsset, logoPath: selectedLogo?.path ?? logoPath)
    }
    func copySelectedLogo(for value: inout ResortSettings) throws -> URL? {
        guard let selectedLogo else { return nil }
        guard NSImage(contentsOf: selectedLogo) != nil else { throw SettingsError(L("无法读取所选 Logo，请换一个透明 PNG 或 PDF。", "The logo could not be read. Choose a transparent PNG or PDF.")) }
        let folder = WallSettings.directory.appendingPathComponent("Logos")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(UUID().uuidString + "." + selectedLogo.pathExtension)
        try FileManager.default.copyItem(at: selectedLogo, to: destination)
        value.logoPath = destination.path
        return destination
    }
}

final class SettingsWindowController: NSWindowController {
    private var forms: [ResortForm] = []
    private let language = NSPopUpButton()
    private let tabs = NSSegmentedControl()
    private let status = NSTextField(labelWithString: "")
    private let heading = NSTextField(labelWithString: "")
    private let restore = NSButton()
    private let cancelButton = NSButton()
    private let saveButton = NSButton()
    var onSave: (() -> Void)?
    var onLanguageChange: (() -> Void)?
    init() {
        let settings = (try? WallSettings.read()) ?? .defaults
        AppText.language = settings.language ?? .system
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 552, height: 760), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Ski Nerd Lock Screen"
        window.center()
        let content = window.contentView!
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        heading.frame = NSRect(x: 24, y: 712, width: 280, height: 30)
        content.addSubview(heading)
        language.addItems(withTitles: ["System / 系统", "简体中文", "English"])
        language.selectItem(at: AppLanguage.allCases.firstIndex(of: AppText.language) ?? 0)
        language.frame = NSRect(x: 342, y: 715, width: 186, height: 28)
        language.target = self; language.action = #selector(changeLanguage)
        language.setAccessibilityLabel("Language / 语言")
        content.addSubview(language)
        tabs.segmentCount = 2
        tabs.trackingMode = .selectOne
        tabs.selectedSegment = 0
        tabs.frame = NSRect(x: 24, y: 670, width: 504, height: 28)
        tabs.target = self; tabs.action = #selector(changeTab)
        content.addSubview(tabs)
        for i in 0..<2 {
            let form = ResortForm(title: i == 0 ? "上排雪场" : "下排雪场", settings: settings.resorts[i])
            form.frame.origin = NSPoint(x: 24, y: 50)
            form.isHidden = i != 0
            forms.append(form); content.addSubview(form)
        }
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 24, y: 48, width: 504, height: 20)
        content.addSubview(status)
        for button in [restore, cancelButton, saveButton] { content.addSubview(button); button.target = self }
        restore.frame = NSRect(x: 22, y: 12, width: 150, height: 30)
        restore.action = #selector(restoreDefaults)
        cancelButton.frame = NSRect(x: 282, y: 12, width: 90, height: 32)
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        saveButton.frame = NSRect(x: 376, y: 12, width: 154, height: 32)
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        updateLanguage()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func updateLanguage() {
        heading.stringValue = L("摄像头设置", "Camera settings")
        tabs.setLabel(L("上排雪场", "Top row"), forSegment: 0)
        tabs.setLabel(L("下排雪场", "Bottom row"), forSegment: 1)
        status.stringValue = L("保存后两块屏幕会同步更新。", "Save to update the preview and screen saver on both displays.")
        restore.title = L("载入默认雪场", "Load defaults")
        cancelButton.title = L("取消", "Cancel")
        saveButton.title = L("保存并预览", "Save & Preview")
        forms.forEach { $0.updateLanguage() }
        onLanguageChange?()
    }
    @objc private func changeLanguage() {
        AppText.language = AppLanguage.allCases[language.indexOfSelectedItem]
        updateLanguage()
    }
    @objc private func changeTab() {
        for (index, form) in forms.enumerated() { form.isHidden = index != tabs.selectedSegment }
    }
    @objc private func restoreDefaults() {
        forms[0].fill(.whistler); forms[1].fill(.cypress)
        status.stringValue = L("已载入默认雪场；点击保存后生效。", "Defaults loaded. Save to apply them.")
    }
    @objc private func cancel() {
        AppText.language = (try? WallSettings.read().language) ?? .system
        onLanguageChange?()
        window?.close()
    }
    @objc private func save() {
        var copied: [URL] = []
        do {
            window?.makeFirstResponder(nil)
            var settings = WallSettings(resorts: try forms.map { try $0.value() }, language: AppText.language)
            try settings.validate()
            for i in forms.indices {
                if let file = try forms[i].copySelectedLogo(for: &settings.resorts[i]) { copied.append(file) }
            }
            try settings.save()
            DistributedNotificationCenter.default().postNotificationName(Notification.Name("io.skinerd.lockscreen.settingsChanged"), object: nil, userInfo: nil, deliverImmediately: true)
            onSave?()
            window?.close()
        } catch {
            copied.forEach { try? FileManager.default.removeItem(at: $0) }
            let alert = NSAlert()
            alert.messageText = L("设置未保存", "Settings not saved")
            alert.informativeText = error.localizedDescription
            if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
        }
    }
}
