import Foundation
import Combine

/// Owns the workout list and its JSON persistence in the app's Documents folder.
final class WorkoutStore: ObservableObject {
    @Published private(set) var workouts: [Workout] {
        didSet { persist() }
    }

    let storageURL: URL

    init(storageDirectory: URL? = nil) {
        let dir = storageDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("workouts.json")
        workouts = Self.load(from: storageURL)
    }

    // MARK: - Loading / saving

    static func load(from url: URL) -> [Workout] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let list = try? JSONDecoder().decode([Workout].self, from: data) else { return [] }
        return list.sorted { $0.date > $1.date }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(workouts) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    // MARK: - Mutations

    func upsert(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        } else {
            workouts.append(workout)
        }
        workouts.sort { $0.date > $1.date }
    }

    func delete(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
    }

    func deleteAll() {
        workouts.removeAll()
    }

    /// Merges imported workouts (by id). Returns how many were actually added.
    @discardableResult
    func importWorkouts(_ imported: [Workout]) -> Int {
        let existing = Set(workouts.map { $0.id })
        let fresh = imported.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return 0 }
        workouts.append(contentsOf: fresh)
        workouts.sort { $0.date > $1.date }
        return fresh.count
    }

    // MARK: - Workout type autocomplete

    /// Distinct type names, most recently used first (case-insensitive dedupe,
    /// keeps the newest spelling the user typed).
    var distinctTypes: [String] {
        var latest: [String: (date: Date, spelling: String)] = [:]
        for w in workouts {
            let key = w.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let spelling = w.type.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = latest[key], existing.date >= w.date { continue }
            latest[key] = (w.date, spelling)
        }
        return latest.values.sorted { $0.date > $1.date }.map { $0.spelling }
    }

    /// Suggestions shown under the type box: recents when empty, matches while typing.
    var recentTypes: [String] {
        Array(distinctTypes.prefix(5))
    }

    func suggestions(for prefix: String) -> [String] {
        Workout.suggestions(from: distinctTypes, for: prefix)
    }

    // MARK: - Sample data

    /// Deterministic demo data so Stats/autocomplete light up on first launch.
    func loadSampleData() {
        var generator = SeededGenerator(seed: 0x2026_0816)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let kinds: [(type: String, minutes: ClosedRange<Double>, km: ClosedRange<Double>?, notes: [String])] = [
            ("Morning Run", 25...70, 4...11, ["Easy pace, felt great", "Negative split", "Hills in the park", ""]),
            ("Bike Ride", 45...120, 12...35, ["Flat loop", "Windy but strong", ""]),
            ("HIIT Class", 25...45, nil, ["Sweaty!", "Coach pushed us hard", ""]),
            ("Strength", 40...75, nil, ["Upper body focus", "Leg day", "New PR on bench", ""]),
            ("Swim", 30...60, 1...2.5, ["2000m mixed", "Drills + kick sets", ""]),
            ("Yoga", 30...60, nil, ["Recovery flow", ""])
        ]

        for dayOffset in stride(from: 56, through: 0, by: -1) {
            guard Double.random(in: 0...1, using: &generator) < 0.45 else { continue }
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let pick = kinds[Int.random(in: 0..<kinds.count, using: &generator)]
            let minutes = Double.random(in: pick.minutes, using: &generator)
            let hour = Int.random(in: 6...19, using: &generator)
            let minute = Int.random(in: 0..<12, using: &generator) * 5
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
            dateComponents.hour = hour
            dateComponents.minute = minute
            let date = calendar.date(from: dateComponents) ?? day

            let workout = Workout(
                date: date,
                type: pick.type,
                durationMinutes: (minutes / 5).rounded() * 5,
                distanceKm: pick.km.map { ($0.lowerBound + ($0.upperBound - $0.lowerBound) * Double.random(in: 0...1, using: &generator)).rounded(toPlaces: 1) },
                effort: Int.random(in: 5...9, using: &generator),
                calories: Int((minutes * Double.random(in: 7...11, using: &generator)).rounded()),
                notes: pick.notes.randomElement(using: &generator) ?? ""
            )
            workouts.append(workout)
        }
        workouts.sort { $0.date > $1.date }
    }
}

/// SplitMix64 — small deterministic generator so sample data is reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
