import Foundation

#if REELSBAN_SDK_SMOKE_TEST && !DEBUG
#error("REELSBAN_SDK_SMOKE_TEST is only for Debug compilation checks; do not distribute.")
#endif
import FamilyControls
import ManagedSettings
import DeviceActivity
import CryptoKit

struct AppLimit: Codable, Identifiable, Equatable {
    var id: String
    var token: ApplicationToken
    var minutes: Int
    init(token: ApplicationToken, minutes: Int = DailyPolicy.defaultMinutes) {
        self.token = token
        self.minutes = minutes
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        self.id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    var event: DeviceActivityEvent.Name { .init(id) }
}

struct LimitConfiguration: Codable {
    var revision = UUID().uuidString
    // Retain legacy fields to migrate existing single-app installations.
    var selection = FamilyActivitySelection()
    var minutes = DailyPolicy.defaultMinutes
    var enabled = false
    var limits: [AppLimit]?
    var appLimits: [AppLimit] {
        limits ?? selection.applicationTokens.map { AppLimit(token: $0, minutes: minutes) }.sorted { $0.id < $1.id }
    }
    var activity: DeviceActivityName { DeviceActivityName("reelsban.daily." + revision) }
    var isValid: Bool {
        let apps = appLimits
        return !apps.isEmpty && apps.allSatisfy { DailyPolicy.validMinutes($0.minutes) }
            && Set(apps.map(\.token)).count == apps.count
            && Set(apps.map(\.id)).count == apps.count
            && Set(apps.map(\.token)) == selection.applicationTokens
            && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
}

typealias BlockRecord = DailyBlockRecord

enum SharedState {
    static let store = ManagedSettingsStore(named: .init("reelsban"))
    static var displayName: String { defaults?.string(forKey: "displayName") ?? "" }
    static func normalizedName(_ text: String) -> String {
        String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(20))
    }
    static func limitTitle(for name: String) -> String {
        let name = normalizedName(name)
        return name.isEmpty ? "오늘의 약속을 지켰어요" : "\(name)님, 오늘의 한도에 도달했어요"
    }
    static func saveDisplayName(_ text: String) -> Bool {
        guard let defaults else { return false }
        defaults.set(normalizedName(text), forKey: "displayName")
        return true
    }
    static var jobURL: URL {
        DailyPolicy.destinationURL(defaults?.string(forKey: "destinationURL") ?? "") ?? DailyPolicy.defaultDestination
    }
    static func saveDestination(_ text: String) -> Bool {
        guard let defaults, let url = DailyPolicy.destinationURL(text) else { return false }
        defaults.set(url.absoluteString, forKey: "destinationURL")
        return true
    }
    static var defaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ReelsBanAppGroup") as? String,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
        return UserDefaults(suiteName: group)
    }
    static var configuration: LimitConfiguration {
        get { read(LimitConfiguration.self, key: "configuration") ?? LimitConfiguration() }
        set { save(newValue, key: "configuration") }
    }
    private static func blockKey(_ config: LimitConfiguration, _ limit: AppLimit) -> String {
        "blocked." + config.revision + "." + limit.id
    }
    static func isBlocked(_ limit: AppLimit, in config: LimitConfiguration) -> Bool {
        let record: BlockRecord? = config.limits == nil
            ? read(BlockRecord.self, key: "blocked")
            : read(BlockRecord.self, key: blockKey(config, limit))
        return DailyPolicy.shouldShield(enabled: config.enabled, revision: config.revision, blockedRevision: record?.revision, blockedDay: record?.day)
    }
    static func markBlocked(_ limit: AppLimit, in config: LimitConfiguration) {
        let record = BlockRecord(revision: config.revision, day: DailyPolicy.day())
        // Each event writes its own key so simultaneous thresholds cannot overwrite each other.
        save(record, key: config.limits == nil ? "blocked" : blockKey(config, limit))
    }
    static func preserveUnchangedBlocks(from old: LimitConfiguration, to new: LimitConfiguration) {
        for limit in new.appLimits where old.appLimits.contains(limit) && isBlocked(limit, in: old) {
            markBlocked(limit, in: new)
        }
    }
    static func removeBlocks(for config: LimitConfiguration) {
        for limit in config.appLimits { defaults?.removeObject(forKey: blockKey(config, limit)) }
        if config.limits == nil { defaults?.removeObject(forKey: "blocked") }
    }
    private static func blockedIDs(in config: LimitConfiguration) -> Set<String> {
        var records: [String: DailyBlockRecord] = [:]
        for limit in config.appLimits {
            records[limit.id] = read(BlockRecord.self, key: config.limits == nil ? "blocked" : blockKey(config, limit))
        }
        return DailyPolicy.blockedIDs(enabled: config.enabled, revision: config.revision, records: records)
    }
    static var isBlockedToday: Bool { !blockedIDs(in: configuration).isEmpty }
    static func reconcileShield() {
        let config = configuration
        let ids = blockedIDs(in: config)
        let tokens = Set(config.appLimits.filter { ids.contains($0.id) }.map(\.token))
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }
    static func requestJob() {
        defaults?.set(Date().timeIntervalSince1970, forKey: "jobRequestedAt")
    }
    static func consumeJobRequest(now: Date = Date()) -> Bool {
        guard let defaults, let timestamp = defaults.object(forKey: "jobRequestedAt") as? Double else { return false }
        defaults.removeObject(forKey: "jobRequestedAt")
        let elapsed = now.timeIntervalSince1970 - timestamp
        return elapsed >= 0 && elapsed < 120
    }
    private static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults?.set(data, forKey: key)
    }
}
