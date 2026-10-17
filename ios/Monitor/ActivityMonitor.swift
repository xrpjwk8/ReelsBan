import DeviceActivity
import ManagedSettings

final class ActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == SharedState.configuration.activity else { return }
        // Re-registration can invoke this within the same day; retain today's block.
        SharedState.reconcileShield()

    }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let config = SharedState.configuration
        guard config.enabled, config.isValid, config.activity == activity, (config.appLimits.contains { $0.event == event } || (config.limits == nil && event.rawValue == "daily-limit")) else { return }
        guard let limit = config.appLimits.first(where: { $0.event == event }) ?? (config.limits == nil ? config.appLimits.first : nil) else { return }
        SharedState.markBlocked(limit, in: config)
        SharedState.reconcileShield()
    }
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == SharedState.configuration.activity else { return }
        SharedState.store.clearAllSettings()
    }
}
