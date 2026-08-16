import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 4

    @State private var selectedWeek: Stats.WeekTotal?
    @State private var selectedDay: (day: Date, minutes: Double)?

    private let units = SettingsKeys.currentUnits

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.workouts.isEmpty {
                        emptyCard
                    } else {
                        goalCard
                        summaryCards
                        WeeklyBarChartCard(weeks: Stats.weekTotals(store.workouts, weeks: 8), selection: $selectedWeek)
                        HeatmapCard(days: Stats.dailyMinutes(store.workouts, days: 16 * 7), selection: $selectedDay)
                        TypeBreakdownCard(breakdown: Stats.typeBreakdown(store.workouts))
                        recordsCard
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Stats")
        }
    }

    // MARK: - Cards

    private var goalCard: some View {
        let sessions = Stats.sessionsThisWeek(store.workouts)
        let goal = max(1, weeklyGoal)
        let progress = min(1, Double(sessions) / Double(goal))
        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(sessions)")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Text("of \(goal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Goal")
                    .font(.headline)
                if sessions >= goal {
                    Text("Goal crushed — keep it rolling! 🎉")
                } else {
                    Text("\(goal - sessions) more session\((goal - sessions) == 1 ? "" : "s") to hit your goal.")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var summaryCards: some View {
        let workouts = store.workouts
        let streak = Stats.currentStreak(workouts)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            miniStat("\(workouts.count)", "Workouts", "figure.run")
            miniStat(Format.duration(minutes: Stats.totalMinutes(workouts)), "Total time", "clock")
            miniStat("\(streak) day\(streak == 1 ? "" : "s")", streak >= 3 ? "Streak 🔥" : "Streak", "flame.fill")
            miniStat(Format.duration(minutes: Stats.minutesThisWeek(workouts)), "This week", "calendar")
        }
    }

    private var recordsCard: some View {
        let records = Stats.records(store.workouts)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Records & Streaks")
                .font(.headline)
            recordRow("trophy.fill", "Longest session", records.longestSession.map { "\(Format.duration(minutes: $0.durationMinutes)) · \($0.type)" } ?? "—")
            recordRow("figure.run", "Farthest distance", records.farthestSession.flatMap { $0.distanceKm }.map { Format.distance(km: $0, units: units) } ?? "—")
            recordRow("calendar", "Biggest week", Format.duration(minutes: records.biggestWeekMinutes))
            recordRow("flame.fill", "Longest streak", "\(records.longestStreak) day\(records.longestStreak == 1 ? "" : "s")")
        }
        .card()
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Nothing to see yet")
                .font(.headline)
            Text("Log a few workouts and your stats, streaks and charts will light up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Load Sample Data") {
                store.loadSampleData()
            }
            .buttonStyle(.borderedProminent)
        }
        .card()
    }

    // MARK: - Helpers

    private func miniStat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: symbol)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .card()
    }

    private func recordRow(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundColor(Theme.accent)
                .frame(width: 26)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.subheadline)
    }
}

// MARK: - Weekly bar chart

struct WeeklyBarChartCard: View {
    let weeks: [Stats.WeekTotal]
    @Binding var selection: Stats.WeekTotal?

    private var maxMinutes: Double {
        max(weeks.map(\.minutes).max() ?? 1, 1)
    }

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 8 Weeks")
                .font(.headline)
            if let selection {
                Text("Week of \(Self.labelFormatter.string(from: selection.start)) · \(Format.duration(minutes: selection.minutes)) · \(selection.sessions) session\(selection.sessions == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(weeks, id: \.start) { week in
                    let isSelected = selection?.start == week.start
                    Button {
                        selection = isSelected ? nil : week
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(week.minutes > 0
                                    ? (isSelected ? Theme.accent : Theme.accent.opacity(0.45))
                                    : Color.primary.opacity(0.08))
                                .frame(height: max(6, CGFloat(week.minutes / maxMinutes) * 130))
                                .frame(maxHeight: 130, alignment: .bottom)
                            Text(Self.labelFormatter.string(from: week.start))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }
}

// MARK: - Activity heatmap (GitHub style)

struct HeatmapCard: View {
    let days: [(day: Date, minutes: Double)]
    @Binding var selection: (day: Date, minutes: Double)?

    private func opacity(for minutes: Double) -> Double {
        switch minutes {
        case 0: return 0
        case ..<20: return 0.3
        case ..<40: return 0.55
        case ..<60: return 0.8
        default: return 1
        }
    }

    private var columns: [[(day: Date, minutes: Double)]] {
        stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text("Last 16 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 3) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 3) {
                        ForEach(column, id: \.day) { entry in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(entry.minutes > 0
                                    ? Theme.accent.opacity(opacity(for: entry.minutes))
                                    : Color.primary.opacity(0.07))
                                .frame(width: 14, height: 14)
                                .onTapGesture { selection = entry }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let selection {
                Text("\(Format.relativeDay(selection.day)) · \(selection.minutes > 0 ? Format.duration(minutes: selection.minutes) : "Rest day")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap a square to see that day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .card()
    }
}

// MARK: - Type breakdown

struct TypeBreakdownCard: View {
    let breakdown: [Stats.TypeTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By Workout Type")
                .font(.headline)
            let maxCount = max(breakdown.map(\.count).max() ?? 1, 1)
            ForEach(Array(breakdown.enumerated()), id: \.element.type) { index, item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.paletteColor(index))
                            .frame(width: 8, height: 8)
                        Text(item.type)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count) · \(Format.duration(minutes: item.minutes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                            Capsule()
                                .fill(Theme.paletteColor(index))
                                .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .card()
    }
}

#Preview("Stats") {
    NavigationStack {
        StatsView()
    }
    .environmentObject(WorkoutStore())
}
