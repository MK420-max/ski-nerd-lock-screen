import Foundation

@main
struct SettingsChecks {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("resorts.json")
        let initial = try WallSettings.read(from: url)
        precondition(initial == .defaults)
        precondition(initial.language == nil)
        AppText.language = .english
        precondition(L("中文", "English") == "English")
        AppText.language = .chinese
        precondition(L("中文", "English") == "中文")
        var custom = WallSettings.defaults
        custom.language = .english
        custom.resorts[0] = .empty
        custom.resorts[0].name = "Revelstoke 测试雪场"
        custom.resorts[0].latitude = 50.957
        custom.resorts[0].longitude = -118.163
        custom.resorts[0].cameras[0] = CameraSettings(name: "Mountain", elevation: 2200, url: "https://example.com/camera.jpg", kind: .image)
        try custom.save(to: url)
        let restored = try WallSettings.read(from: url)
        precondition(restored == custom)
        let original = try Data(contentsOf: url)
        func rejects(_ bad: WallSettings) {
            do { try bad.save(to: url); preconditionFailure("Invalid settings accepted") } catch {}
            precondition((try? Data(contentsOf: url)) == original, "Invalid save changed the existing file")
        }
        var bad = custom; bad.resorts[0].latitude = 95; rejects(bad)
        bad = custom; bad.resorts[0].longitude = nil; rejects(bad)
        bad = custom; bad.resorts[0].cameras[0].elevation = .infinity; rejects(bad)
        bad = custom; bad.resorts[0].cameras[0].url = "http://127.0.0.1/private"; rejects(bad)
        bad = custom; bad.resorts[0].snowURL = "https://user:password@example.com/image.jpg"; rejects(bad)
        bad = custom; bad.resorts[0].cameras.removeLast(); rejects(bad)
        let provider = CameraSettings(name: "YouTube", elevation: 1000, url: "https://www.youtube.com/watch?v=abcdefghijk&feature=share")
        let query = URLComponents(string: provider.playbackURL)!.queryItems!
        precondition(query.first(where: { $0.name == "source" })?.value == provider.url)
        try Data("bad JSON".utf8).write(to: url)
        do { _ = try WallSettings.read(from: url); preconditionFailure("Corrupt file accepted") } catch {}
        print("PASS: custom resort, image source, atomic invalid-save retention, coordinates, altitude, HTTPS, provider query encoding, corrupt JSON")
    }
}
