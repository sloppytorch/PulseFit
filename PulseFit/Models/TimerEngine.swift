import Foundation

/// Snapshot of the timer at a given total elapsed time.
struct EngineState: Equatable {
    var phaseIndex: Int
    var phase: Phase
    var elapsedInPhase: Double
    var remainingInPhase: Double
    var totalElapsed: Double
    var totalRemaining: Double
    var isFinished: Bool
    var nextPhase: Phase?
    var completedPhases: Int

    /// Fraction of the current phase remaining, 0...1 (ring depletes to 0).
    var phaseRemainingFraction: Double {
        guard phase.duration > 0 else { return 0 }
        return min(1, max(0, remainingInPhase / phase.duration))
    }

    /// Fraction of the whole workout completed, 0...1.
    var totalProgressFraction: Double {
        let total = totalElapsed + totalRemaining
        guard total > 0 else { return 0 }
        return min(1, max(0, totalElapsed / total))
    }
}

/// Pure, date-independent interval engine. Callers own the clock and ask
/// `state(at:)` for the layout at any total elapsed seconds.
struct TimerEngine: Equatable {
    let phases: [Phase]
    private let cumulative: [Double] // cumulative[i] = start time of phase i; cumulative[count] = total

    init(phases: [Phase]) {
        self.phases = phases
        var c = [Double](repeating: 0, count: phases.count + 1)
        for i in phases.indices {
            c[i + 1] = c[i] + max(0.1, phases[i].duration)
        }
        cumulative = c
    }

    var totalDuration: Double { cumulative.last ?? 0 }

    func startTime(of index: Int) -> Double {
        guard phases.indices.contains(index) else { return 0 }
        return cumulative[index]
    }

    func endTime(of index: Int) -> Double {
        guard phases.indices.contains(index) else { return totalDuration }
        return cumulative[index + 1]
    }

    func state(at elapsed: Double) -> EngineState {
        let total = totalDuration
        let t = min(max(0, elapsed), total)

        guard !phases.isEmpty, t < total else {
            let last = phases.last ?? Phase(
                id: "done", name: "Done", kind: .cooldown, duration: 0,
                setNumber: nil, roundNumber: nil, totalSets: 0, totalRounds: 0
            )
            return EngineState(
                phaseIndex: phases.count,
                phase: last,
                elapsedInPhase: last.duration,
                remainingInPhase: 0,
                totalElapsed: total,
                totalRemaining: 0,
                isFinished: true,
                nextPhase: nil,
                completedPhases: phases.count
            )
        }

        // First index whose end time is strictly greater than t.
        var lo = 0
        var hi = phases.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cumulative[mid + 1] > t { hi = mid } else { lo = mid + 1 }
        }
        let i = lo
        let phase = phases[i]
        let into = t - cumulative[i]
        return EngineState(
            phaseIndex: i,
            phase: phase,
            elapsedInPhase: into,
            remainingInPhase: phase.duration - into,
            totalElapsed: t,
            totalRemaining: total - t,
            isFinished: false,
            nextPhase: i + 1 < phases.count ? phases[i + 1] : nil,
            completedPhases: i
        )
    }

    /// Segment boundaries strictly after `elapsed` — used to schedule
    /// lock-screen notifications. Returns (endTme, phaseEnding, phaseStarting).
    func transitions(after elapsed: Double) -> [(at: Double, ending: Phase, starting: Phase?)] {
        var result: [(Double, Phase, Phase?)] = []
        for i in phases.indices where cumulative[i + 1] > elapsed {
            let next = i + 1 < phases.count ? phases[i + 1] : nil
            result.append((cumulative[i + 1], phases[i], next))
        }
        return result
    }
}
