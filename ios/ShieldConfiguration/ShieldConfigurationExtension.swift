import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let minutes = SharedState.configuration.appLimits.first { $0.token == application.token }?.minutes ?? DailyPolicy.defaultMinutes
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialLight,
            backgroundColor: .white,
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: SharedState.limitTitle(for: SharedState.displayName), color: .black),
            subtitle: .init(text: L("하루 \(minutes)분 한도에 도달했어요.\n설정한 사이트를 확인하고 다음 할 일을 시작해볼까요?\n다음 날 다시 이용할 수 있어요.", "You've reached your daily limit of \(minutes) minutes.\nVisit your saved website and move on to your next task.\nYou can use this app again tomorrow."), color: .darkGray),
            primaryButtonLabel: .init(text: L("설정한 사이트 열기", "Open saved website"), color: .white),
            primaryButtonBackgroundColor: .black,
            secondaryButtonLabel: .init(text: L("닫기", "Close"), color: .darkGray)
        )
    }
}
