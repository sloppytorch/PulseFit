import XCTest
@testable import PulseFit

final class StatsLogicTests: XCTestCase {
    private func workout(daysAgo: Int, type: String = "Run", minutes: Double = 30) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Workout(date: date, type: type, durationMinutes: minutes)
    }

    func testCurrentStreak() {
        XCTAssertEqual(Stats.currentStreak([], calendar: .current), 0)

        let today = [workout(daysAgo: 0)]
        XCTAssertEqual(Stats.currentStreak(today, calendar: .current), 1)

        let three = [workout(daysAgo: 0), workout(daysAgo: 1), workout(daysAgo: 2)]
        XCTAssertEqual(Stats.currentStreak(three, calendar: .current), 3)

        // Streak survives when today has no workout yet but yesterday did.
        let yesterday = [workout(daysAgo: 1), workout(daysAgo: 2)]
        XCTAssertEqual(Stats.currentStreak(yesterday, calendar: .current), 2)

        // A gap breaks the streak.
        let gapped = [workout(daysAgo: 1), workout(daysAgo: 3)]
        XCTAssertEqual(Stats.currentStreak(gapped, calendar: .current), 1)

        // Old workouts alone don't count.
        let old = [workout(daysAgo: 5), workout(daysAgo: 6)]
        XCTAssertEqual(Stats.currentStreak(old, calendar: .current), 0)
    }

    func testLongestStreak() {
        XCTAssertEqual(Stats.longestStreak([], calendar: .current), 0)
        let workouts = [
            workout(daysAgo: 10), workout(daysAgo: 9), workout(daysAgo: 8),
            workout(daysAgo: 5),
            workout(daysAgo: 2), workout(daysAgo: 1), workout(daysAgo: 0)
        ]
        XCTAssertEqual(Stats.longestStreak(workouts, calendar: .current), 3)
    }

    func testWeekTotalsLengthAndSum() {
        let workouts = (0..<10).map { workout(daysAgo: $0, minutes: 10) }
        let weeks = Stats.weekTotals(workouts, weeks: 8, calendar: .current)
        XCTAssertEqual(weeks.count, 8)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.sessions }, 10)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.minutes }, 100, accuracy: 0.001)
    }

    func testTypeBreakdownSortsByCount() {
        let workouts = [
            workout(daysAgo: 1, type: "Run"),
            workout(daysAgo: 2, type: "Run"),
            workout(daysAgo: 3, type: "Swim"),
            workout(daysAgo: 4, type: " run ")
        ]
        let breakdown = Stats.typeBreakdown(workouts)
        XCTAssertEqual(breakdown.count, 3) // " run " is trimmed to "run", distinct from "Run"
        XCTAssertEqual(breakdown.first?.type, "Run")
        XCTAssertEqual(breakdown.first?.count, 2)
    }

    func testSuggestions() {
        let types = ["Morning Run", "Bike Ride", "Run Intervals", "Swim"]
        XCTAssertEqual(Workout.suggestions(from: types, for: ""), ["Morning Run", "Bike Ride", "Run Intervals", "Swim"])
        XCTAssertEqual(Workout.suggestions(from: types, for: "run"), ["Morning Run", "Run Intervals"])
        XCTAssertEqual(Workout.suggestions(from: types, for: "RUN"), ["Morning Run", "Run Intervals"])
        XCTAssertEqual(Workout.suggestions(from: types, for: "bike"), ["Bike Ride"])
        XCTAssertEqual(Workout.suggestions(from: types, for: "Morning Run"), [])
        XCTAssertEqual(Workout.suggestions(from: types, for: "zzz"), [])
        XCTAssertEqual(Workout.suggestions(from: types, for: "", limit: 2).count, 2)
    }

    func testWorkoutDecodingToleratesMissingFields() throws {
        let json = """
        {"id": "E621E1B8-9C52-4C9B-9DC0-2B0AE7C0E2B4", "date": 700000000, "type": "Run", "durationMinutes": 42}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Workout.self, from: json)
        XCTAssertEqual(decoded.type, "Run")
        XCTAssertEqual(decoded.durationMinutes, 42)
        XCTAssertNil(decoded.distanceKm)
        XCTAssertNil(decoded.effort)
        XCTAssertEqual(decoded.notes, "")
    }

    func testPace() {
        let run = Workout(type: "Run", durationMinutes: 30, distanceKm: 5)
        XCTAssertEqual(run.paceSecondsPerKm ?? 0, 360, accuracy: 0.001)
        let yoga = Workout(type: "Yoga", durationMinutes: 30)
        XCTAssertNil(yoga.paceSecondsPerKm)
    }

    func testDailyMinutesSpansRequestedDays() {
        let days = Stats.dailyMinutes([], days: 28, calendar: .current)
        XCTAssertEqual(days.count, 28)
        XCTAssertTrue(days.allSatisfy { $0.minutes == 0 })
    }

    func testSampleDataIsDeterministic() {
        let a = WorkoutStore(storageDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-test-a-\(UUID().uuidString)"))
        let b = WorkoutStore(storageDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-test-b-\(UUID().uuidString)"))
        a.loadSampleData()
        b.loadSampleData()
        XCTAssertFalse(a.workouts.isEmpty)
        XCTAssertEqual(a.workouts.count, b.workouts.count)
        XCTAssertEqual(a.workouts.first?.type, b.workouts.first?.type)
        let aDate = a.workouts.first?.date.timeIntervalSince1970 ?? 0
        let bDate = b.workouts.first?.date.timeIntervalSince1970 ?? 0
        XCTAssertEqual(aDate, bDate, accuracy: 1.0)
    }
}
