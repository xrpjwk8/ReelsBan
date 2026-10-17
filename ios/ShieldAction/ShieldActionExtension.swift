import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else { completionHandler(.close); return }
        SharedState.requestJob()
        #if REELSBAN_SDK_SMOKE_TEST
        // Compilation checks on older SDKs only. Never distribute this variant.
        completionHandler(.close)
        #else
        completionHandler(.openParentalControlsApp)
        #endif
    }
}
