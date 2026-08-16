import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var templateStore: TemplateStore

    @AppStorage(SettingsKeys.units) private var units: Units = .metric
    @AppStorage(SettingsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKeys.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(SettingsKeys.backgroundTimer) private var backgroundTimer = true
    @AppStorage(SettingsKeys.phaseAlerts) private var phaseAlerts = true {
        willSet {
            if newValue { TimerSession.requestAuthorization() }
        }
    }
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 4

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var importResult: String?
    @State private var showDeleteAllDialog = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $units) {
                        ForEach(Units.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Stepper(value: $weeklyGoal, in: 1...14) {
                        HStack {
                            Text("Weekly goal")
                            Spacer()
                            Text("\(weeklyGoal) workouts")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Distances are stored in kilometers and converted for display.")
                }

                Section {
                    Toggle("Beeps & sounds", isOn: $soundEnabled)
                    Toggle("Voice prompts", isOn: $voiceEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Keep running in background", isOn: $backgroundTimer)
                    Toggle("Phase alerts on lock screen", isOn: $phaseAlerts)
                } header: {
                    Text("Interval Timer")
                } footer: {
                    Text("Background mode keeps the timer alive when you lock the screen by playing inaudible audio.")
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL, preview: SharePreview("PulseFit Export"))
                    } else {
                        Button {
                            prepareExport()
                        } label: {
                            Label("Prepare Export File", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import from File", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        workoutStore.loadSampleData()
                    } label: {
                        Label("Load Sample Data", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) {
                        showDeleteAllDialog = true
                    } label: {
                        Label("Delete All Workouts", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    if let importResult {
                        Text(importResult)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Workouts logged", value: "\(workoutStore.workouts.count)")
                    LabeledContent("Timer templates", value: "\(templateStore.templates.count)")
                    Text("All data lives on your device. Export creates a JSON backup you can re-import anytime.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    importFrom(url: url)
                }
            }
            .confirmationDialog("Delete every logged workout?", isPresented: $showDeleteAllDialog, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    workoutStore.deleteAll()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    // MARK: - Export / import

    private func prepareExport() {
        let payload = ExportPayload(
            workouts: workoutStore.workouts,
            templates: templateStore.templates,
            exportedAt: Date()
        )
        if let data = try? JSONEncoder().encode(payload) {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("PulseFit-Export.json")
            do {
                try data.write(to: url, options: .atomic)
                exportURL = url
            } catch {
                importResult = "Couldn't create the export file."
            }
        }
    }

    private func importFrom(url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer {
            if secured { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            importResult = "Couldn't read that file."
            return
        }
        if let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) {
            let added = workoutStore.importWorkouts(payload.workouts)
            importResult = "Imported \(added) workout\(added == 1 ? "" : "s")."
        } else if let list = try? JSONDecoder().decode([Workout].self, from: data) {
            let added = workoutStore.importWorkouts(list)
            importResult = "Imported \(added) workout\(added == 1 ? "" : "s")."
        } else {
            importResult = "That file isn't a PulseFit export."
        }
    }
}

struct ExportPayload: Codable {
    var workouts: [Workout]
    var templates: [TimerTemplate]
    var exportedAt: Date
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(WorkoutStore())
        .environmentObject(TemplateStore())
}
