import XCTest
@testable import ReelsBanPolicy

final class DailyPolicyTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testLocalMidnightClearsBlock() {
        let before = date("2026-10-10T14:59:59Z")
        let after = date("2026-10-10T15:00:00Z")
        let day = DailyPolicy.day(at: before, calendar: calendar)
        XCTAssertTrue(DailyPolicy.shouldShield(enabled: true, revision: "a", blockedRevision: "a", blockedDay: day, now: before, calendar: calendar))
        XCTAssertFalse(DailyPolicy.shouldShield(enabled: true, revision: "a", blockedRevision: "a", blockedDay: day, now: after, calendar: calendar))
    }
    func testDisabledAndOldRegistrationCannotBlock() {
        let now = Date()
        let day = DailyPolicy.day(at: now)
        XCTAssertFalse(DailyPolicy.shouldShield(enabled: false, revision: "a", blockedRevision: "a", blockedDay: day, now: now))
        XCTAssertFalse(DailyPolicy.shouldShield(enabled: true, revision: "new", blockedRevision: "old", blockedDay: day, now: now))
        XCTAssertFalse(DailyPolicy.shouldShield(enabled: true, revision: "a", blockedRevision: nil, blockedDay: nil, now: now))
    }
    func testRepeatedStartSameDayKeepsBlock() {
        let now = Date()
        XCTAssertTrue(DailyPolicy.shouldShield(enabled: true, revision: "a", blockedRevision: "a", blockedDay: DailyPolicy.day(at: now), now: now))
    }
    func testDestinationValidation() {
        XCTAssertEqual(DailyPolicy.destinationURL("  "), DailyPolicy.defaultDestination)
        XCTAssertEqual(DailyPolicy.destinationURL(" https://example.com/path?q=1 ")?.absoluteString, "https://example.com/path?q=1")
        XCTAssertNotNil(DailyPolicy.destinationURL("http://example.com"))
        for invalid in ["javascript:alert(1)", "file:///tmp/test", "example.com", "https://", "https://user:password@example.com", "https://exa mple.com"] {
            XCTAssertNil(DailyPolicy.destinationURL(invalid), invalid)
        }
    }
    func testIndependentAppBlocksAndReset() {
        let now = date("2026-10-10T14:59:59Z")
        let day = DailyPolicy.day(at: now, calendar: calendar)
        var records = ["instagram": DailyBlockRecord(revision: "session", day: day)]
        XCTAssertEqual(DailyPolicy.blockedIDs(enabled: true, revision: "session", records: records, now: now, calendar: calendar), ["instagram"])
        records["youtube"] = DailyBlockRecord(revision: "session", day: day)
        records["tiktok"] = DailyBlockRecord(revision: "old-session", day: day)
        XCTAssertEqual(DailyPolicy.blockedIDs(enabled: true, revision: "session", records: records, now: now, calendar: calendar), ["instagram", "youtube"])
        XCTAssertTrue(DailyPolicy.blockedIDs(enabled: false, revision: "session", records: records, now: now, calendar: calendar).isEmpty)
        XCTAssertTrue(DailyPolicy.blockedIDs(enabled: true, revision: "session", records: records, now: date("2026-10-10T15:00:00Z"), calendar: calendar).isEmpty)
    }
    func testLimitBoundaries() {
        XCTAssertEqual(DailyPolicy.defaultMinutes, 30)
        XCTAssertFalse(DailyPolicy.validMinutes(0))
        XCTAssertTrue(DailyPolicy.validMinutes(1))
        XCTAssertTrue(DailyPolicy.validMinutes(480))
        XCTAssertFalse(DailyPolicy.validMinutes(481))
    }
}
