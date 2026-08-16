import Foundation
import Combine

/// Owns interval-timer templates and persists them as JSON.
final class TemplateStore: ObservableObject {
    @Published private(set) var templates: [TimerTemplate] {
        didSet { persist() }
    }

    let storageURL: URL

    static let builtIns: [TimerTemplate] = [
        TimerTemplate(
            name: "Tabata",
            mode: .classic,
            config: ClassicConfig(prepareSeconds: 10, workSeconds: 20, restSeconds: 10, rounds: 8, sets: 1, restBetweenSetsSeconds: 60, cooldownSeconds: 0),
            isBuiltIn: true
        ),
        TimerTemplate(
            name: "HIIT 30/15",
            mode: .classic,
            config: ClassicConfig(prepareSeconds: 10, workSeconds: 30, restSeconds: 15, rounds: 8, sets: 2, restBetweenSetsSeconds: 60, cooldownSeconds: 60),
            isBuiltIn: true
        ),
        TimerTemplate(
            name: "Run Intervals",
            mode: .classic,
            config: ClassicConfig(prepareSeconds: 180, workSeconds: 60, restSeconds: 90, rounds: 6, sets: 1, restBetweenSetsSeconds: 120, cooldownSeconds: 180),
            isBuiltIn: true
        ),
        TimerTemplate(
            name: "EMOM 10",
            mode: .classic,
            config: ClassicConfig(prepareSeconds: 10, workSeconds: 45, restSeconds: 15, rounds: 10, sets: 1, restBetweenSetsSeconds: 60, cooldownSeconds: 0),
            isBuiltIn: true
        )
    ]

    init(storageDirectory: URL? = nil) {
        let dir = storageDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("templates.json")
        if FileManager.default.fileExists(atPath: storageURL.path) {
            templates = Self.load(from: storageURL)
        } else {
            templates = Self.builtIns
            persist()
        }
    }

    static func load(from url: URL) -> [TimerTemplate] {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([TimerTemplate].self, from: data) else { return [] }
        return list
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(templates) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    // MARK: - Mutations

    func upsert(_ template: TimerTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.insert(template, at: 0)
        }
    }

    @discardableResult
    func duplicate(_ template: TimerTemplate) -> TimerTemplate {
        var copy = template
        copy.id = UUID()
        copy.name = template.name + " Copy"
        copy.createdAt = Date()
        copy.isBuiltIn = false
        templates.insert(copy, at: 0)
        return copy
    }

    func delete(_ template: TimerTemplate) {
        templates.removeAll { $0.id == template.id }
    }

    func delete(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
    }
}
