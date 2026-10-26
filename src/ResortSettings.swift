import Foundation
import Darwin

struct CameraSettings: Codable, Equatable {
    enum Kind: String, Codable { case stream, image }
    var name: String
    var elevation: Double
    var url: String
    var kind: Kind = .stream

    var playbackURL: String {
        guard kind == .stream, let source = URL(string: url),
              ["youtube.com", "www.youtube.com", "youtu.be", "camstreamer.com", "www.camstreamer.com"].contains(source.host?.lowercased() ?? "") else { return url }
        var request = URLComponents(string: "http://127.0.0.1:48764/stream")!
        request.queryItems = [URLQueryItem(name: "source", value: url)]
        return request.url!.absoluteString
    }
    var caption: String {
        let number = NumberFormatter()
        number.locale = Locale(identifier: "en_CA")
        number.numberStyle = .decimal
        number.maximumFractionDigits = 0
        return name + " · " + (number.string(from: NSNumber(value: elevation)) ?? "—") + " m"
    }
}

struct ResortSettings: Codable, Equatable {
    var name: String
    var latitude: Double?
    var longitude: Double?
    var cameras: [CameraSettings]
    var snowURL: String
    var logoAsset: String?
    var logoPath: String?

    static let whistler = ResortSettings(name: "Whistler", latitude: 50.0669, longitude: -122.947, cameras: [
        CameraSettings(name: "Roundhouse", elevation: 1850, url: "https://live9.brownrice.com:444/whistlerroundhouse/whistlerroundhouse.stream/main_playlist.m3u8"),
        CameraSettings(name: "Village", elevation: 675, url: "https://live5.brownrice.com:444/whistlervillagefitz/whistlervillagefitz.stream/main_playlist.m3u8")
    ], snowURL: "https://player.brownrice.com/snapshot/whistlersnowstack", logoAsset: "WhistlerLogo")
    static let cypress = ResortSettings(name: "Cypress", latitude: 49.396, longitude: -123.204, cameras: [
        CameraSettings(name: "Lions Chair", elevation: 1275, url: "https://camstreamer.com/embed/coUmF7P2InhuwcFcDus84j6LnbpQobaZBfJI5e37"),
        CameraSettings(name: "Plaza", elevation: 910, url: "https://camstreamer.com/embed/eRzI4m4I7DVVaPqHWCVvlHERvHviYEmqOI3yXz3Q")
    ], snowURL: "https://snowstakecam.cypressmountain.com/axis-cgi/jpg/image.cgi?resolution=1024x768", logoAsset: "CypressLogo")
    static let empty = ResortSettings(name: L("自定义雪场", "Custom resort"), cameras: [
        CameraSettings(name: L("画面 1", "Camera 1"), elevation: 0, url: ""), CameraSettings(name: L("画面 2", "Camera 2"), elevation: 0, url: "")
    ], snowURL: "")
}

struct WallSettings: Codable, Equatable {
    var version = 1
    var resorts: [ResortSettings]
    var language: AppLanguage? = nil
    static let defaults = WallSettings(resorts: [.whistler, .cypress])

    static var directory: URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/MountainCams")
    }
    static var fileURL: URL { directory.appendingPathComponent("resorts.json") }

    func validate() throws {
        guard version == 1, resorts.count == 2 else { throw SettingsError(L("当前布局需要上、下两排雪场。", "This layout needs a top and a bottom resort.")) }
        for resort in resorts {
            guard !resort.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, resort.name.count <= 80,
                  resort.cameras.count == 2 else { throw SettingsError(L("请填写雪场名称，并保留每排两个主画面。", "Enter a resort name and keep two cameras in each row.")) }
            if resort.latitude != nil || resort.longitude != nil {
                guard let lat = resort.latitude, let lon = resort.longitude, lat.isFinite, lon.isFinite,
                      (-90...90).contains(lat), (-180...180).contains(lon) else { throw SettingsError(L("天气位置需同时填写有效纬度和经度。", "Enter both valid latitude and longitude, or leave both blank.")) }
            }
            for camera in resort.cameras {
                guard !camera.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      camera.elevation.isFinite, (-500...9000).contains(camera.elevation) else {
                    throw SettingsError(L("请填写机位名称，海拔范围为 -500 至 9,000 米。", "Enter a camera name and an elevation from -500 to 9,000 metres."))
                }
                try Self.validateURL(camera.url)
            }
            try Self.validateURL(resort.snowURL)
            guard resort.logoAsset == nil || ["WhistlerLogo", "CypressLogo"].contains(resort.logoAsset!) else {
                throw SettingsError(L("内置 Logo 不存在，请重新选择。", "Choose an available built-in logo."))
            }
            if let path = resort.logoPath, !path.hasPrefix("/") { throw SettingsError(L("Logo 文件位置无效。", "The logo file location is invalid.")) }
        }
    }
    private static func validateURL(_ text: String) throws {
        if text.isEmpty { return }
        guard text.count <= 8192, let url = URL(string: text), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, !text.contains(where: { $0.isWhitespace }) else {
            throw SettingsError(L("来源请填写完整的公开 HTTPS 地址；没有来源可以留空。", "Enter a complete public HTTPS URL, or leave it blank."))
        }
    }
    static func read(from url: URL = fileURL) throws -> WallSettings {
        if !FileManager.default.fileExists(atPath: url.path) { return .defaults }
        let settings = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try settings.validate()
        return settings
    }
    func save(to url: URL = fileURL) throws {
        try validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

struct SettingsError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
