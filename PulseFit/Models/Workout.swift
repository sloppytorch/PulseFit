import Foundation

/// A single logged workout session.
struct Workout: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var type: String
    var durationMinutes: Double
    var distanceKm: Double?
    var effort: Int?
    var calories: Int?
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: String,
        durationMinutes: Double,
        distanceKm: Double? = nil,
        effort: Int? = nil,
        calories: Int? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.effort = effort
        self.calories = calories
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Seconds per kilometer, if a usable distance exists.
    var paceSecondsPerKm: Double? {
        guard let km = distanceKm, km > 0, durationMinutes > 0 else { return nil }
        return durationMinutes * 60 / km
    }

    /// SF Symbol name picked from keywords in the workout type.
    var symbolName: String {
        let t = type.lowercased()
        if t.contains("run") || t.contains("jog") || t.contains("sprint") { return "figure.run" }
        if t.contains("walk") || t.contains("hike") { return "figure.walk" }
        if t.contains("bike") || t.contains("cycl") || t.contains("spin") { return "bicycle" }
        if t.contains("swim") { return "figure.pool.swim" }
        if t.contains("row") { return "figure.rower" }
        if t.contains("hiit") || t.contains("interval") || t.contains("cardio") { return "heart.circle.fill" }
        if t.contains("strength") || t.contains("lift") || t.contains("gym") || t.contains("weight") { return "dumbbell" }
        if t.contains("yoga") || t.contains("stretch") || t.contains("mobility") { return "figure.mind.and.body" }
        return "flame.fill"
    }

    // MARK: - Robust decoding (tolerates older exports missing newer fields)

    enum CodingKeys: String, CodingKey {
        case id, date, type, durationMinutes, distanceKm, effort, calories, notes, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        durationMinutes = try c.decodeIfPresent(Double.self, forKey: .durationMinutes) ?? 0
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        effort = try c.decodeIfPresent(Int.self, forKey: .effort)
        calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

extension Workout {
    /// Case-insensitive matching of past types for the autocomplete feature.
    /// - Parameters:
    ///   - types: distinct type names ordered most-recently-used first.
    ///   - prefix: what the user has typed so far (may be empty).
    static func suggestions(from types: [String], for prefix: String, limit: Int = 5) -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(types.prefix(limit))
        }
        return types.filter {
            $0.localizedCaseInsensitiveContains(trimmed) && $0.caseInsensitiveCompare(trimmed) != .orderedSame
        }.prefix(limit).map { $0 }
    }
}
