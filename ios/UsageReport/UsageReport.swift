import SwiftUI
import DeviceActivity

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayAppReport { configuration in TodayUsageView(configuration: configuration) }
    }
}

struct UsageConfiguration {
    var seconds: TimeInterval = 0
    var lastUpdated: Date?
}

struct TodayAppReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("reelsban.today.app")
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
    private var duration: String {
        let seconds = max(0, Int(configuration.seconds))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)시간 \(minutes)분" }
        if seconds > 0 && minutes == 0 { return "1분 미만" }
        return "\(minutes)분"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configuration.lastUpdated == nil ? "오늘 사용 시간: 기록 없음" : "오늘 사용 시간: \(duration)")
                .font(.subheadline.weight(.semibold))
            if let updated = configuration.lastUpdated {
                Text("집계 갱신 \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("사용 후 새로고침해주세요.").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
