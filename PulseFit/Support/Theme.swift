import Foundation
import SwiftUI
import UIKit

// MARK: - Units

enum Units: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var label: String { self == .metric ? "Kilometers" : "Miles" }
    var abbreviation: String { self == .metric ? "km" : "mi" }

    func km(fromDisplay value: Double) -> Double {
        self == .metric ? value : value * 1.609344
    }

    func display(km: Double) -> Double {
        self == .metric ? km : km / 1.609344
    }
}

// MARK: - Settings keys

enum SettingsKeys {
    /// Defaults-backed keys; the enum makes leading-dot shorthand resolve.
    enum Key: String {
        case soundEnabled = "settings.soundEnabled"
        case voiceEnabled = "settings.voiceEnabled"
        case hapticsEnabled = "settings.hapticsEnabled"
        case backgroundTimer = "settings.backgroundTimer"
        case phaseAlerts = "settings.phaseAlerts"
    }

    static let units = "settings.units"
    static let soundEnabled = "settings.soundEnabled"
    static let voiceEnabled = "settings.voiceEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let backgroundTimer = "settings.backgroundTimer"
    static let phaseAlerts = "settings.phaseAlerts"
    static let weeklyGoal = "settings.weeklyGoal"

    /// `@AppStorage`-style reads where "never set" must default to true.
    static func defaultedBool(_ key: Key) -> Bool {
        UserDefaults.standard.object(forKey: key.rawValue) == nil ? true : UserDefaults.standard.bool(forKey: key.rawValue)
    }

    static var currentUnits: Units {
        Units(rawValue: UserDefaults.standard.string(forKey: units) ?? "") ?? .metric
    }

    static var weeklyGoalValue: Int {
        let v = UserDefaults.standard.integer(forKey: weeklyGoal)
        return v > 0 ? v : 4
    }
}

// MARK: - Theme

enum Theme {
    static let accent = Color(hex: 0x32D74B)

    static func color(for kind: PhaseKind) -> Color {
        Color(hex: kind.colorHex)
    }

    /// Rotating palette for per-type breakdowns.
    static let palette: [Color] = [
        Color(hex: 0x32D74B), Color(hex: 0x0A84FF), Color(hex: 0xFF9F0A),
        Color(hex: 0xBF5AF2), Color(hex: 0xFF375F), Color(hex: 0x64D2FF),
        Color(hex: 0xFFD60A), Color(hex: 0xFF453A)
    ]

    static func paletteColor(_ index: Int) -> Color {
        palette[index % palette.count]
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Card styling

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Formatting

enum Format {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f
    }()

    /// 1:05 or 1:02:03 (floored).
    static func mmss(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Countdown display — rounds up so "0" only shows when truly done.
    static func countdown(_ seconds: Double) -> String {
        mmss(max(1, seconds.rounded(.up)))
    }

    /// "45 min", "1 h 30 m", "2 h".
    static func duration(minutes: Double) -> String {
        let m = Int(minutes.rounded())
        guard m >= 60 else { return "\(m) min" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) h" : "\(h) h \(rem) m"
    }

    static func distance(km: Double, units: Units) -> String {
        String(format: "%.1f %@", units.display(km: km), units.abbreviation)
    }

    /// "5:24 /km" or "8:42 /mi".
    static func pace(secondsPerKm: Double, units: Units) -> String {
        let perUnit = units == .metric ? secondsPerKm : secondsPerKm / 1.609344
        let total = max(0, Int(perUnit.rounded()))
        return String(format: "%d:%02d /%@", total / 60, total % 60, units.abbreviation)
    }

    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        if day == today { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return "Yesterday"
        }
        return dayFormatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func timeOfDay(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func fullDateTime(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    /// RPE label for the 1–10 effort scale.
    static func effortLabel(_ effort: Int) -> String {
        switch effort {
        case ..<3: return "Very easy"
        case 3..<5: return "Easy"
        case 5..<7: return "Moderate"
        case 7..<9: return "Hard"
        default: return "Max effort"
        }
    }
}
