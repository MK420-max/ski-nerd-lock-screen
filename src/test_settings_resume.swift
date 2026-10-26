import AppKit

private final class CaptureRequests: URLProtocol {
    private static let lock = NSLock()
    private static var sources: [String] = []
    static func seen() -> [String] { lock.lock(); defer { lock.unlock() }; return sources }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let url = request.url, url.path == "/stream",
           let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "source" })?.value {
            Self.lock.lock(); Self.sources.append(source); Self.lock.unlock()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main private struct ResumeChecks {
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        URLProtocol.registerClass(CaptureRequests.self)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        func profile(_ id: String) -> WallSettings {
            var settings = WallSettings(resorts: [.empty, .empty])
            for row in 0..<2 {
                settings.resorts[row].name = "Lifecycle fixture \(row)"
                for column in 0..<2 {
                    settings.resorts[row].cameras[column].url = "https://www.youtube.com/watch?v=" + id
                }
            }
            return settings
        }
        try profile("aaaaaaaaaaa").save(to: file)
        let wall = CamWall(frame: NSRect(x: 0, y: 0, width: 1244, height: 810), showsClock: false, settingsURL: file)
        wall.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        wall.stop()
        try profile("bbbbbbbbbbb").save(to: file)
        // No notification: a suspended screen-saver host may miss the settings event.
        wall.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        wall.stop()
        let count = CaptureRequests.seen().filter { $0.contains("bbbbbbbbbbb") }.count
        print("New camera sources requested after stop/config-change/resume:", count, "/ 4")
        guard count == 4 else { exit(1) }
        print("PASS: all four replacement sources restart after an inactive configuration change")
    }
}
