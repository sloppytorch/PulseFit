import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @Environment(\.dismiss) private var dismiss

    let editing: TimerTemplate?

    @State private var name = ""
    @State private var mode: TemplateMode = .classic
    @State private var prepare: Double = 10
    @State private var work: Double = 30
    @State private var rest: Double = 15
    @State private var rounds = 8
    @State private var sets = 1
    @State private var setRest: Double = 60
    @State private var cooldown: Double = 0
    @State private var segments: [Segment] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Template name", text: $name)
                }

                Section("Style") {
                    Picker("Style", selection: $mode) {
                        Text("Intervals").tag(TemplateMode.classic)
                        Text("Segments").tag(TemplateMode.segments)
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .classic {
                    classicSections
                } else {
                    segmentsSection
                }

                previewSection
            }
            .navigationTitle(editing == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if mode == .segments { EditButton() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draftTemplate.totalSeconds <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                load()
            }
        }
    }

    // MARK: - Classic intervals

    @ViewBuilder
    private var classicSections: some View {
        Section("Timing") {
            DurationStepperRow(label: "Get Ready", seconds: $prepare, range: 0...600)
            DurationStepperRow(label: "Work", seconds: $work, range: 5...1800)
            DurationStepperRow(label: "Rest", seconds: $rest, range: 0...900)
        }
        Section("Structure") {
            Stepper(value: $rounds, in: 1...40) {
                HStack {
                    Text("Rounds")
                    Spacer()
                    Text("\(rounds)×").foregroundColor(.secondary).monospacedDigit()
                }
            }
            Stepper(value: $sets, in: 1...10) {
                HStack {
                    Text("Sets")
                    Spacer()
                    Text("\(sets)×").foregroundColor(.secondary).monospacedDigit()
                }
            }
            DurationStepperRow(label: "Rest Between Sets", seconds: $setRest, range: 0...1800, step: 15)
            DurationStepperRow(label: "Cool Down", seconds: $cooldown, range: 0...1800, step: 15)
        }
    }

    // MARK: - Custom segments

    private var segmentsSection: some View {
        Section {
            ForEach($segments) { $segment in
                SegmentEditorRow(segment: $segment)
            }
            .onDelete { segments.remove(atOffsets: $0) }
            .onMove { from, to in segments.move(fromOffsets: from, toOffset: to) }
            Button {
                segments.append(Segment(name: "", kind: .work, durationSeconds: 60))
            } label: {
                Label("Add Segment", systemImage: "plus")
            }
        } header: {
            Text("Segments")
        } footer: {
            Text("Segments play in order. Reorder them in Edit mode.")
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Total time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Format.mmss(draftTemplate.totalSeconds))
                        .font(.body.bold().monospacedDigit())
                }
                Text("\(draftTemplate.expandedPhases.count) phases · \(draftTemplate.summary)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                PhaseTimelineView(phases: draftTemplate.expandedPhases)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Data flow

    private var draftTemplate: TimerTemplate {
        var template = editing ?? TimerTemplate(name: "Untitled")
        template.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        template.name = template.name.isEmpty ? "Untitled" : template.name
        template.mode = mode
        if mode == .classic {
            template.config = ClassicConfig(
                prepareSeconds: prepare,
                workSeconds: work,
                restSeconds: rest,
                rounds: rounds,
                sets: sets,
                restBetweenSetsSeconds: setRest,
                cooldownSeconds: cooldown
            )
            template.segments = nil
        } else {
            template.segments = segments
            template.config = nil
        }
        return template
    }

    private func load() {
        guard let template = editing else { return }
        name = template.name
        mode = template.mode
        if let c = template.config {
            prepare = c.prepareSeconds
            work = c.workSeconds
            rest = c.restSeconds
            rounds = c.rounds
            sets = c.sets
            setRest = c.restBetweenSetsSeconds
            cooldown = c.cooldownSeconds
        }
        segments = template.segments ?? []
    }

    private func save() {
        templateStore.upsert(draftTemplate)
        dismiss()
    }
}

/// A stepper row that shows a mm:ss value (or "Off" for zero).
struct DurationStepperRow: View {
    let label: String
    @Binding var seconds: Double
    var range: ClosedRange<Double>
    var step: Double = 5

    var body: some View {
        Stepper(value: $seconds, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text(seconds <= 0 ? "Off" : Format.mmss(seconds))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// Editor for one custom segment.
struct SegmentEditorRow: View {
    @Binding var segment: Segment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Kind", selection: $segment.kind) {
                ForEach(PhaseKind.allCases) { kind in
                    Text(kind.defaultName).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.color(for: segment.kind))

            TextField("Custom name (optional)", text: $segment.name)

            Stepper(value: $segment.durationSeconds, in: 5...3600, step: 5) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(Format.mmss(segment.durationSeconds))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Editor") {
    TemplateEditorView(editing: nil)
        .environmentObject(TemplateStore())
}
