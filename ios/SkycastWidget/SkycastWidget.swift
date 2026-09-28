import SwiftUI
import WidgetKit

// 2×2 current-weather widget. The Flutter app writes already-formatted text
// (lib/features/home_widget/) into the shared App Group; this only draws it.

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

struct WeatherEntry: TimelineEntry {
    let date: Date
    let city: String
    let temp: String
    let condition: String
    let hilo: String
    let sky: String
}

struct Provider: TimelineProvider {
    private func read() -> WeatherEntry {
        let d = UserDefaults(suiteName: appGroup)
        return WeatherEntry(
            date: Date(),
            city: d?.string(forKey: "city") ?? "Skycast",
            temp: d?.string(forKey: "temp") ?? "--°",
            condition: d?.string(forKey: "condition") ?? "",
            hilo: d?.string(forKey: "hilo") ?? "",
            sky: d?.string(forKey: "sky") ?? "clear_day"
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

struct SkycastWidgetView: View {
    let entry: WeatherEntry

    private var gradient: LinearGradient {
        let stops = skies[entry.sky] ?? skies["clear_day"]!
        return LinearGradient(
            colors: stops.map { Color(hex: $0) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.city).font(.subheadline.bold()).lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.temp).font(.system(size: 44, weight: .light))
            Text(entry.condition).font(.caption).lineLimit(1)
            Text(entry.hilo).font(.caption2).opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(gradient, for: .widget)
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
        .supportedFamilies([.systemSmall])
    }
}
