import AppKit
import OSLog

final class SnowStakeView: NSView {
    private let imageView = NSImageView()
    private let unavailable = NSImageView()
    private let caption: NSTextField
    private let freshness = NSTextField(labelWithString: L("连接中", "Connecting"))
    private let imageBox = NSView()
    private let url: URL?
    private let name: String
    private var timer: Timer?
    private var request: URLSessionDataTask?
    private var generation = 0
    private var fetchedAt: Date?
    private let logger = Logger(subsystem: "io.skinerd.lockscreen", category: "snow-stake")

    init(name: String, url: String) {
        self.name = name
        self.url = url.isEmpty ? nil : URL(string: url)
        caption = NSTextField(labelWithString: L("雪尺", "Snow stake"))
        super.init(frame: .zero)
        imageBox.wantsLayer = true
        imageBox.layer?.cornerRadius = 13
        imageBox.layer?.masksToBounds = true
        imageBox.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.4).cgColor
        imageBox.layer?.borderWidth = 0.7
        imageBox.layer?.borderColor = NSColor(white: 1, alpha: 0.22).cgColor
        addSubview(imageBox)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageBox.addSubview(imageView)
        unavailable.image = NSImage(systemSymbolName: "video.slash", accessibilityDescription: L("雪尺摄像头不可用", "Snow-stake camera unavailable"))
        unavailable.contentTintColor = NSColor(white: 1, alpha: 0.8)
        unavailable.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        imageBox.addSubview(unavailable)
        for label in [caption, freshness] {
            label.textColor = NSColor(white: 1, alpha: 0.9)
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            addSubview(label)
        }
        caption.font = .systemFont(ofSize: 12, weight: .medium)
        caption.alignment = .center
        freshness.font = .systemFont(ofSize: 10)
        freshness.alignment = .center
        if url.isEmpty { freshness.stringValue = L("未设置雪尺", "Not configured") }
        freshness.textColor = NSColor(white: 1, alpha: 0.65)
        setAccessibilityLabel(name + L(" 雪尺快照", " snow-stake snapshot"))
        toolTip = L("雪尺摄像头快照，每60秒重新获取；获取时间不代表摄像头拍摄时间。", "Snow-stake snapshot, fetched every 60 seconds. Fetch time is not camera capture time.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        imageBox.frame = NSRect(x: 0, y: 35, width: bounds.width, height: bounds.width * 9 / 16)
        imageView.frame = imageBox.bounds
        unavailable.frame = NSRect(x: (imageBox.bounds.width - 36) / 2, y: (imageBox.bounds.height - 32) / 2, width: 36, height: 32)
        let fullCaption = name + L(" · 雪尺", " · Snow stake")
        caption.stringValue = L("雪尺", "Snow stake")
        caption.toolTip = fullCaption
        caption.frame = NSRect(x: 0, y: 17, width: bounds.width, height: 17)
        freshness.frame = NSRect(x: 0, y: 2, width: bounds.width, height: 14)
    }
    func start() {
        guard timer == nil else { return }
        let next = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        timer = next
        RunLoop.main.add(next, forMode: .common)
        refresh()
    }
    func stop() {
        generation += 1
        timer?.invalidate(); timer = nil
        request?.cancel(); request = nil
    }
    private func refresh() {
        guard timer != nil, request == nil, let url else { return }
        let requestID = generation
        request = URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)) { [weak self] data, response, error in
            let http = response as? HTTPURLResponse
            let valid = error == nil && http?.statusCode == 200 && http?.mimeType?.hasPrefix("image/") == true
            let image = valid ? data.flatMap { NSImage(data: $0) } : nil
            DispatchQueue.main.async {
                guard let self, self.timer != nil, self.generation == requestID else { return }
                self.request = nil
                if let image, image.size.width > 0, image.size.height > 0 {
                    self.imageView.image = image
                    self.unavailable.isHidden = true
                    self.fetchedAt = Date()
                }
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone(identifier: "America/Vancouver")
                formatter.dateFormat = "M/d HH:mm"
                if let fetchedAt = self.fetchedAt {
                    self.freshness.stringValue = L("获取 ", "Fetched ") + formatter.string(from: fetchedAt) + (image == nil ? L(" · 更新失败", " · Update failed") : "")
                } else {
                    self.freshness.stringValue = L("离线 · 自动重试", "Offline · Retrying")
                }
                self.logger.notice("SNOW \(self.name, privacy: .public) fetched=\(image != nil) status=\(http?.statusCode ?? 0) error=\((error as NSError?)?.code ?? 0)")
            }
        }
        request?.resume()
    }
}
