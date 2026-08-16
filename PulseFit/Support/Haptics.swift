import UIKit

/// Haptic feedback helpers, gated by the Settings toggle.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard SettingsKeys.defaultedBool(.hapticsEnabled) else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        guard SettingsKeys.defaultedBool(.hapticsEnabled) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
