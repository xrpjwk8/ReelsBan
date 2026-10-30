import SwiftUI
import DeviceActivity
import ExtensionKit

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayAppReport(english: false) { configuration in TodayUsageView(configuration: configuration, english: false) }
        TodayAppReport(english: true) { configuration in TodayUsageView(configuration: configuration, english: true) }
    }
}

struct UsageConfiguration {
    var seconds: TimeInterval = 0
    var lastUpdated: Date?
}

struct TodayAppReport: DeviceActivityReportScene {
    let english: Bool
    var context: DeviceActivityReport.Context { .init("reelsban.today.app." + (english ? "en" : "ko")) }
    let content: (UsageConfiguration) -> TodayUsageView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageConfiguration {
        var result = UsageConfiguration()
        // Each host report filters to a single application token and today's interval.
        for await device in data {
            result.lastUpdated = max(result.lastUpdated ?? .distantPast, device.lastUpdatedDate)
            for await segment in device.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        result.seconds += app.totalActivityDuration
                    }
                }
            }
        }
        return result
    }
}

struct TodayUsageView: View {
    let configuration: UsageConfiguration
    let english: Bool
    private func text(_ korean: String, _ translated: String) -> String { english ? translated : korean }
    private var duration: String {
        let seconds = max(0, Int(configuration.seconds))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return text("\(hours)시간 \(minutes)분", "\(hours)h \(minutes)m") }
        if seconds > 0 && minutes == 0 { return text("1분 미만", "Less than 1 min") }
        return text("\(minutes)분", "\(minutes) min")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configuration.lastUpdated == nil ? text("오늘 사용 시간: 기록 없음", "Today: No usage data") : text("오늘 사용 시간: \(duration)", "Today: \(duration)"))
                .font(.subheadline.weight(.semibold))
            if let updated = configuration.lastUpdated {
                Text(text("집계 갱신 \(updated.formatted(date: .omitted, time: .shortened))", "Updated \(updated.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: english ? "en" : "ko"))))"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(text("사용 후 새로고침해주세요.", "Refresh after using the app.")).font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
