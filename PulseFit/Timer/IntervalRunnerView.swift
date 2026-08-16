import SwiftUI
import UIKit
import UserNotifications

/// Owns the clock and drives the pure `TimerEngine` with real time.
/// All UI mutations happen on the main thread (the tick timer runs on the
/// main run loop in `.common` mode so it keeps firing during scrolling).
final class TimerSession: ObservableObject {
    let template: TimerTemplate
    let phases: [Phase]
    let engine: TimerEngine

    @Published private(set) var state: EngineState
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?
    private var lastPhaseIndex = -1
    private var lastSecondRemaining = Int.max

    init(template: TimerTemplate) {
        self.template = template
        let expanded = template.expandedPhases
        self.phases = expanded
        let built = TimerEngine(phases: expanded)
        self.engine = built
        self.state = built.state(at: 0)
    }

    /// Real seconds counted against the workout (pause time excluded).
    var totalElapsed: TimeInterval {
        accumulated + (startDate.map { Date().timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Control

    func start() {
        guard !isFinished, !isRunning, !phases.isEmpty else { return }
        SoundPlayer.shared.prepare()
        SoundPlayer.shared.startKeepAlive()
        Self.requestAuthorization()
        isRunning = true
        startDate = Date()
        lastPhaseIndex = -1
        lastSecondRemaining = .max
        rescheduleNotifications()
        startTicking()
        tick()
    }

    func pause() {
        guard isRunning, !isFinished else { return }
        accumulated = totalElapsed
        startDate = nil
        isRunning = false
        stopTicking()
        SoundPlayer.shared.stopKeepAlive()
        cancelNotifications()
        state = engine.state(at: totalElapsed)
    }

    func resume() {
        guard !isRunning, !isFinished else { return }
        isRunning = true
        startDate = Date()
        SoundPlayer.shared.startKeepAlive()
        rescheduleNotifications()
        startTicking()
        tick()
    }

    func skipForward() {
        guard !isFinished, !phases.isEmpty else { return }
        let current = engine.state(at: totalElapsed)
        guard !current.isFinished, current.phaseIndex + 1 < phases.count else {
            finish()
            return
        }
        setElapsed(to: engine.endTime(of: current.phaseIndex))
    }

    func skipBack() {
        guard !isFinished, !phases.isEmpty else { return }
        let current = engine.state(at: totalElapsed)
        if current.elapsedInPhase > 2 {
            setElapsed(to: engine.startTime(of: current.phaseIndex))
        } else if current.phaseIndex > 0 {
            setElapsed(to: engine.startTime(of: current.phaseIndex - 1))
        } else {
            setElapsed(to: 0)
        }
    }

    /// Full teardown with no completion flow.
    func stop() {
        stopTicking()
        startDate = nil
        isRunning = false
        SoundPlayer.shared.stopKeepAlive()
        cancelNotifications()
    }

    /// Recomputes state from wall-clock time — called when returning to the
    /// foreground so the timer catches up after any suspension.
    func tick() {
        let next = engine.state(at: totalElapsed)
        state = next
        if next.isFinished {
            finish()
            return
        }
        if next.phaseIndex != lastPhaseIndex {
            lastPhaseIndex = next.phaseIndex
            cue(for: next.phase)
            lastSecondRemaining = Int(next.remainingInPhase.rounded(.up))
        }
        let secondRemaining = Int(next.remainingInPhase.rounded(.up))
        if secondRemaining != lastSecondRemaining {
            if (1...3).contains(secondRemaining) {
                SoundPlayer.shared.tick()
            }
            lastSecondRemaining = secondRemaining
        }
    }

    // MARK: - Internals

    private func setElapsed(_ value: TimeInterval) {
        accumulated = min(max(0, value), engine.totalDuration)
        startDate = isRunning ? Date() : nil
        lastPhaseIndex = -1
        lastSecondRemaining = .max
        rescheduleNotifications()
        state = engine.state(at: totalElapsed)
    }

    private func finish() {
        guard !isFinished else { return }
        accumulated = engine.totalDuration
        startDate = nil
        stopTicking()
        isRunning = false
        isFinished = true
        lastPhaseIndex = .max
        state = engine.state(at: engine.totalDuration)
        SoundPlayer.shared.stopKeepAlive()
        cancelNotifications()
        SoundPlayer.shared.finish()
        Haptics.success()
        SoundPlayer.shared.speak("Workout complete. Great job!")
    }

    private func cue(for phase: Phase) {
        SoundPlayer.shared.transition(for: phase.kind)
        Haptics.impact(phase.kind == .work ? .heavy : .light)
        SoundPlayer.shared.speak(phase.name)
    }

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Lock-screen notifications

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func rescheduleNotifications() {
        guard SettingsKeys.defaultedBool(.phaseAlerts) else { return }
        let center = UNUserNotificationCenter.current()
        let elapsed = totalElapsed
        let upcoming = Array(engine.transitions(after: elapsed).prefix(64))
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            center.removeAllPendingNotificationRequests()
            for transition in upcoming {
                let delay = transition.at - elapsed
                guard delay > 0.5 else { continue }
                let content = UNMutableNotificationContent()
                if let starting = transition.starting {
                    content.title = starting.kind == .work ? "GO — \(starting.name)" : starting.name
                    content.body = Self.detailLine(for: starting)
                } else {
                    content.title = "Complete!"
                    content.body = "Workout finished — nice work."
                }
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "pulse-phase-\(Int(transition.at * 10))",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func detailLine(for phase: Phase) -> String {
        if let s = phase.setNumber, phase.totalSets > 1, let r = phase.roundNumber {
            return "Set \(s) of \(phase.totalSets) · Round \(r) of \(phase.totalRounds)"
        }
        if let r = phase.roundNumber, phase.totalRounds > 1 {
            return "Round \(r) of \(phase.totalRounds)"
        }
        return "Interval timer"
    }
}

// MARK: - Runner UI

struct IntervalRunnerView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var session: TimerSession

    @State private var showStopDialog = false
    @State private var logDraft: LogDraft?
    @State private var savedLog = false

    struct LogDraft: Identifiable {
        let id = UUID()
        var minutes: Double
        var notes: String
    }

    init(template: TimerTemplate) {
        _session = StateObject(wrappedValue: TimerSession(template: template))
    }

    private var phaseColor: Color {
        Theme.color(for: session.state.phase.kind)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Spacer()
                ring
                Spacer()
                phaseInfo
                controls
            }
            .padding(20)

            if session.isFinished {
                completionOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            session.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                session.tick()
            }
        }
        .confirmationDialog("End workout?", isPresented: $showStopDialog, titleVisibility: .visible) {
            if session.state.totalElapsed >= 60 {
                Button("End & Log Workout") {
                    logDraft = LogDraft(
                        minutes: session.state.totalElapsed / 60,
                        notes: "\(session.template.name) — \(session.template.summary)"
                    )
                }
            }
            Button("End Without Saving", role: .destructive) {
                session.stop()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        }
        .sheet(item: $logDraft, onDismiss: {
            if savedLog {
                dismiss()
            }
        }) { draft in
            NavigationStack {
                WorkoutFormView(
                    prefill: WorkoutPrefill(minutes: draft.minutes, notes: draft.notes),
                    onSaved: { savedLog = true }
                )
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                showStopDialog = true
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .accessibilityLabel("End workout")

            Spacer()

            VStack(spacing: 2) {
                Text(session.template.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Total elapsed \(Format.mmss(session.state.totalElapsed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 16)
            Circle()
                .trim(from: 0, to: session.state.phaseRemainingFraction)
                .stroke(phaseColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: phaseColor.opacity(0.55), radius: 12)
            VStack(spacing: 6) {
                Text(session.state.phase.name.uppercased())
                    .font(.footnote.weight(.bold))
                    .tracking(2)
                    .foregroundColor(phaseColor)
                Text(Format.countdown(session.state.remainingInPhase))
                    .font(.system(size: 68, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(nextText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 290, height: 290)
    }

    private var nextText: String {
        if let next = session.state.nextPhase {
            return "Next: \(next.name) \(Format.mmss(next.duration))"
        }
        return session.isFinished ? "Done" : "Last segment"
    }

    // MARK: Phase info

    private var phaseInfo: some View {
        VStack(spacing: 10) {
            if let setNumber = session.state.phase.setNumber, session.state.phase.totalSets > 1 {
                Text("Set \(setNumber) of \(session.state.phase.totalSets)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            if let roundNumber = session.state.phase.roundNumber, session.state.phase.totalRounds > 1 {
                Text("Round \(roundNumber) of \(session.state.phase.totalRounds)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            HStack(spacing: 4) {
                let visible = min(30, session.phases.count)
                ForEach(0..<max(1, visible), id: \.self) { i in
                    Capsule()
                        .fill(i <= session.state.phaseIndex && i < session.phases.count
                            ? Theme.color(for: session.phases[i].kind)
                            : Color.white.opacity(0.15))
                        .frame(width: session.phases.count > 18 ? 5 : 10, height: 4)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 36) {
            sideControl(symbol: "backward.end.fill") {
                session.skipBack()
            }
            Button {
                if session.isRunning {
                    session.pause()
                } else {
                    session.resume()
                }
            } label: {
                Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(Theme.accent))
            }
            .accessibilityLabel(session.isRunning ? "Pause" : "Resume")

            sideControl(symbol: "forward.end.fill") {
                session.skipForward()
            }
        }
        .padding(.bottom, 8)
    }

    private func sideControl(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
    }

    // MARK: Completion

    private var completionOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundColor(Theme.accent)
            Text("Workout Complete!")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("\(session.template.name) · \(Format.duration(minutes: session.engine.totalDuration / 60))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                logDraft = LogDraft(
                    minutes: session.engine.totalDuration / 60,
                    notes: "\(session.template.name) — \(session.template.summary)"
                )
            } label: {
                Text("Log This Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)

            Button("Done") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.94).ignoresSafeArea())
    }
}
