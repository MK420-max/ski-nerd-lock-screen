import AppKit
import AVFoundation
import ScreenSaver
import OSLog
import Darwin

final class GlassCard: NSGlassEffectView {
    let content = NSView()
    init(radius: CGFloat = 20) {
        super.init(frame: .zero)
        style = .regular
        cornerRadius = radius
        contentView = content
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class WeatherCard: NSView {
    private let name: NSTextField
    private let temperature = NSTextField(labelWithString: "—°C")
    private let details = NSTextField(labelWithString: L("天气加载中", "Loading weather"))
    private let icon = NSImageView()
    init(name: String) {
        self.name = NSTextField(labelWithString: name)
        super.init(frame: .zero)
        addSubview(icon)
        icon.contentTintColor = NSColor(white: 0.9, alpha: 1)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        for label in [self.name, temperature, details] { addSubview(label); label.textColor = .white }
        self.name.font = .systemFont(ofSize: 18, weight: .medium)
        self.name.textColor = NSColor(white: 0.8, alpha: 1)
        temperature.font = .systemFont(ofSize: 18, weight: .semibold)
        details.font = .systemFont(ofSize: 18)
        details.maximumNumberOfLines = 1
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let labels = [temperature, name, details]
        let widths = labels.map { ceil(($0.stringValue as NSString).size(withAttributes: [.font: $0.font!]).width) + 2 }
        let gap: CGFloat = 14
        let totalWidth = 20 + gap + widths.reduce(0, +) + gap * 2
        var x = (bounds.width - totalWidth) / 2
        icon.frame = NSRect(x: x, y: 2, width: 20, height: 20)
        x += 20 + gap
        for (label, width) in zip(labels, widths) {
            label.frame = NSRect(x: x, y: 1, width: width, height: 24)
            x += width + gap
        }
    }
    func localize() { details.stringValue = L("天气加载中", "Loading weather") }
    func update(temp: Double, feels: Double, wind: Double, condition: String) {
        temperature.stringValue = String(format: "%.1f°C", temp)
        name.stringValue = "Burnaby · " + AppText.condition(condition)
        details.stringValue = String(format: L("体感 %.1f°C", "Feels %.1f°C"), feels)
        needsLayout = true
        toolTip = String(format: L("%@ · 体感 %.1f°C · 风 %.0f km/h", "%@ · Feels %.1f°C · Wind %.0f km/h"), condition, feels, wind)
        let symbol = condition.contains("雪") ? "cloud.snow.fill" : condition.contains("雨") ? "cloud.rain.fill" : condition == "晴" ? "sun.max.fill" : "cloud.fill"
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: AppText.condition(condition))
    }
}

final class CameraPanel: NSView {
    private let video = NSView()
    private let player = AVPlayer()
    // Ordinary bitmap layers survive the screen saver's cross-display composition.
    private let videoLayer = CALayer()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var frameTimer: Timer?
    private var renderedFrames = 0
    private var lastFrame = Date.distantPast
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let caption: NSTextField
    private let status = NSTextField(labelWithString: "●")
    private let weather = NSTextField(labelWithString: "—°C")
    private let footer = NSView()
    private let captionGradient = CAGradientLayer()
    private let address: URL?
    private let kind: CameraSettings.Kind
    private let message = NSTextField(labelWithString: L("连接中", "Connecting"))
    private let cameraName: String
    private let location: String
    private var lastProgress = Date()
    private var lastTime = -1.0
    private var timer: Timer?
    private var request: URLSessionDataTask?
    private var active = false
    private var generation = 0
    private let logger = Logger(subsystem: "io.skinerd.lockscreen", category: "playback")

    init(name: String, location: String, url: String, kind: CameraSettings.Kind = .stream) {
        cameraName = name
        self.location = location
        address = url.isEmpty ? nil : URL(string: url)
        self.kind = kind
        caption = NSTextField(labelWithString: location)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.04, alpha: 1).cgColor
        layer?.cornerRadius = 13
        layer?.masksToBounds = true
        video.wantsLayer = true
        video.layer?.addSublayer(videoLayer)
        videoLayer.contentsGravity = .resizeAspectFill
        videoLayer.masksToBounds = true
        player.isMuted = true
        player.allowsExternalPlayback = false
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = .white
        caption.lineBreakMode = .byTruncatingTail
        addSubview(video)
        message.font = .systemFont(ofSize: 16, weight: .medium)
        message.textColor = NSColor(white: 1, alpha: 0.65)
        message.alignment = .center
        addSubview(message)
        addSubview(footer)
        footer.wantsLayer = true
        captionGradient.colors = [NSColor(white: 0, alpha: 0.82).cgColor,
                                  NSColor(white: 0, alpha: 0.32).cgColor,
                                  NSColor.clear.cgColor]
        captionGradient.locations = [0, 0.45, 1]
        footer.layer?.addSublayer(captionGradient)
        for label in [caption, status, weather] { footer.addSubview(label) }
        weather.font = .systemFont(ofSize: 14, weight: .medium)
        weather.textColor = .white
        weather.lineBreakMode = .byTruncatingTail
        weather.alignment = .right
        status.font = .systemFont(ofSize: 8, weight: .medium)
        status.alignment = .center
        status.textColor = .systemOrange
        setAccessibilityLabel("\(name) \(location) " + (kind == .image ? L("图片快照，每60秒读取", "Snapshot, refreshed every 60 seconds") : L("实时摄像头", "Live camera")))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        video.frame = bounds
        message.frame = NSRect(x: 12, y: bounds.midY - 12, width: max(0, bounds.width - 24), height: 24)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = video.bounds
        footer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 66)
        captionGradient.frame = footer.bounds
        CATransaction.commit()
        let textWidth = (caption.stringValue as NSString).size(withAttributes: [.font: caption.font!]).width + 8
        let captionWidth = min(textWidth, max(0, bounds.width - 80))
        caption.frame = NSRect(x: 18, y: 11, width: captionWidth, height: 20)
        status.frame = NSRect(x: max(0, bounds.width - 20), y: 12, width: 10, height: 17)
        let weatherWidth = max(0, bounds.width - captionWidth - 52)
        weather.frame = NSRect(x: captionWidth + 22, y: 11, width: weatherWidth, height: 20)
    }
    func updateWeather(temp: Double, feels: Double, wind: Double) {
        weather.stringValue = String(format: "%.1f°C", temp)
        weather.toolTip = String(format: L("体感 %.1f°C · 风 %.0f km/h", "Feels %.1f°C · Wind %.0f km/h"), feels, wind)
    }
    func start() {
        guard !active else { return }
        active = true
        guard address != nil else {
            message.stringValue = L("未设置摄像头", "Camera not configured")
            status.textColor = .secondaryLabelColor
            return
        }
        if kind == .image {
            reloadSnapshot()
            let next = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.reloadSnapshot() }
            timer = next
            RunLoop.main.add(next, forMode: .common)
            return
        }
        reload()
        let next = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.sample() }
        timer = next
        RunLoop.main.add(next, forMode: .common)
        let frames = Timer(timeInterval: 1.0 / 12, repeats: true) { [weak self] _ in self?.renderFrame() }
        frameTimer = frames
        RunLoop.main.add(frames, forMode: .common)
    }
    func stop() {
        guard active else { return }
        active = false
        generation += 1
        timer?.invalidate(); timer = nil
        frameTimer?.invalidate(); frameTimer = nil
        request?.cancel(); request = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        videoOutput = nil
        videoLayer.contents = nil
        renderedFrames = 0
        lastFrame = .distantPast
    }
    private func reload() {
        guard active, let address else { return }
        generation += 1
        let requestID = generation
        request?.cancel()
        lastProgress = Date()
        lastTime = -1
        status.toolTip = L("连接中", "Connecting")
        status.textColor = .systemOrange
        logger.notice("\(self.cameraName, privacy: .public) \(self.location, privacy: .public) NATIVE connecting")
        if address.scheme != "http" {
            play(address)
            return
        }
        request = URLSession.shared.dataTask(with: URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)) { [weak self] data, response, error in
            let result = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: String]
            DispatchQueue.main.async {
                guard let self, self.active, self.generation == requestID else { return }
                self.request = nil
                if (response as? HTTPURLResponse)?.statusCode == 200,
                   let text = result?["url"], let url = URL(string: text), url.scheme == "https" {
                    self.play(url)
                } else {
                    self.status.toolTip = L("连接失败", "Connection failed")
                    self.logger.error("\(self.cameraName, privacy: .public) stream resolution failed")
                }
            }
        }
        request?.resume()
    }
    private func reloadSnapshot() {
        guard active, request == nil, let address else { return }
        let requestID = generation
        request = URLSession.shared.dataTask(with: URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)) { [weak self] data, response, error in
            let http = response as? HTTPURLResponse
            let valid = error == nil && http?.statusCode == 200 && http?.mimeType?.hasPrefix("image/") == true
            let image = valid ? data.flatMap { NSImage(data: $0) } : nil
            DispatchQueue.main.async {
                guard let self, self.active, self.generation == requestID else { return }
                self.request = nil
                if let pixels = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    self.videoLayer.contents = pixels
                    CATransaction.commit()
                    self.message.isHidden = true
                    self.renderedFrames += 1
                    self.status.textColor = .systemMint
                    self.status.toolTip = L("图片已获取 · 每60秒刷新", "Snapshot received · Refreshes every 60 seconds")
                } else {
                    self.status.textColor = .systemOrange
                    self.status.toolTip = L("图片更新失败 · 自动重试", "Snapshot failed · Retrying")
                    if self.videoLayer.contents == nil { self.message.stringValue = L("图片暂不可用 · 自动重试", "Snapshot unavailable · Retrying") }
                }
                self.logger.notice("SNAPSHOT \(self.cameraName, privacy: .public) \(self.location, privacy: .public) fetched=\(image != nil) frames=\(self.renderedFrames)")
            }
        }
        request?.resume()
    }
    private func play(_ url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 8
        item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.suppressesPlayerRendering = true
        item.add(output)
        videoOutput = output
        player.replaceCurrentItem(with: item)
        player.play()
    }
    private func renderFrame() {
        guard active, let output = videoOutput else { return }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil),
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { return }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        // Copy the pixels so the layer never depends on a decoder-owned surface.
        let pixels = Data(bytes: base, count: stride * height)
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                  bitsPerPixel: 32, bytesPerRow: stride, space: Self.colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.contents = image
        message.isHidden = true
        CATransaction.commit()
        renderedFrames += 1
        lastFrame = Date()
    }
    private func sample() {
        guard active else { return }
        let seconds = player.currentTime().seconds
        let time = seconds.isFinite ? seconds : 0
        let item = player.currentItem
        let displayed = renderedFrames > 0 && Date().timeIntervalSince(lastFrame) < 10
        let ready = displayed && item?.status == .readyToPlay ? 4 : 0
        let error = (item?.error as NSError?)?.code ?? 0
        if ready == 4 && error == 0 && lastTime >= 0 && time > lastTime + 0.1 {
            lastProgress = Date()
            status.toolTip = L("播放中", "Playing")
            status.textColor = .systemMint
        }
        lastTime = time
        let elapsed = Date().timeIntervalSince(lastProgress)
        if elapsed > 20 {
            status.toolTip = L("缓冲中", "Buffering"); status.textColor = .systemOrange
            if renderedFrames == 0 { message.stringValue = L("画面暂不可用 · 自动重试", "Camera unavailable · Retrying") }
        }
        if elapsed > 20, let range = item?.seekableTimeRanges.last?.timeRangeValue {
            let edge = CMTimeRangeGetEnd(range).seconds
            if edge.isFinite && edge > time + 4 {
                player.seek(to: CMTime(seconds: edge - 2, preferredTimescale: 600))
                player.play()
            }
        }
        let displayID = (window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        logger.notice("\(self.cameraName, privacy: .public) \(self.location, privacy: .public) time=\(time) ready=\(ready) error=\(error) display=\(displayed) frames=\(self.renderedFrames) screen=\(displayID) width=\(self.superview?.bounds.width ?? 0, privacy: .public)")
        if ProcessInfo.processInfo.arguments.contains("--verify") {
            print("PLAYBACK \(cameraName) \(location) time=\(time) ready=\(ready) error=\(error) display=\(displayed) frames=\(renderedFrames) screen=\(displayID)")
            fflush(stdout)
        }
        if elapsed > 60 { reload() }
    }
}

final class CamWall: NSView {
    private var panels: [CameraPanel] = []
    private var snowStakes: [SnowStakeView] = []
    private let configurationURL: URL
    private var configuration = WallSettings.defaults
    private var configurationStamp: Date?
    private var weatherGeneration = 0
    private let logos = [NSImageView(), NSImageView()]
    private let settingsButton = NSButton()
    private let clock = NSTextField(labelWithString: "")
    private let date = NSTextField(labelWithString: "")
    private let localWeather = WeatherCard(name: "Burnaby")
    private let resortRows = [GlassCard(radius: 22), GlassCard(radius: 22)]
    private let previewAvatar = NSImageView()
    private let previewName = NSTextField(labelWithString: "User")
    private let previewUnlockBackground = GlassCard(radius: 18)
    private let previewUnlock = NSTextField(labelWithString: "系统解锁区域")
    private let previewHint = NSTextField(labelWithString: "预览 · 实际锁屏由 macOS 显示密码与 Touch ID")
    private let resortNames = (0..<2).map { _ in NSTextField(labelWithString: "") }
    private let precipitation = (0..<2).map { _ in NSTextField(labelWithString: L("24h预报 · 加载中", "24h forecast · Loading")) }
    private let backdrop = CAGradientLayer()
    private let scenery = CALayer()
    private var wallpaperKey = ""
    private var wallpaperGenerator: AVAssetImageGenerator?
    private var wallpaperObserver: NSObjectProtocol?
    private let wallpaperLog = Logger(subsystem: "io.skinerd.lockscreen", category: "wallpaper")
    private let source = NSTextField(labelWithString: L("天气：Open-Meteo 模型估算 · 各机位按对应区域海拔取值 · 每10分钟刷新", "Weather: Open-Meteo model estimates · Camera elevation · Updated every 10 minutes"))
    private var clockTimer: Timer?
    private var weatherTimer: Timer?
    private var weatherTask: URLSessionDataTask?
    private var wallpaperTimer: Timer?
    private var lastWeatherSource = "Open-Meteo · 天气尚未加载"
    private let showsClock: Bool
    init(frame: NSRect, showsClock: Bool, settingsURL: URL = WallSettings.fileURL) {
        self.configurationURL = settingsURL
        self.configuration = (try? WallSettings.read(from: settingsURL)) ?? .defaults
        self.showsClock = showsClock
        super.init(frame: frame)
        AppText.language = configuration.language ?? .system
        applyLanguage()
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)
        layer?.backgroundColor = NSColor(red: 0.035, green: 0.055, blue: 0.08, alpha: 1).cgColor
        scenery.contentsGravity = .resizeAspectFill
        layer?.addSublayer(scenery)
        backdrop.colors = [NSColor(white: 0, alpha: 0.18).cgColor,
                           NSColor(white: 0, alpha: 0.34).cgColor]
        layer?.addSublayer(backdrop)
        for i in 0..<2 {
            let row = resortRows[i]
            row.tintColor = NSColor(white: 0.8, alpha: 0.08)
            row.wantsLayer = true
            row.layer?.cornerRadius = 22
            row.layer?.borderWidth = 0.7
            row.layer?.borderColor = NSColor(white: 1, alpha: 0.34).cgColor
            addSubview(row)
            row.content.addSubview(logos[i])
            logos[i].imageScaling = .scaleProportionallyUpOrDown
            logos[i].contentTintColor = .white
            row.content.addSubview(resortNames[i])
            row.content.addSubview(precipitation[i])
            resortNames[i].font = .systemFont(ofSize: 34, weight: .semibold)
            resortNames[i].maximumNumberOfLines = 2
            resortNames[i].cell?.isScrollable = false
            resortNames[i].cell?.wraps = true
            resortNames[i].lineBreakMode = .byWordWrapping
            resortNames[i].textColor = .white
            resortNames[i].alignment = .center
            precipitation[i].font = .systemFont(ofSize: 12, weight: .medium)
            precipitation[i].maximumNumberOfLines = 2
            precipitation[i].textColor = NSColor(white: 0.92, alpha: 1)
            precipitation[i].lineBreakMode = .byWordWrapping
            precipitation[i].alignment = .center
        }
        // Keep decoded bitmaps out of glass-effect containers in the lock-screen host.
        buildResortViews()
        addSubview(localWeather)
        previewAvatar.image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: L("系统账户区域示意", "System account placeholder"))
        previewAvatar.contentTintColor = NSColor(white: 1, alpha: 0.8)
        previewAvatar.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 56, weight: .light)
        previewAvatar.isHidden = !showsClock
        addSubview(previewAvatar)
        previewUnlockBackground.isHidden = !showsClock
        addSubview(previewUnlockBackground)
        for label in [previewName, previewUnlock, previewHint] {
            label.textColor = .white
            label.alignment = .center
            label.isHidden = !showsClock
            addSubview(label)
        }
        previewName.font = .systemFont(ofSize: 18, weight: .semibold)
        previewUnlock.font = .systemFont(ofSize: 14)
        previewUnlock.textColor = NSColor(white: 1, alpha: 0.75)
        previewHint.font = .systemFont(ofSize: 11)
        previewHint.textColor = NSColor(white: 1, alpha: 0.7)
        for label in [clock, date, source] {
            label.textColor = .white
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        clock.font = .monospacedDigitSystemFont(ofSize: 136, weight: .medium)
        clock.alignment = .center
        date.font = .systemFont(ofSize: 18, weight: .medium)
        date.alignment = .center
        clock.isHidden = !showsClock
        date.isHidden = !showsClock
        date.textColor = NSColor(white: 0.72, alpha: 1)
        source.font = .systemFont(ofSize: 10)
        source.alignment = .left
        source.textColor = NSColor(white: 0.63, alpha: 1)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("设置雪场", "Camera settings"))
        settingsButton.isBordered = false
        settingsButton.contentTintColor = NSColor(white: 1, alpha: 0.8)
        settingsButton.action = NSSelectorFromString("openSettings:")
        settingsButton.toolTip = L("设置雪场", "Camera settings")
        settingsButton.isHidden = !showsClock
        addSubview(settingsButton)
        configurationStamp = (try? configurationURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(settingsDidChange(_:)), name: Notification.Name("io.skinerd.lockscreen.settingsChanged"), object: nil)
        setFrameSize(frame.size)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { DistributedNotificationCenter.default().removeObserver(self) }
    private func applyLanguage() {
        previewName.stringValue = L("用户", "User")
        previewUnlock.stringValue = L("系统解锁区域", "System unlock area")
        previewHint.stringValue = L("预览 · 实际锁屏由 macOS 显示密码与 Touch ID", "Preview · macOS provides password and Touch ID on the lock screen")
        settingsButton.toolTip = L("设置雪场", "Camera settings")
        lastWeatherSource = L("Open-Meteo · 天气尚未加载", "Open-Meteo · Weather not loaded")
        localWeather.localize()
    }
    private func buildResortViews() {
        panels.forEach { $0.stop(); $0.removeFromSuperview() }
        snowStakes.forEach { $0.stop(); $0.removeFromSuperview() }
        panels.removeAll(); snowStakes.removeAll()
        for (i, resort) in configuration.resorts.enumerated() {
            resortNames[i].stringValue = resort.name
            resortNames[i].toolTip = resort.name
            var size: CGFloat = 26
            while size > 14 {
                let height = (resort.name as NSString).boundingRect(with: NSSize(width: 190, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height
                if height <= 32 { break }
                size -= 1
            }
            resortNames[i].font = .systemFont(ofSize: size, weight: .semibold)
            let image: NSImage?
            if let path = resort.logoPath { image = NSImage(contentsOfFile: path) }
            else if let asset = resort.logoAsset, let url = Bundle(for: CamWall.self).url(forResource: asset, withExtension: "png") { image = NSImage(contentsOf: url) }
            else { image = nil }
            image?.isTemplate = true
            logos[i].image = image
            logos[i].isHidden = image == nil
            resortNames[i].isHidden = image != nil
            precipitation[i].stringValue = resort.latitude == nil ? L("未设置天气位置", "Weather location not set") : L("24h预报 · 加载中", "24h forecast · Loading")
            for camera in resort.cameras {
                let panel = CameraPanel(name: resort.name.uppercased(), location: camera.caption, url: camera.playbackURL, kind: camera.kind)
                panels.append(panel); addSubview(panel)
            }
            let stake = SnowStakeView(name: resort.name, url: resort.snowURL)
            snowStakes.append(stake); addSubview(stake)
        }
        needsLayout = true
    }
    @objc private func settingsDidChange(_ notification: Notification) { reloadConfiguration() }
    private func reloadConfiguration() {
        let stamp = (try? configurationURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard stamp != configurationStamp else { return }
        configurationStamp = stamp
        do {
            let next = try WallSettings.read(from: configurationURL)
            guard next != configuration else { return }
            weatherGeneration += 1
            weatherTask?.cancel(); weatherTask = nil
            configuration = next
            AppText.language = next.language ?? .system
            applyLanguage()
            buildResortViews()
            if clockTimer != nil {
                panels.forEach { $0.start() }
                snowStakes.forEach { $0.start() }
                refreshWeather()
            }
        } catch { source.stringValue = L("雪场设置读取失败 · 继续显示上次有效配置", "Could not load settings · Keeping the last valid configuration") }
    }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard newSize.width > 0, newSize.height > 0 else { return }
        let scale = max(1040 / newSize.width, 1011 / newSize.height)
        setBoundsSize(NSSize(width: newSize.width * scale, height: newSize.height * scale))
    }
    override func layout() {
        super.layout()
        backdrop.frame = bounds
        scenery.frame = bounds
        let rowHeight = bounds.height * 0.2515
        let gap = bounds.height * 0.006
        let padding: CGFloat = 8
        let informationWidth: CGFloat = 190
        let snowWidth: CGFloat = 115
        let columnGap: CGFloat = 14
        let downShift: CGFloat = 38
        let maximumCameraWidth = (rowHeight - padding * 2) * 3
        let wallWidth = min(bounds.width * 0.96, padding * 2 + informationWidth + columnGap * 2 + maximumCameraWidth * 2)
        let cameraWidth = (wallWidth - informationWidth - padding * 2 - columnGap * 2) / 2
        let cameraHeight = rowHeight - padding * 2
        let inset = (bounds.width - wallWidth) / 2
        let snowHeight = snowWidth * 9 / 16 + 35
        let contentBottom = (rowHeight - (64 + 8 + 30 + 8 + snowHeight)) / 2
        let forecastY = contentBottom + snowHeight + 8
        let logoY = forecastY + 30 + 8
        for i in 0..<2 {
            let y = bounds.height * 0.245 + CGFloat(1 - i) * (rowHeight + gap) - downShift
            let row = NSRect(x: inset, y: y, width: wallWidth, height: rowHeight)
            resortRows[i].frame = row
            let informationX = (wallWidth - informationWidth) / 2
            logos[i].frame = NSRect(x: informationX + 15, y: logoY, width: 160, height: 64)
            resortNames[i].frame = NSRect(x: informationX, y: logoY + 16, width: informationWidth, height: 32)
            precipitation[i].frame = NSRect(x: informationX, y: forecastY, width: informationWidth, height: 30)
            let snowX = bounds.midX - snowWidth / 2
            let imageY = row.minY + padding
            panels[i * 2].frame = NSRect(x: inset + padding, y: imageY, width: cameraWidth, height: cameraHeight)
            snowStakes[i].frame = NSRect(x: snowX, y: row.minY + contentBottom, width: snowWidth, height: snowHeight)
            panels[i * 2 + 1].frame = NSRect(x: bounds.width - inset - padding - cameraWidth, y: imageY, width: cameraWidth, height: cameraHeight)
        }
        // Only the preview draws these guides; macOS owns the real clock and authentication.
        clock.frame = NSRect(x: 0, y: bounds.height * 0.803, width: bounds.width, height: 156)
        date.frame = NSRect(x: 0, y: bounds.height * 0.937, width: bounds.width, height: 24)
        localWeather.frame = NSRect(x: 0, y: bounds.height * 0.765 - downShift - 8, width: bounds.width, height: 26)
        previewAvatar.frame = NSRect(x: bounds.midX - 30, y: bounds.height * 0.16, width: 60, height: 60)
        previewName.frame = NSRect(x: bounds.midX - 100, y: bounds.height * 0.13, width: 200, height: 26)
        previewUnlockBackground.frame = NSRect(x: bounds.midX - 135, y: bounds.height * 0.078, width: 270, height: 36)
        previewUnlock.frame = previewUnlockBackground.frame.insetBy(dx: 8, dy: 8)
        previewHint.frame = NSRect(x: bounds.midX - 200, y: bounds.height * 0.048, width: 400, height: 18)
        source.frame = NSRect(x: 24, y: 14, width: bounds.width * 0.28, height: 16)
        settingsButton.frame = NSRect(x: bounds.width - 60, y: 18, width: 32, height: 32)
    }
    func start() {
        guard clockTimer == nil else { return }
        reloadConfiguration()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateClock() }
        clockTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        panels.forEach { $0.start() }
        snowStakes.forEach { $0.start() }
        updateClock()
        refreshWeather()
        refreshWallpaper()
        wallpaperObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshWallpaper() }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refreshWeather() }
        wallpaperTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refreshWallpaper() }
    }
    func stop() {
        panels.forEach { $0.stop() }
        snowStakes.forEach { $0.stop() }
        clockTimer?.invalidate(); clockTimer = nil
        weatherTimer?.invalidate(); weatherTimer = nil
        weatherTask?.cancel(); weatherTask = nil
        wallpaperTimer?.invalidate(); wallpaperTimer = nil
        wallpaperGenerator?.cancelAllCGImageGeneration(); wallpaperGenerator = nil
        wallpaperKey = ""
        if let wallpaperObserver { NSWorkspace.shared.notificationCenter.removeObserver(wallpaperObserver) }
        wallpaperObserver = nil
    }
    private func updateClock() {
        reloadConfiguration()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")
        formatter.dateFormat = "HH:mm"
        formatter.locale = AppText.locale
        clock.stringValue = formatter.string(from: Date())
        formatter.dateFormat = L("M月d日 EEEE", "EEEE, MMM d")
        date.stringValue = formatter.string(from: Date())
    }
    private func refreshWeather() {
        struct Target {
            let panel: Int?
            let forecastRow: Int?
            let latitude: Double
            let longitude: Double
            let elevation: Double
        }
        var targets: [Target] = []
        for (row, resort) in configuration.resorts.enumerated() {
            guard let lat = resort.latitude, let lon = resort.longitude else { continue }
            for (column, camera) in resort.cameras.enumerated() {
                targets.append(Target(panel: row * 2 + column, forecastRow: column == 0 ? row : nil, latitude: lat, longitude: lon, elevation: camera.elevation))
            }
        }
        targets.append(Target(panel: nil, forecastRow: nil, latitude: 49.26636, longitude: -122.95263, elevation: 87))
        var request = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        request.queryItems = [
            URLQueryItem(name: "latitude", value: targets.map { String($0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: targets.map { String($0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "elevation", value: targets.map { String($0.elevation) }.joined(separator: ",")),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,wind_speed_10m,weather_code"),
            URLQueryItem(name: "hourly", value: "rain,showers,snowfall"),
            URLQueryItem(name: "forecast_hours", value: "25"),
            URLQueryItem(name: "timezone", value: "America/Vancouver")
        ]
        let requestID = weatherGeneration
        weatherTask?.cancel()
        weatherTask = URLSession.shared.dataTask(with: request.url!) { [weak self] data, response, error in
            guard (error as NSError?)?.code != NSURLErrorCancelled else { return }
            let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            let records = object as? [[String: Any]] ?? (object as? [String: Any]).map { [$0] }
            DispatchQueue.main.async {
                guard let self, self.clockTimer != nil, self.weatherGeneration == requestID else { return }
                guard let records, records.count == targets.count, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    self.source.stringValue = self.lastWeatherSource + L(" · 连接失败，每10分钟重试", " · Connection failed; retries every 10 minutes")
                    for row in self.configuration.resorts.indices where self.configuration.resorts[row].latitude != nil { self.precipitation[row].stringValue = L("24h预报 · 更新失败", "24h forecast · Update failed") }
                    return
                }
                var times: [String] = []
                for (record, target) in zip(records, targets) {
                    if let row = target.forecastRow {
                        if let forecast = PrecipitationForecast(record: record) {
                            self.precipitation[row].stringValue = String(format: L("24h预报\n雪 %.1f cm · 雨 %.1f mm", "24h forecast\nSnow %.1f cm · Rain %.1f mm"), forecast.snowCM, forecast.rainMM)
                            self.precipitation[row].toolTip = L("Open-Meteo 模型预报 · 海拔 \(target.elevation) m\n\(forecast.start) 至 \(forecast.end) · America/Vancouver", "Open-Meteo model forecast · Elevation \(target.elevation) m\n\(forecast.start) to \(forecast.end) · America/Vancouver")
                        } else { self.precipitation[row].stringValue = L("24h预报 · 暂不可用", "24h forecast · Unavailable") }
                    }
                    guard let current = record["current"] as? [String: Any],
                          let temp = current["temperature_2m"] as? Double,
                          let feels = current["apparent_temperature"] as? Double,
                          let wind = current["wind_speed_10m"] as? Double,
                          let time = current["time"] as? String else { continue }
                    let condition = Self.condition(for: current["weather_code"] as? Int ?? -1)
                    if let panel = target.panel { self.panels[panel].updateWeather(temp: temp, feels: feels, wind: wind) }
                    else { self.localWeather.update(temp: temp, feels: feels, wind: wind, condition: condition) }
                    times.append(time.replacingOccurrences(of: "T", with: " "))
                }
                self.source.stringValue = L("天气 Open-Meteo · ", "Weather Open-Meteo · ") + Array(Set(times)).sorted().joined(separator: " / ")
                self.lastWeatherSource = self.source.stringValue
            }
        }
        weatherTask?.resume()
    }
    private func refreshWallpaper() {
        guard clockTimer != nil else { return }
        // The lock-screen host can attach an external window without an NSScreen.
        // Wallpaper selection follows the built-in screen and does not depend on that window's mapping.
        let screen = window?.screen
        guard let sourceScreen = NSScreen.screens.first(where: {
            let id = ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayIsBuiltin(id) != 0
        }) ?? NSScreen.screens.first ?? screen else {
            wallpaperLog.error("WALLPAPER no source screen; will retry")
            return
        }
        guard let url = desktopWallpaperURL(for: sourceScreen) else { return }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = url.path + String(modified)
        guard key != wallpaperKey else { return }
        wallpaperKey = key
        wallpaperGenerator?.cancelAllCGImageGeneration()
        wallpaperGenerator = nil
        let display = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let sourceDisplay = (sourceScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let apply: (CGImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async {
                guard let self, self.wallpaperKey == key, self.clockTimer != nil else { return }
                self.wallpaperGenerator = nil
                guard let image else {
                    self.wallpaperKey = ""
                    self.wallpaperLog.error("WALLPAPER could not load screen=\(display)")
                    return
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.scenery.contents = image
                CATransaction.commit()
                self.wallpaperLog.notice("WALLPAPER loaded screen=\(display) sourceScreen=\(sourceDisplay) windowScreen=\(screen != nil) view=\(self.bounds.width)x\(self.bounds.height) pixels=\(image.width)x\(image.height) type=\(url.pathExtension, privacy: .public)")
            }
        }
        if ["mov", "mp4"].contains(url.pathExtension.lowercased()) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = NSSize(width: 2560, height: 1600)
            wallpaperGenerator = generator
            generator.generateCGImageAsynchronously(for: .zero) { image, _, _ in apply(image) }
        } else {
            apply(NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        }
    }
    private func desktopWallpaperURL(for screen: NSScreen) -> URL? {
        let workspaceURL = NSWorkspace.shared.desktopImageURL(for: screen)
        guard let account = getpwuid(getuid()) else { return workspaceURL }
        // The system screen saver host's home directory is its container, not the desktop user's home.
        let root = URL(fileURLWithPath: String(cString: account.pointee.pw_dir), isDirectory: true)
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper")
        guard let data = try? Data(contentsOf: root.appendingPathComponent("Store/Index.plist")),
              let store = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return workspaceURL }
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let uuid = CGDisplayCreateUUIDFromDisplayID(displayID).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
        let displays = store["Displays"] as? [String: [String: Any]]
        let entry = uuid.flatMap { displays?[$0] } ?? store["AllSpacesAndDisplays"] as? [String: Any] ?? store["SystemDefault"] as? [String: Any]
        guard let desktop = entry?["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choice = (content["Choices"] as? [[String: Any]])?.first else { return workspaceURL }
        if choice["Provider"] as? String == "com.apple.wallpaper.choice.image",
           let file = (choice["Files"] as? [[String: Any]])?.first?["relative"] as? String,
           let url = URL(string: file), url.isFileURL,
           (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
            return url
        }
        guard choice["Provider"] as? String == "com.apple.wallpaper.choice.aerials",
              let configuration = choice["Configuration"] as? Data,
              let values = (try? PropertyListSerialization.propertyList(from: configuration, format: nil)) as? [String: Any],
              let asset = values["assetID"] as? String, UUID(uuidString: asset) != nil else { return workspaceURL }
        // macOS's generic API returns DefaultDesktop.heic for the current aerial wallpaper.
        let candidates = [root.appendingPathComponent("aerials/videos/\(asset).mov"),
                          URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS/\(asset).mov")]
        return candidates.first { FileManager.default.isReadableFile(atPath: $0.path) } ?? workspaceURL
    }
    private static func condition(for code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "晴间多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55: return "细雨"
        case 56, 57, 66, 67: return "冻雨"
        case 61, 63, 65: return "雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "阵雨"
        case 85, 86: return "阵雪"
        case 95, 96, 97, 99: return "雷雨"
        default: return "天气状况未知"
        }
    }
}

@objc(MountainCamsView)
final class MountainCamsView: ScreenSaverView {
    private var wall: CamWall!
    private let lifecycle = Logger(subsystem: "io.skinerd.lockscreen", category: "lifecycle")
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wall = CamWall(frame: bounds, showsClock: isPreview)
        wall.autoresizingMask = [.width, .height]
        addSubview(wall)
        animationTimeInterval = 1
        lifecycle.notice("BITMAP 1.0 (36) INIT preview=\(isPreview) width=\(frame.width) height=\(frame.height)")
        for name in ["com.apple.screensaver.willstop", "com.apple.screensaver.didstop", "com.apple.screenIsUnlocked"] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(sessionEnded(_:)), name: Notification.Name(name), object: nil)
        }
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    override func startAnimation() {
        super.startAnimation()
        lifecycle.notice("START preview=\(self.isPreview) width=\(self.bounds.width) height=\(self.bounds.height)")
        startIfAttached()
    }
    override func stopAnimation() {
        wall?.stop()
        lifecycle.info("STOP")
        super.stopAnimation()
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            wall?.stop()
            lifecycle.notice("DETACHED: playback stopped")
        } else {
            startIfAttached()
            lifecycle.notice("ATTACHED: native playback started")
        }
    }
    private func startIfAttached() {
        if window != nil && bounds.width > 0 && bounds.height > 0 { wall?.start() }
    }
    override func animateOneFrame() { startIfAttached() }
    @objc private func sessionEnded(_ notification: Notification) {
        guard !isPreview else { return }
        lifecycle.info("SESSION END \(notification.name.rawValue, privacy: .public)")
        stopAnimation()
    }
    deinit { DistributedNotificationCenter.default().removeObserver(self) }
}
