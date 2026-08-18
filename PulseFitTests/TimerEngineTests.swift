import XCTest
@testable import PulseFit

final class TimerEngineTests: XCTestCase {
    private func simplePhases() -> [Phase] {
        [
            Phase(id: "test-0", name: "Get Ready", kind: .prepare, duration: 10, setNumber: nil, roundNumber: nil, totalSets: 0, totalRounds: 0),
            Phase(id: "test-1", name: "Work", kind: .work, duration: 30, setNumber: 1, roundNumber: 1, totalSets: 1, totalRounds: 2),
            Phase(id: "test-2", name: "Rest", kind: .rest, duration: 15, setNumber: 1, roundNumber: 1, totalSets: 1, totalRounds: 2),
            Phase(id: "test-3", name: "Work", kind: .work, duration: 30, setNumber: 1, roundNumber: 2, totalSets: 1, totalRounds: 2)
        ]
    }

    func testEmptyEngineIsFinished() {
        let engine = TimerEngine(phases: [])
        XCTAssertTrue(engine.state(at: 0).isFinished)
        XCTAssertEqual(engine.totalDuration, 0)
    }

    func testExpansionCountsAndDurations() {
        let config = ClassicConfig(
            prepareSeconds: 10, workSeconds: 30, restSeconds: 15,
            rounds: 3, sets: 2, restBetweenSetsSeconds: 60, cooldownSeconds: 30
        )
        let phases = TemplateExpander.phases(for: config)
        // prepare + (work,rest,work,rest,work) + setRest + (work,rest,work,rest,work) + cooldown
        XCTAssertEqual(phases.count, 1 + 5 + 1 + 5 + 1)
        XCTAssertEqual(phases.filter { $0.kind == .work }.count, 6)
        XCTAssertEqual(phases.filter { $0.kind == .rest }.count, 4)
        XCTAssertEqual(phases.filter { $0.kind == .setRest }.count, 1)
        let total = phases.reduce(0.0) { $0 + $1.duration }
        // 10 prepare + 2 x (3x30 work + 2x15 rest) + 60 set rest + 30 cool down
        let expected: Double = 340
        XCTAssertEqual(total, expected, accuracy: 0.001)
    }

    func testZeroDurationsAreDropped() {
        let config = ClassicConfig(
            prepareSeconds: 0, workSeconds: 30, restSeconds: 0,
            rounds: 2, sets: 1, restBetweenSetsSeconds: 0, cooldownSeconds: 0
        )
        let phases = TemplateExpander.phases(for: config)
        XCTAssertEqual(phases.count, 2)
        XCTAssertEqual(phases.first?.kind, .work)
    }

    func testStateBoundaries() {
        let engine = TimerEngine(phases: simplePhases())
        XCTAssertEqual(engine.totalDuration, 85, accuracy: 0.001)

        let start = engine.state(at: 0)
        XCTAssertEqual(start.phaseIndex, 0)
        XCTAssertFalse(start.isFinished)
        XCTAssertEqual(start.remainingInPhase, 10, accuracy: 0.001)

        let midFirstWork = engine.state(at: 25)
        XCTAssertEqual(midFirstWork.phaseIndex, 1)
        XCTAssertEqual(midFirstWork.elapsedInPhase, 15, accuracy: 0.001)
        XCTAssertEqual(midFirstWork.remainingInPhase, 15, accuracy: 0.001)
        XCTAssertEqual(midFirstWork.nextPhase?.kind, .rest)

        let exactBoundary = engine.state(at: 40) // rest phase starts at 40
        XCTAssertEqual(exactBoundary.phaseIndex, 2)
        XCTAssertEqual(exactBoundary.elapsedInPhase, 0, accuracy: 0.001)

        let done = engine.state(at: 85)
        XCTAssertTrue(done.isFinished)
        XCTAssertEqual(done.totalElapsed, 85, accuracy: 0.001)

        XCTAssertTrue(engine.state(at: 999).isFinished)

        let negative = engine.state(at: -5)
        XCTAssertEqual(negative.phaseIndex, 0)
        XCTAssertEqual(negative.totalElapsed, 0, accuracy: 0.001)
    }

    func testStartEndTimes() {
        let engine = TimerEngine(phases: simplePhases())
        XCTAssertEqual(engine.startTime(of: 0), 0)
        XCTAssertEqual(engine.endTime(of: 0), 10)
        XCTAssertEqual(engine.startTime(of: 1), 10)
        XCTAssertEqual(engine.endTime(of: 3), 85)
        XCTAssertEqual(engine.startTime(of: 99), 0)
        XCTAssertEqual(engine.endTime(of: 99), 85)
    }

    func testTransitionsAfter() {
        let engine = TimerEngine(phases: simplePhases())
        let transitions = engine.transitions(after: 20)
        XCTAssertEqual(transitions.count, 3)
        XCTAssertEqual(transitions[0].at, 40)
        XCTAssertEqual(transitions[0].starting?.kind, .rest)
        XCTAssertNil(transitions.last?.starting)
    }

    func testSegmentsModeExpansion() {
        var template = TimerTemplate(name: "Custom", mode: .segments)
        template.segments = [
            Segment(name: "Warmup jog", kind: .prepare, durationSeconds: 120),
            Segment(name: "", kind: .work, durationSeconds: 60)
        ]
        XCTAssertEqual(template.expandedPhases.count, 2)
        XCTAssertEqual(template.expandedPhases.last?.name, "Work") // blank name falls back
        XCTAssertEqual(template.totalSeconds, 180)
        XCTAssertTrue(template.summary.contains("2 segments"))
    }
}
