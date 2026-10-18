import SwiftUI
import FamilyControls
import SafariServices
import DeviceActivity

struct ContentView: View {
    @StateObject private var model = AppModel()
    @StateObject private var router = JobRouter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var usageRefresh = Date()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("reelsban").font(.system(size: 34, weight: .black, design: .rounded))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.blocked ? "오늘의 한도에 도달했어요" : "내 하루의 사용 시간").font(.title2.bold())
                        Text("선택한 앱의 전체 사용 시간을 기준으로 해요. 인스타그램은 릴스·피드·DM이 모두 포함돼요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.authorized ? "Screen Time 접근 허용 완료" : "Screen Time 접근 허용 필요",
                              systemImage: model.authorized ? "checkmark.circle.fill" : "lock.circle")
                            .font(.headline)
                        Text(model.monitoringActive ? "저장한 앱 \(model.savedAppCount)개의 개별 시간 제한이 적용 중이에요." : "앱을 선택하고 저장하면 제한이 시작돼요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if !model.authorized {
                            Button { Task { await model.authorize() } } label: {
                                HStack {
                                    if model.busy { ProgressView().tint(.gray) }
                                    Text(model.busy ? "권한 승인 확인 중…" : "Screen Time 접근 허용")
                                }
                            }.buttonStyle(PrimaryStyle()).disabled(model.busy)
                        }
                        Button("권한 상태 다시 확인") { model.refresh() }.font(.footnote)
                        if let notice = model.notice {
                            Text(notice).font(.footnote).accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("나를 부를 이름").font(.headline)
                        TextField("이름 또는 별명 (선택)", text: $model.displayName)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: model.displayName) { _, value in
                                if value.count > 20 { model.displayName = String(value.prefix(20)) }
                            }
                        Text("최대 20자 · 오늘의 약속 저장 시 이름도 함께 저장돼요. 비워두면 기본 문구를 사용해요.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button { model.saveName() } label: {
                            Text("이름 저장")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                                }
                        }.buttonStyle(.plain)
                        if let notice = model.nameNotice { Text(notice).font(.footnote) }
                    }.padding(20).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 20) {
                        Toggle("하루 사용 시간 제한", isOn: $model.enabled)
                        Button { model.showingAppPicker = true } label: {
                            HStack { Text("제한할 앱 선택"); Spacer(); Text("\(model.selection.applicationTokens.count)개"); Image(systemName: "chevron.right") }
                        }.disabled(!model.authorized)
                        ForEach($model.limits) { $limit in
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Label(limit.token).labelStyle(.titleAndIcon)
                                if model.authorized {
                                    DeviceActivityReport(.init("reelsban.today.app"), filter: DeviceActivityFilter(
                                        segment: .daily(during: Calendar.current.dateInterval(of: .day, for: usageRefresh)!),
                                        devices: .init([.iPhone]), applications: [limit.token]
                                    ))
                                    .id(limit.id + usageRefresh.description)
                                    .frame(height: 66)
                                } else {
                                    Text("오늘 사용 시간: Screen Time 접근 허용 필요").font(.footnote).foregroundStyle(.secondary)
                                }
                                Stepper(value: $limit.minutes, in: 1...480) {
                                    Text("하루 **\(limit.minutes)분**")
                                }
                            }
                        }
                        if model.authorized && !model.limits.isEmpty {
                            Divider()
//                            Button("오늘 사용 시간 새로고침") { usageRefresh = Date() }
                            Button { usageRefresh = Date() } label: {
                                Text("오늘 사용 시간 새로고침")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                                    }
                            }.buttonStyle(.plain)
                            Text("Screen Time 집계는 반영이 늦을 수 있어요. iPhone 사용 기록 기준이며, 기기 간 공유 설정에 따라 다른 iPhone 기록도 포함될 수 있어요.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("여러 앱을 선택하고 각각 한도를 정해주세요. 기본값은 앱마다 30분이며, 사용 시간은 합산하지 않아요. 매일 자정을 기준으로 다시 시작해요.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(20).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    Button("오늘의 약속 저장") { model.save() }.buttonStyle(PrimaryStyle())
                    VStack(alignment: .leading, spacing: 12) {
                        Text("한도에 도달하면").font(.headline)
                        Text("각자의 한도를 채운 앱만 차단돼요. ‘설정한 사이트 열기’를 누르면 저장한 주소가 열려요. 기본값은 맥도날드 채용 공고예요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("공고 보기 · 이동 사이트 설정") { router.destination = .settings }.font(.headline)
                    }
                }.padding(24)
            }.background(Color(.systemBackground))
        }
        .tint(.primary)
        .alert("저장 완료", isPresented: Binding(
            get: { model.saveConfirmation != nil },
            set: { if !$0 { model.saveConfirmation = nil } }
        )) {
            Button("확인", role: .cancel) { model.saveConfirmation = nil }
        } message: {
            Text(model.saveConfirmation ?? "")
        }
        .sheet(isPresented: $model.showingAppPicker) {
            AppSelectionView(selection: model.selection) { model.choose($0) }
        }
        .sheet(item: $router.destination) { destination in
            JobPage(allowsSettings: destination == .settings)
        }
        .onAppear { router.consumeRequest() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            usageRefresh = Date()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh(); router.consumeRequest(); usageRefresh = Date() }
        }
    }
}

private struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var selection: FamilyActivitySelection
    let onConfirm: (FamilyActivitySelection) -> Void
    private var valid: Bool {
        !selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("제한할 앱을 여러 개 선택할 수 있어요. 카테고리를 펼쳐 개별 앱을 선택해주세요. 각 앱의 한도는 다음 화면에서 정해요.")
                    .font(.subheadline).padding(.horizontal)
                FamilyActivityPicker(selection: $selection)
                Text(valid ? "앱 \(selection.applicationTokens.count)개를 선택했어요. 완료 후 앱별 한도를 저장해주세요." : "카테고리·웹사이트를 제외하고 앱을 하나 이상 선택해주세요.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
            .navigationTitle("제한할 앱 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onConfirm(selection); dismiss() }.disabled(!valid)
                }
            }
        }
    }
}

private struct PrimaryStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(scheme == .dark ? Color.black : .white)
            .background(scheme == .dark ? Color.white : .black, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
private struct JobPage: View {
    let allowsSettings: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var address = SharedState.jobURL.absoluteString
    @State private var displayedURL = SharedState.jobURL
    @State private var message: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if allowsSettings {
                DisclosureGroup("이동할 사이트 설정") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("https://example.com", text: $address)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.URL).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("한도 도달 후 열 사이트 주소")
                        HStack {
                            Button("주소 저장") { save(address) }
                            Spacer()
                            Button("맥도날드 기본값") { save("") }
                        }
                        Text("모든 앱에 공통으로 적용돼요. http:// 또는 https://로 시작하는 주소를 입력해주세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let message { Text(message).font(.footnote) }
                    }.padding(.top, 12)
                }.padding()
                }
                SafariPage(url: displayedURL).id(displayedURL)
            }
//            .navigationTitle(allowsSettings ? "공고 · 이동 사이트" : "설정한 사이트")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
    private func save(_ input: String) {
        guard let url = DailyPolicy.destinationURL(input) else {
            message = "올바른 웹사이트 주소를 입력해주세요. 예: https://example.com"
            return
        }
        guard SharedState.saveDestination(input) else {
            message = "주소를 저장하지 못했어요. 앱 그룹 설정을 확인해주세요."
            return
        }
        address = url.absoluteString
        displayedURL = url
        message = "저장했어요. 다음부터 이 사이트가 열려요."
    }
}
private struct SafariPage: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
