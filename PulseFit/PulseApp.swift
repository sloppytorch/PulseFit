import SwiftUI
import UserNotifications
import UIKit

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Show notification banner and sound when the app is backgrounded or locked.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if UIApplication.shared.applicationState == .active {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}

@main
struct PulseFitApp: App {
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var templateStore = TemplateStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(workoutStore)
                .environmentObject(templateStore)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                }
        }
    }
}

struct RootTabView: View {
    enum Tab: Hashable {
        case timer, log, stats, settings
    }

    @State private var selectedTab: Tab = .timer

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerHomeView()
                .tabItem { Label("Timer", systemImage: "stopwatch") }
                .tag(Tab.timer)
            WorkoutListView()
                .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle.portrait") }
                .tag(Tab.log)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                .tag(Tab.stats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}
