import Foundation

public struct DailyBlockRecord: Codable {
    public let revision: String
    public let day: String
    public init(revision: String, day: String) { self.revision = revision; self.day = day }
}

public enum DailyPolicy {
    public static func blockedIDs(enabled: Bool, revision: String, records: [String: DailyBlockRecord], now: Date = Date(), calendar: Calendar = .current) -> Set<String> {
        Set(records.compactMap { id, record in
            shouldShield(enabled: enabled, revision: revision, blockedRevision: record.revision, blockedDay: record.day, now: now, calendar: calendar) ? id : nil
        })
    }
    public static let defaultMinutes = 30
    public static let defaultDestination = URL(string: "https://mcdonalds.recruiter.co.kr/career/jobs/130416")!
    public static func destinationURL(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return defaultDestination }
        guard !text.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        return url
    }
    public static func validMinutes(_ minutes: Int) -> Bool { (1...480).contains(minutes) }
    public static func day(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(c.era ?? 1)-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    public static func shouldShield(enabled: Bool, revision: String, blockedRevision: String?, blockedDay: String?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        enabled && blockedRevision == revision && blockedDay == day(at: now, calendar: calendar)
    }
}
