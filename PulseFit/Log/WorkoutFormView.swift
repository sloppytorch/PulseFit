import SwiftUI

/// Values used to pre-fill the form (e.g. straight from a finished timer session).
struct WorkoutPrefill {
    var minutes: Double
    var notes: String
    var type: String = ""
}

struct WorkoutFormView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    let editing: Workout?
    let prefill: WorkoutPrefill?
    let onSaved: (() -> Void)?

    @State private var date = Date()
    @State private var type = ""
    @State private var durationMinutes: Double = 30
    @State private var hasDistance = false
    @State private var distanceText = ""
    @State private var hasCalories = false
    @State private var caloriesText = ""
    @State private var hasEffort = false
    @State private var effort: Double = 7
    @State private var notes = ""
    @FocusState private var typeFocused: Bool

    private let units = SettingsKeys.currentUnits

    init(editing: Workout? = nil, prefill: WorkoutPrefill? = nil, onSaved: (() -> Void)? = nil) {
        self.editing = editing
        self.prefill = prefill
        self.onSaved = onSaved

        if let e = editing {
            _date = State(initialValue: e.date)
            _type = State(initialValue: e.type)
            _durationMinutes = State(initialValue: max(5, (e.durationMinutes / 5).rounded() * 5))
            _hasDistance = State(initialValue: e.distanceKm != nil)
            _distanceText = State(initialValue: e.distanceKm.map { String(format: "%.1f", SettingsKeys.currentUnits.display(km: $0)) } ?? "")
            _hasCalories = State(initialValue: e.calories != nil)
            _caloriesText = State(initialValue: e.calories.map(String.init) ?? "")
            _hasEffort = State(initialValue: e.effort != nil)
            _effort = State(initialValue: Double(e.effort ?? 7))
            _notes = State(initialValue: e.notes)
        } else if let p = prefill {
            _type = State(initialValue: p.type)
            _durationMinutes = State(initialValue: max(5, (p.minutes / 5).rounded() * 5))
            _notes = State(initialValue: p.notes)
        }
    }

    /// Past categories: recents while the box is empty, matches while typing.
    private var suggestions: [String] {
        guard typeFocused else { return [] }
        return store.suggestions(for: type)
    }

    private var isValid: Bool {
        !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && durationMinutes > 0
    }

    var body: some View {
        Form {
            Section("Workout") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("What did you do? e.g. Morning Run", text: $type)
                    .focused($typeFocused)
                    .submitLabel(.next)
            }

            if !suggestions.isEmpty {
                Section("Past categories") {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            type = suggestion
                            typeFocused = false
                        } label: {
                            Label(suggestion, systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
            }

            Section {
                Stepper(value: $durationMinutes, in: 5...600, step: 5) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(Format.duration(minutes: durationMinutes))
                            .foregroundColor(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([15.0, 30, 45, 60, 75, 90, 120], id: \.self) { minutes in
                            durationChip(minutes)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Duration")
            }

            Section {
                Toggle("Track distance", isOn: $hasDistance.animation())
                if hasDistance {
                    HStack {
                        TextField("Distance", text: $distanceText)
                            .keyboardType(.decimalPad)
                        Text(units.abbreviation)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Distance")
            } footer: {
                Text("Great for runs, rides and swims — pace is calculated automatically.")
            }

            Section {
                Toggle("Rate effort", isOn: $hasEffort.animation())
                if hasEffort {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Perceived effort")
                            Spacer()
                            Text("\(Int(effort))/10 · \(Format.effortLabel(Int(effort)))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $effort, in: 1...10, step: 1)
                    }
                }
                Toggle("Calories", isOn: $hasCalories.animation())
                if hasCalories {
                    TextField("Calories burned", text: $caloriesText)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("Extras")
            }

            Section("Notes") {
                TextField("How did it go?", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(editing == nil ? "New Workout" : "Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!isValid)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func durationChip(_ minutes: Double) -> some View {
        Button {
            durationMinutes = minutes
        } label: {
            Text(Format.duration(minutes: minutes))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(durationMinutes == minutes ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(durationMinutes == minutes ? Theme.accent : Color(UIColor.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else { return }

        var workout = editing ?? Workout(type: trimmedType, durationMinutes: durationMinutes)
        workout.type = trimmedType
        workout.date = date
        workout.durationMinutes = durationMinutes

        let normalizedDistance = distanceText.replacingOccurrences(of: ",", with: ".")
        if hasDistance, let value = Double(normalizedDistance), value > 0 {
            workout.distanceKm = units.km(fromDisplay: value)
        } else {
            workout.distanceKm = nil
        }

        if hasEffort {
            workout.effort = Int(effort)
        } else {
            workout.effort = nil
        }

        if hasCalories, let calories = Int(caloriesText), calories > 0 {
            workout.calories = calories
        } else {
            workout.calories = nil
        }

        workout.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        store.upsert(workout)
        onSaved?()
        dismiss()
    }
}

#Preview("Form") {
    NavigationStack {
        WorkoutFormView()
    }
    .environmentObject(WorkoutStore())
}
