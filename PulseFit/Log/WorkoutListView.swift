import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var search = ""
    @State private var showForm = false
    @State private var period: Period = .all
    @State private var typeFilter: String?

    private let units = SettingsKeys.currentUnits

    enum Period: String, CaseIterable, Identifiable {
        case all = "All"
        case week = "This Week"
        case month = "This Month"
        var id: String { rawValue }
    }

    private var filtered: [Workout] {
        var result = store.workouts
        if !search.isEmpty {
            result = result.filter {
                $0.type.localizedCaseInsensitiveContains(search)
                    || $0.notes.localizedCaseInsensitiveContains(search)
            }
        }
        switch period {
        case .all:
            break
        case .week:
            result = result.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        case .month:
            result = result.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        }
        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        return result
    }

    private var grouped: [(day: Date, items: [Workout])] {
        let calendar = Calendar.current
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    emptySection
                } else {
                    ForEach(grouped, id: \.day) { group in
                        Section {
                            ForEach(group.items) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workoutID: workout.id)
                                } label: {
                                    WorkoutRow(workout: workout, units: units)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.delete(workout)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(Format.relativeDay(group.day))
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .searchable(text: $search, prompt: "Search type or notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                NavigationStack {
                    WorkoutFormView()
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Period", selection: $period) {
                ForEach(Period.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            Picker("Type", selection: Binding(
                get: { typeFilter ?? "All" },
                set: { typeFilter = $0 == "All" ? nil : $0 }
            )) {
                Text("All types").tag("All")
                ForEach(store.distinctTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
        } label: {
            Image(systemName: typeFilter == nil && period == .all
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(store.workouts.isEmpty ? "No workouts yet" : "Nothing matches")
                    .font(.headline)
                Text(store.workouts.isEmpty
                    ? "Tap + to log your first workout — date, type, notes and more."
                    : "Try clearing the search or filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let units: Units

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.type)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(Format.duration(minutes: workout.durationMinutes))
                    if let km = workout.distanceKm {
                        Text("·")
                        Text(Format.distance(km: km, units: units))
                    }
                    if let pace = workout.paceSecondsPerKm {
                        Text("·")
                        Text(Format.pace(secondsPerKm: pace, units: units))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Format.timeOfDay(workout.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let effort = workout.effort {
                    Text("RPE \(effort)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("List") {
    WorkoutListView()
        .environmentObject(WorkoutStore())
}
