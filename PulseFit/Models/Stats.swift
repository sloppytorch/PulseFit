import Foundation

/// Pure statistics helpers. All functions take explicit `now`/`calendar`
/// parameters so they are deterministic and unit-testable.
enum Stats {
    struct WeekTotal: Equatable {
        var start: Date
        var minutes: Double
        var sessions: Int
    }

    struct TypeTotal: Equatable {
        var type: String
        var count: Int
        var minutes: Double
    }

    struct Records: Equatable {
        var longestSession: Workout?
        var farthestSession: Workout?
        var biggestWeekMinutes: Double
        var longestStreak: Int
    }

    struct DayActivity: Identifiable, Equatable {
        var id: Date { day }
        var day: Date
        var minutes: Double
    }

    // MARK: - Streaks

    static func currentStreak(_ workouts: [Workout], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else {
                return 0
            }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    static func longestStreak(_ workouts: [Workout], calendar: Calendar = .current) -> Int {
        let days = Set(workouts.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for i in 1..<days.count {
            if let previous = calendar.date(byAdding: .day, value: -1, to: days[i]), previous == days[i - 1] {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - Weeks

    static func weekTotals(_ workouts: [Workout], weeks: Int, now: Date = Date(), calendar: Calendar = .current) -> [WeekTotal] {
        var result: [WeekTotal] = []
        let today = calendar.startOfDay(for: now)
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStartDay = calendar.date(byAdding: .weekOfYear, value: -offset, to: today),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStartDay) else { continue }
            let inWeek = workouts.filter { interval.contains($0.date) }
            result.append(
                WeekTotal(
                    start: interval.start,
                    minutes: inWeek.reduce(0) { $0 + $1.durationMinutes },
                    sessions: inWeek.count
                )
            )
        }
        return result
    }

    static func sessionsThisWeek(_ workouts: [Workout], now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { interval.contains($0.date) }.count
    }

    static func minutesThisWeek(_ workouts: [Workout], now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Breakdowns & records

    static func typeBreakdown(_ workouts: [Workout]) -> [TypeTotal] {
        var map: [String: TypeTotal] = [:]
        for w in workouts {
            let key = w.type.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            if var existing = map[key] {
                existing.count += 1
                existing.minutes += w.durationMinutes
                map[key] = existing
            } else {
                map[key] = TypeTotal(type: key, count: 1, minutes: w.durationMinutes)
            }
        }
        return map.values.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.type < $1.type
        }
    }

    static func totalMinutes(_ workouts: [Workout]) -> Double {
        workouts.reduce(0) { $0 + $1.durationMinutes }
    }

    static func records(_ workouts: [Workout], calendar: Calendar = .current) -> Records {
        let longest = workouts.max { $0.durationMinutes < $1.durationMinutes }
        let farthest = workouts.max { ($0.distanceKm ?? 0) < ($1.distanceKm ?? 0) }
        let biggestWeek = weekTotals(workouts, weeks: 520, calendar: calendar).map(\.minutes).max() ?? 0
        return Records(
            longestSession: longest,
            farthestSession: farthest,
            biggestWeekMinutes: biggestWeek,
            longestStreak: longestStreak(workouts, calendar: calendar)
        )
    }

    /// Daily minutes for the trailing `days` days, oldest first.
    static func dailyMinutes(_ workouts: [Workout], days: Int, now: Date = Date(), calendar: Calendar = .current) -> [DayActivity] {
        let byDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0.0) { $0 + $1.durationMinutes } }
        let today = calendar.startOfDay(for: now)
        var result: [DayActivity] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append(DayActivity(day: day, minutes: byDay[day] ?? 0))
        }
        return result
    }
}
