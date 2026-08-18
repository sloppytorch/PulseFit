import Foundation

// MARK: - Building blocks

enum PhaseKind: String, Codable, CaseIterable, Identifiable {
    case prepare, work, rest, setRest, cooldown, custom

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .prepare: return "Get Ready"
        case .work: return "Work"
        case .rest: return "Rest"
        case .setRest: return "Set Rest"
        case .cooldown: return "Cool Down"
        case .custom: return "Segment"
        }
    }

    /// 24-bit RGB color used for this phase across the whole app.
    var colorHex: UInt32 {
        switch self {
        case .prepare: return 0xFFD60A // yellow
        case .work: return 0xFF453A // red
        case .rest: return 0x0A84FF // blue
        case .setRest: return 0x64D2FF // cyan
        case .cooldown: return 0xBF5AF2 // purple
        case .custom: return 0xFF375F // pink
        }
    }
}

/// One editable step in a custom-segments template.
struct Segment: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: PhaseKind
    var durationSeconds: Double

    init(id: UUID = UUID(), name: String = "", kind: PhaseKind = .work, durationSeconds: Double = 60) {
        self.id = id
        self.name = name
        self.kind = kind
        self.durationSeconds = durationSeconds
    }
}

/// Classic interval builder: prepare, N sets x M rounds of work/rest, set rest, cooldown.
struct ClassicConfig: Codable, Hashable {
    var prepareSeconds: Double = 10
    var workSeconds: Double = 30
    var restSeconds: Double = 15
    var rounds: Int = 8
    var sets: Int = 1
    var restBetweenSetsSeconds: Double = 60
    var cooldownSeconds: Double = 0

    var totalSeconds: Double {
        TemplateExpander.phases(for: self).reduce(0) { $0 + $1.duration }
    }
}

enum TemplateMode: String, Codable {
    case classic
    case segments
}

// MARK: - Template

struct TimerTemplate: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var mode: TemplateMode
    var config: ClassicConfig?
    var segments: [Segment]?
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        mode: TemplateMode = .classic,
        config: ClassicConfig? = nil,
        segments: [Segment]? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.mode = mode
        self.config = config
        self.segments = segments
        self.isBuiltIn = isBuiltIn
    }

    var expandedPhases: [Phase] { TemplateExpander.phases(for: self) }

    var totalSeconds: Double {
        switch mode {
        case .classic: return config?.totalSeconds ?? 0
        case .segments: return (segments ?? []).reduce(0) { $0 + max(1, $1.durationSeconds) }
        }
    }

    /// One-line description, e.g. "2 sets x 8 rounds - 30s work / 15s rest".
    var summary: String {
        switch mode {
        case .classic:
            guard let c = config else { return "" }
            var parts: [String] = []
            if c.sets > 1 {
                parts.append("\(c.sets) sets x \(c.rounds) rounds")
            } else {
                parts.append("\(c.rounds) rounds")
            }
            parts.append("\(Int(c.workSeconds))s work / \(Int(c.restSeconds))s rest")
            return parts.joined(separator: " · ")
        case .segments:
            let count = segments?.count ?? 0
            return "\(count) segment\(count == 1 ? "" : "s")"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, mode, config, segments, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        mode = try c.decodeIfPresent(TemplateMode.self, forKey: .mode) ?? .classic
        config = try c.decodeIfPresent(ClassicConfig.self, forKey: .config)
        segments = try c.decodeIfPresent([Segment].self, forKey: .segments)
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}

// MARK: - Runtime phase

/// A fully expanded, timed step the engine walks through.
struct Phase: Identifiable, Hashable {
    var id: String
    var name: String
    var kind: PhaseKind
    var duration: Double
    var setNumber: Int?
    var roundNumber: Int?
    var totalSets: Int
    var totalRounds: Int
}

enum TemplateExpander {
    static func phases(for template: TimerTemplate) -> [Phase] {
        switch template.mode {
        case .classic:
            guard let c = template.config else { return [] }
            return phases(for: c)
        case .segments:
            return (template.segments ?? []).enumerated().map { index, segment in
                Phase(
                    id: "segment-\(index)-\(segment.id.uuidString)",
                    name: segment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? segment.kind.defaultName : segment.name,
                    kind: segment.kind,
                    duration: max(1, segment.durationSeconds),
                    setNumber: nil,
                    roundNumber: nil,
                    totalSets: 0,
                    totalRounds: 0
                )
            }
        }
    }

    static func phases(for c: ClassicConfig) -> [Phase] {
        var result: [Phase] = []
        let sets = max(1, c.sets)
        let rounds = max(1, c.rounds)

        func append(_ kind: PhaseKind, _ seconds: Double, set: Int?, round: Int?) {
            guard seconds > 0 else { return }
            let id = "classic-\(result.count)-\(kind.rawValue)-\(set ?? 0)-\(round ?? 0)"
            result.append(
                Phase(
                    id: id,
                    name: kind.defaultName,
                    kind: kind,
                    duration: seconds,
                    setNumber: set,
                    roundNumber: round,
                    totalSets: sets,
                    totalRounds: rounds
                )
            )
        }

        append(.prepare, c.prepareSeconds, set: nil, round: nil)

        for s in 1...sets {
            for r in 1...rounds {
                append(.work, c.workSeconds, set: s, round: r)
                if r < rounds {
                    append(.rest, c.restSeconds, set: s, round: r)
                }
            }
            if s < sets {
                append(.setRest, c.restBetweenSetsSeconds, set: s, round: nil)
            }
        }

        append(.cooldown, c.cooldownSeconds, set: nil, round: nil)
        return result
    }
}
