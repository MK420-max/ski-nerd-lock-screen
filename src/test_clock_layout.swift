import AppKit

@main private struct ClockLayoutChecks {
    static func check(_ valid: Bool, _ message: String) {
        if !valid { print("FAIL:", message); exit(1) }
    }
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for size in [NSSize(width: 1512, height: 982), NSSize(width: 2560, height: 1440),
                     NSSize(width: 1244, height: 810), NSSize(width: 3840, height: 1080)] {
            let wall = CamWall(frame: NSRect(origin: .zero, size: size), showsClock: false, settingsURL: missing)
            wall.layoutSubtreeIfNeeded()
            let cameras = wall.subviews.compactMap { $0 as? CameraPanel }
            let cards = wall.subviews.compactMap { $0 as? GlassCard }.filter { !$0.isHidden }
            let weather = wall.subviews.compactMap { $0 as? WeatherCard }.first!
            check(cameras.count == 4 && cards.count == 2, "four cameras and two information cards")
            let clockRegion = NSRect(x: 0, y: wall.bounds.height * 0.76, width: wall.bounds.width, height: wall.bounds.height * 0.24)
            let avatarTop = wall.bounds.height * 0.16 + 60
            let authenticationRegions = [
                NSRect(x: wall.bounds.midX - 100, y: 0, width: 200, height: avatarTop),
                NSRect(x: wall.bounds.midX - 135, y: 0, width: 270, height: wall.bounds.height * 0.078 + 36)
            ]
            for camera in cameras {
                check(!camera.frame.intersects(clockRegion), "camera entered the clock region")
                check(!authenticationRegions.contains(where: { camera.frame.intersects($0) }), "camera entered the password region")
                check(wall.bounds.contains(camera.frame), "camera is outside the screen")
                check(camera.frame.width / camera.frame.height <= 3.0001, "camera is too wide")
                check(camera.frame.height > wall.bounds.height * 0.23, "camera did not use the available height")
            }
            check(cameras[0].frame.minX < cards[0].frame.minX + cards[0].frame.width * 0.04, "left camera must use its row's left edge")
            check(cameras[1].frame.maxX > cards[0].frame.maxX - cards[0].frame.width * 0.04, "right camera must use its row's right edge")
            check(!cameras[0].frame.intersects(cameras[2].frame), "left cameras overlap vertically")
            check(!cameras[1].frame.intersects(cameras[3].frame), "right cameras overlap vertically")
            for (row, card) in cards.enumerated() {
                check(abs(card.frame.midX - wall.bounds.midX) < 0.01, "resort row must remain centered")
                check(card.frame.width <= wall.bounds.width * 0.96 + 0.01, "resort row exceeded screen margins")
                check(card.frame.contains(cameras[row * 2].frame) && card.frame.contains(cameras[row * 2 + 1].frame), "video protrudes outside its shared resort row")
                check(abs(cameras[row * 2].frame.height - cameras[row * 2 + 1].frame.height) < 0.01, "paired videos must align")
                check(card.frame.maxY < wall.bounds.height * 0.76, "information card entered the clock region")
                check(card.frame.minY >= wall.bounds.height * 0.20, "glass background extends too low")
            }
            for stake in wall.subviews.compactMap({ $0 as? SnowStakeView }) {
                check(stake.frame.minY >= avatarTop + 8, "snow-stake text entered the password region")
            }
            check(abs(cards[1].frame.minY - (wall.bounds.height * 0.245 - 38)) < 0.01, "rows did not move down by one weather-text height")
            check(weather.frame.maxY < wall.bounds.height * 0.78, "weather moved into the clock region")
            check(weather.frame.minY - cards[0].frame.maxY >= 3, "weather overlaps the upper row")
            if size.width == 1512 { check(cameras[0].frame.width > 450, "built-in video did not grow") }
            if size.width == 2560 { check(cameras[0].frame.width > 550, "external video did not grow") }
            print("PASS:", Int(size.width), "x", Int(size.height), "camera", cameras[0].frame.size)
        }
        print("PASS: connected rows, contained videos, edge use, clock/password space, weather position, and screen bounds")
    }
}
