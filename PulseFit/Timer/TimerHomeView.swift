import SwiftUI

struct TimerHomeView: View {
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var showEditor = false
    @State private var editingTemplate: TimerTemplate?
    @State private var runningTemplate: TimerTemplate?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if templateStore.templates.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No templates yet")
                                .font(.headline)
                            Text("Tap + to build your first interval timer.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    ForEach(templateStore.templates) { template in
                        Button {
                            runningTemplate = template
                        } label: {
                            TemplateRow(template: template)
                        }
                        .contextMenu {
                            Button {
                                runningTemplate = template
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            Button {
                                editingTemplate = template
                                showEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                templateStore.duplicate(template)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                templateStore.delete(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { templateStore.delete(at: $0) }
                } header: {
                    Text("Templates")
                } footer: {
                    Text("Tap a template to start it. Long-press to edit, duplicate or delete.")
                }
            }
            .navigationTitle("Interval Timer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTemplate = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: { editingTemplate = nil }) {
                TemplateEditorView(editing: editingTemplate)
            }
            .fullScreenCover(item: $runningTemplate) { template in
                IntervalRunnerView(template: template)
            }
        }
    }
}

/// A template row: name, badge, total time, summary and a mini phase timeline.
struct TemplateRow: View {
    let template: TimerTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if template.isBuiltIn {
                    Text("BUILT-IN")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                Label(Format.mmss(template.totalSeconds), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(template.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
            PhaseTimelineView(phases: template.expandedPhases)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Proportional, color-coded strip showing the whole workout at a glance.
struct PhaseTimelineView: View {
    let phases: [Phase]

    private var total: Double {
        max(1, phases.reduce(0) { $0 + $1.duration })
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(phases.prefix(80)) { phase in
                    Capsule()
                        .fill(Theme.color(for: phase.kind).opacity(0.9))
                        .frame(width: max(1.5, geo.size.width * CGFloat(phase.duration / total) - 1))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}

#Preview("Timer Home") {
    TimerHomeView()
        .environmentObject(TemplateStore())
}
