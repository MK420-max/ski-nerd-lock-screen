import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case system, chinese = "zh-Hans", english = "en"
    var isChinese: Bool {
        switch self {
        case .chinese: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("zh") == true
        }
    }
}

enum AppText {
    static var language: AppLanguage = .system
    static var locale: Locale { Locale(identifier: language.isChinese ? "zh_CN" : "en_CA") }
    static func condition(_ value: String) -> String {
        if language.isChinese { return value }
        return ["晴": "Clear", "晴间多云": "Partly cloudy", "阴": "Overcast", "雾": "Fog",
                "细雨": "Drizzle", "冻雨": "Freezing rain", "雨": "Rain", "雪": "Snow",
                "阵雨": "Showers", "阵雪": "Snow showers", "雷雨": "Thunderstorm"][value] ?? "Unknown"
    }
}

func L(_ chinese: String, _ english: String) -> String { AppText.language.isChinese ? chinese : english }
