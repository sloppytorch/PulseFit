import SwiftUI
import UserNotifications
import UIKit

@main
struct PulseFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var templateStore = TemplateStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(workoutStore)
                .environmentObject(templateStore)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Suppress notification banners while the app is actively showing its own
    /// cues; show them when backgrounded / locked.
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
