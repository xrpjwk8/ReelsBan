import SwiftUI
import FamilyControls
import DeviceActivity
import Combine

@MainActor final class AppModel: ObservableObject {
    @Published var displayName = SharedState.displayName
    @Published var nameNotice: String?
    @Published var selection: FamilyActivitySelection
    @Published var limits: [AppLimit]
    @Published var enabled: Bool
    @Published var authorized = false
    @Published var blocked = false
    @Published var busy = false
    @Published var notice: String?
    @Published var saveConfirmation: String?
    @Published var showingAppPicker = false
    @Published var monitoringActive = false
    @Published var savedAppCount = 0
    private var authorizationObserver: AnyCancellable?
    private var openPickerAfterAuthorization = false

    init() {
        let config = SharedState.configuration
        selection = config.selection
        limits = config.appLimits
        enabled = config.enabled
        refresh()
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }
    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if !authorized { SharedState.store.clearAllSettings() }
        else { SharedState.reconcileShield() }
        blocked = authorized && SharedState.isBlockedToday
        let config = SharedState.configuration
        monitoringActive = authorized && config.enabled && DeviceActivityCenter().activities.contains(config.activity)
        savedAppCount = config.appLimits.count
        if authorized && openPickerAfterAuthorization && !busy {
            openPickerAfterAuthorization = false
            notice = "Screen Time 접근이 허용됐어요. 제한할 앱을 선택해주세요."
            showingAppPicker = true
        }
    }
    func authorize() async {
        guard !busy else { return }
        if authorized { showingAppPicker = true; return }
        busy = true
        notice = nil
        openPickerAfterAuthorization = true
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            openPickerAfterAuthorization = false
            if let familyError = error as? FamilyControlsError, familyError == .authenticationMethodUnavailable {
                notice = "아이폰 잠금 암호를 먼저 설정해주세요.\n설정 → Face ID 및 암호(또는 Touch ID 및 암호) → 암호 켜기\n암호 설정 후 ‘Screen Time 접근 허용’을 다시 눌러주세요. 잠금 암호 없이 앱 사용 시간 제한은 이용할 수 없어요."
            } else {
                notice = "권한 승인이 완료되지 않았어요. 다시 시도해주세요. \(error.localizedDescription)"
            }
        }
        busy = false
        refresh()
        if !authorized && notice == nil {
            notice = "아직 접근 허용이 확인되지 않았어요. 상태 확인을 누르거나 다시 허용해주세요."
        }
    }
    func choose(_ newSelection: FamilyActivitySelection) {
        let previous = limits
        limits = newSelection.applicationTokens.map { token in
            previous.first(where: { $0.token == token }) ?? AppLimit(token: token)
        }.sorted { $0.id < $1.id }
        selection = newSelection
        enabled = !limits.isEmpty
        notice = "앱을 선택했어요. 한도를 정하고 ‘오늘의 약속 저장’을 눌러 적용해주세요."
    }
    func saveName() {
        guard SharedState.saveDisplayName(displayName) else {
            nameNotice = "이름을 저장하지 못했어요. 앱 그룹 설정을 확인해주세요."
            return
        }
        displayName = SharedState.displayName
        nameNotice = displayName.isEmpty ? "이름을 지웠어요. 기본 문구를 사용해요." : "저장했어요. 다음 한도 안내 화면에 이름이 표시돼요."
    }
    func save() {
        saveConfirmation = nil
        guard SharedState.defaults != nil else { notice = "앱 그룹 설정을 확인해주세요. 모든 타깃에 같은 App Group과 개발 팀이 필요해요."; return }
        guard SharedState.saveDisplayName(displayName) else {
            notice = "이름을 저장하지 못했어요. 다시 시도해주세요."
            return
        }
        displayName = SharedState.displayName
        let old = SharedState.configuration
        if !enabled {
            var disabled = old
            disabled.enabled = false
            disabled.selection = selection
            disabled.limits = limits
            SharedState.configuration = disabled
            DeviceActivityCenter().stopMonitoring([old.activity])
            SharedState.store.clearAllSettings()
            refresh()
            notice = "사용 시간 제한을 껐어요."
            saveConfirmation = "설정을 저장하고 사용 시간 제한을 껐어요."
            return
        }
        guard authorized else { notice = "먼저 Screen Time 접근을 허용해주세요."; return }
        var config = LimitConfiguration()
        config.selection = selection
        config.limits = limits
        config.enabled = true
        guard config.isValid else { notice = "제한할 앱을 하나 이상 선택해주세요. 카테고리와 웹사이트는 선택하지 마세요."; return }
        let center = DeviceActivityCenter()
        if old.enabled && old.appLimits == limits && old.selection == selection && center.activities.contains(old.activity) {
            notice = "오늘의 약속을 저장했어요."
            saveConfirmation = "앱별 하루 한도 설정을 저장했어요."
            refresh()
            return
        }
        SharedState.preserveUnchangedBlocks(from: old, to: config)
        // Publish before registration: the extension may be called immediately.
        SharedState.configuration = config
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        let events = Dictionary(uniqueKeysWithValues: limits.map { limit in
            (limit.event, DeviceActivityEvent(applications: [limit.token], threshold: DateComponents(minute: limit.minutes), includesPastActivity: true))
        })
        do {
            try center.startMonitoring(config.activity, during: schedule, events: events)
            center.stopMonitoring([old.activity])
            SharedState.removeBlocks(for: old)
            SharedState.reconcileShield()
            notice = "오늘의 약속을 저장했어요. 오늘 이미 사용한 시간도 포함해요."
            saveConfirmation = "앱별 하루 한도 설정을 저장했어요. 오늘 이미 사용한 시간도 포함해요."
        } catch {
            SharedState.configuration = old
            SharedState.removeBlocks(for: config)
            center.stopMonitoring([config.activity])
            SharedState.reconcileShield()
            notice = "설정을 적용하지 못했어요. 이전 설정을 유지합니다. \(error.localizedDescription)"
        }
        refresh()
    }
}
