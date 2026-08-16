import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    let workoutID: UUID

    @State private var showEdit = false
    @State private var showDeleteDialog = false

    private let units = SettingsKeys.currentUnits

    private var workout: Workout? {
        store.workouts.first { $0.id == workoutID }
    }

    var body: some View {
        Group {
            if let workout {
                content(workout)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("This workout was deleted")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(workout?.type ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let workout {
                NavigationStack {
                    WorkoutFormView(editing: workout)
                }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let workout {
                    store.delete(workout)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func content(_ workout: Workout) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: workout.symbolName)
                        .font(.system(size: 42))
                        .foregroundColor(Theme.accent)
                    Text(workout.type)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(Format.fullDateTime(workout.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("Duration", Format.duration(minutes: workout.durationMinutes), "clock")
                    if let km = workout.distanceKm {
                        statCard("Distance", Format.distance(km: km, units: units), "map")
                    }
                    if let pace = workout.paceSecondsPerKm {
                        statCard("Pace", Format.pace(secondsPerKm: pace, units: units), "speedometer")
                    }
                    if let calories = workout.calories {
                        statCard("Calories", "\(calories) kcal", "flame.fill")
                    }
                    if let effort = workout.effort {
                        statCard("Effort", "RPE \(effort) · \(Format.effortLabel(effort))", "bolt.heart.fill")
                    }
                }

                if !workout.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                        Text(workout.notes)
                            .font(.body)
                    }
                    .card()
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func statCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .card()
    }
}
