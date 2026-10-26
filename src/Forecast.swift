import Foundation

struct PrecipitationForecast {
    let snowCM: Double
    let rainMM: Double
    let start: String
    let end: String

    init?(record: [String: Any]) {
        guard let hourly = record["hourly"] as? [String: Any],
              let units = record["hourly_units"] as? [String: String],
              units["rain"] == "mm", units["showers"] == "mm", units["snowfall"] == "cm",
              let times = hourly["time"] as? [String], times.count >= 25,
              let rain = hourly["rain"] as? [Double],
              let showers = hourly["showers"] as? [Double],
              let snow = hourly["snowfall"] as? [Double],
              [rain, showers, snow].allSatisfy({ $0.count >= 25 && $0.prefix(25).allSatisfy { $0.isFinite && $0 >= 0 } }) else { return nil }
        // Hourly amounts describe the preceding hour: exclude the already elapsed first interval.
        rainMM = rain[1...24].reduce(0, +) + showers[1...24].reduce(0, +)
        snowCM = snow[1...24].reduce(0, +)
        start = times[0]
        end = times[24]
    }
}
