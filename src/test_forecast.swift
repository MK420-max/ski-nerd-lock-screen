import Foundation

@main
struct ForecastChecks {
    static func main() throws {
        let times = (0..<25).map { $0 == 24 ? "2026-10-26T00:00" : String(format: "2026-10-25T%02d:00", $0) }
        let hourly: [String: Any] = ["time": times,
            "rain": [500.0] + Array(repeating: 1.0, count: 24),
            "showers": [500.0] + Array(repeating: 0.5, count: 24),
            "snowfall": [500.0] + Array(repeating: 0.25, count: 24)]
        let units = ["rain": "mm", "showers": "mm", "snowfall": "cm"]
        let record: [String: Any] = ["hourly": hourly, "hourly_units": units]
        let forecast = PrecipitationForecast(record: record)!
        precondition(forecast.rainMM == 36 && forecast.snowCM == 6, "Must exclude the elapsed hour and include showers")
        precondition(forecast.start == times[0] && forecast.end == times[24])
        var invalid = record
        invalid["hourly_units"] = ["rain": "inch", "showers": "mm", "snowfall": "cm"]
        precondition(PrecipitationForecast(record: invalid) == nil, "Do not label inches as millimeters")
        var incomplete = hourly
        incomplete["snowfall"] = [0.0]
        invalid = record; invalid["hourly"] = incomplete
        precondition(PrecipitationForecast(record: invalid) == nil, "Missing hours must not become zero snowfall")
        var missing = hourly
        missing["rain"] = [NSNull()] + Array(repeating: 1.0, count: 24)
        invalid = record; invalid["hourly"] = missing
        precondition(PrecipitationForecast(record: invalid) == nil, "Null precipitation is unavailable data")
        print("Forecast interval, rain/showers, units and missing-data checks passed")

        guard CommandLine.arguments.count > 1 else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let live = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        for (index, name) in ["Whistler", "Cypress"].enumerated() {
            let value = PrecipitationForecast(record: live[index])!
            print(String(format: "%@: snow=%.1f cm rain=%.1f mm", name, value.snowCM, value.rainMM), value.start, value.end)
        }
    }
}
