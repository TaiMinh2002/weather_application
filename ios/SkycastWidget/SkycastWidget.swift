import SwiftUI
import WidgetKit

// Current-weather widget in two sizes: small (2×2) and medium (4×2, plus the
// best activity time and the next six hours). The Flutter app writes
// already-formatted text (widgetData() in lib/features/home_widget/) into the
// shared App Group; this only draws it.

private let appGroup = "group.com.minhpt.skycast"

/// Top/bottom colours per sky key; mirrors `Sky` in lib/core/theme/app_theme.dart.
private let skies: [String: [UInt32]] = [
    "clear_day": [0x2272D6, 0x0F4DA8],
    "clear_night": [0x1E2A5E, 0x0B1026],
    "cloudy_day": [0x5A7390, 0x3A4F66],
    "cloudy_night": [0x2E3A52, 0x151B28],
    "fog_day": [0x6B7784, 0x4A5561],
    "fog_night": [0x343C4C, 0x181C25],
    "rain_day": [0x3A6A94, 0x1D3F63],
    "rain_night": [0x1B3350, 0x0A1424],
    "snow_day": [0x4A78A6, 0x2A5584],
    "snow_night": [0x2A3766, 0x10162E],
    "storm_day": [0x4A4468, 0x24223A],
    "storm_night": [0x231B3D, 0x09081A],
]

struct Hour {
    let time: String
    let icon: String
    let temp: String
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let city: String
    let temp: String
    let condition: String
    let hilo: String
    let sky: String
    /// Best time for the user's first activity; empty when none is good.
    let activity: String
    let hours: [Hour]
}

/// Hourly columns on the medium widget; matches widgetHours in Dart.
private let hourCount = 6

struct Provider: TimelineProvider {
    private func read() -> WeatherEntry {
        let d = UserDefaults(suiteName: appGroup)
        return WeatherEntry(
            date: Date(),
            city: d?.string(forKey: "city") ?? "Skycast",
            temp: d?.string(forKey: "temp") ?? "--°",
            condition: d?.string(forKey: "condition") ?? "",
            hilo: d?.string(forKey: "hilo") ?? "",
            sky: d?.string(forKey: "sky") ?? "clear_day",
            activity: d?.string(forKey: "activity") ?? "",
            hours: (0..<hourCount).compactMap { i in
                guard let time = d?.string(forKey: "h\(i)_time") else { return nil }
                return Hour(
                    time: time,
                    icon: d?.string(forKey: "h\(i)_icon") ?? "",
                    temp: d?.string(forKey: "h\(i)_temp") ?? ""
                )
            }
        )
    }

    func placeholder(in context: Context) -> WeatherEntry { read() }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(read())
    }

    // The app reloads the timeline itself (HomeWidget.updateWidget), so no
    // refresh schedule is needed here.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .never))
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// SF Symbol for a `<WeatherCondition>_<day|night>` key from Dart.
private func symbol(_ key: String) -> String {
    let night = key.hasSuffix("_night")
    switch key.split(separator: "_").first.map(String.init) ?? "" {
    case "clear", "mainlyClear": return night ? "moon.stars.fill" : "sun.max.fill"
    case "partlyCloudy": return night ? "cloud.moon.fill" : "cloud.sun.fill"
    case "fog": return "cloud.fog.fill"
    case "drizzle": return "cloud.drizzle.fill"
    case "rain": return "cloud.rain.fill"
    case "showers": return "cloud.heavyrain.fill"
    case "snow": return "cloud.snow.fill"
    case "thunderstorm": return "cloud.bolt.rain.fill"
    default: return "cloud.fill"
    }
}

struct SkycastWidgetView: View {
    let entry: WeatherEntry
    @Environment(\.widgetFamily) private var family

    private var gradient: LinearGradient {
        let stops = skies[entry.sky] ?? skies["clear_day"]!
        return LinearGradient(
            colors: stops.map { Color(hex: $0) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Group {
            if family == .systemMedium { medium } else { small }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(gradient, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.city).font(.subheadline.bold()).lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.temp).font(.system(size: 44, weight: .light))
            Text(entry.condition).font(.caption).lineLimit(1)
            Text(entry.hilo).font(.caption2).opacity(0.85)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.city).font(.subheadline.bold()).lineLimit(1)
                    Text([entry.condition, entry.hilo].filter { !$0.isEmpty }
                        .joined(separator: " · "))
                        .font(.caption).opacity(0.9).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(entry.temp).font(.system(size: 36, weight: .light))
            }
            if !entry.activity.isEmpty {
                Text(entry.activity).font(.caption).opacity(0.9).lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(Array(entry.hours.enumerated()), id: \.offset) { _, hour in
                    VStack(spacing: 3) {
                        Text(hour.time).font(.caption2).opacity(0.8)
                        Image(systemName: symbol(hour.icon))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 16))
                            .frame(height: 18)
                        Text(hour.temp).font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

@main
struct SkycastWidget: Widget {
    // Must match iOSName in HomeScreenWidget.update().
    let kind = "SkycastWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SkycastWidgetView(entry: entry)
        }
        .configurationDisplayName("Skycast")
        .description("Current weather where you are")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
