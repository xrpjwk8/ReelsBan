import SwiftUI
import FamilyControls
import SafariServices
import DeviceActivity

struct ContentView: View {
    @StateObject private var model = AppModel()
    @StateObject private var router = JobRouter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var usageRefresh = Date()
    @State private var language = AppLanguage.current
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("reelsban").font(.system(size: 34, weight: .black, design: .rounded))
                    Picker("언어 / Language", selection: $language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("언어 / Language")
                    .onChange(of: language) { _, value in
                        guard AppLanguage.save(value) else {
                            language = AppLanguage.current
                            model.notice = L("언어를 저장하지 못했어요. 앱 그룹 설정을 확인해주세요.", "Couldn't save the language. Check the App Group configuration.")
                            return
                        }
                        model.notice = nil
                        model.nameNotice = nil
                        model.saveConfirmation = nil
                        usageRefresh = Date()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.blocked ? L("오늘의 한도에 도달했어요", "You've reached today's limit") : L("내 하루의 사용 시간", "My daily screen time")).font(.title2.bold())
                        Text(L("선택한 앱의 전체 사용 시간을 기준으로 해요. 인스타그램은 릴스·피드·DM이 모두 포함돼요.", "Usage includes all activity in each selected app. For Instagram, this includes Reels, feed, and DMs."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.authorized ? L("Screen Time 접근 허용 완료", "Screen Time access granted") : L("Screen Time 접근 허용 필요", "Screen Time access required"),
                              systemImage: model.authorized ? "checkmark.circle.fill" : "lock.circle")
                            .font(.headline)
                        Text(model.monitoringActive ? L("저장한 앱 \(model.savedAppCount)개의 개별 시간 제한이 적용 중이에요.", "Individual limits are active for \(model.savedAppCount) saved apps.") : L("앱을 선택하고 저장하면 제한이 시작돼요.", "Select apps and save to start limiting usage."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        if !model.authorized {
                            Button { Task { await model.authorize() } } label: {
                                HStack {
                                    if model.busy { ProgressView().tint(.gray) }
                                    Text(model.busy ? L("권한 승인 확인 중…", "Checking authorization…") : L("Screen Time 접근 허용", "Allow Screen Time access"))
                                }
                            }.buttonStyle(PrimaryStyle()).disabled(model.busy)
                        }
                        Button(L("권한 상태 다시 확인", "Check access again")) { model.refresh() }.font(.footnote)
                        if let notice = model.notice {
                            Text(notice).font(.footnote).accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("나를 부를 이름", "What should we call you?")).font(.headline)
                        TextField(L("이름 또는 별명 (선택)", "Name or nickname (optional)"), text: $model.displayName)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: model.displayName) { _, value in
                                if value.count > 20 { model.displayName = String(value.prefix(20)) }
                            }
                        Text(L("최대 20자 · 오늘의 약속 저장 시 이름도 함께 저장돼요. 비워두면 기본 문구를 사용해요.", "Up to 20 characters. Your name is also saved with your daily limits. Leave blank to use the default message."))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button { model.saveName() } label: {
                            Text(L("이름 저장", "Save name"))
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
                        Toggle(L("하루 사용 시간 제한", "Daily time limits"), isOn: $model.enabled)
                        Button { model.showingAppPicker = true } label: {
                            HStack { Text(L("제한할 앱 선택", "Choose apps to limit")); Spacer(); Text(L("\(model.selection.applicationTokens.count)개", "\(model.selection.applicationTokens.count) apps")); Image(systemName: "chevron.right") }
                        }.disabled(!model.authorized)
                        ForEach($model.limits) { $limit in
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Label(limit.token).labelStyle(.titleAndIcon)
                                if model.authorized {
                                    DeviceActivityReport(.init("reelsban.today.app." + language.rawValue), filter: DeviceActivityFilter(
                                        segment: .daily(during: Calendar.current.dateInterval(of: .day, for: usageRefresh)!),
                                        devices: .init([.iPhone]), applications: [limit.token]
                                    ))
                                    .id(limit.id + language.rawValue + usageRefresh.description)
                                    .frame(height: 66)
                                } else {
                                    Text(L("오늘 사용 시간: Screen Time 접근 허용 필요", "Today's usage: Screen Time access required")).font(.footnote).foregroundStyle(.secondary)
                                }
                                Stepper(value: $limit.minutes, in: 1...480) {
                                    Text(L("하루 \(limit.minutes)분", "\(limit.minutes) min per day"))
                                }
                            }
                        }
                        if model.authorized && !model.limits.isEmpty {
                            Divider()
//                            Button(L("오늘 사용 시간 새로고침", "Refresh today's usage")) { usageRefresh = Date() }
                            Button { usageRefresh = Date() } label: {
                                Text(L("오늘 사용 시간 새로고침", "Refresh today's usage"))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                                    }
                            }.buttonStyle(.plain)
                            Text(L("Screen Time 집계는 반영이 늦을 수 있어요. iPhone 사용 기록 기준이며, 기기 간 공유 설정에 따라 다른 iPhone 기록도 포함될 수 있어요.", "Screen Time updates may be delayed. Usage is based on iPhone activity and may include other iPhones when sharing across devices is enabled."))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(L("여러 앱을 선택하고 각각 한도를 정해주세요. 기본값은 앱마다 30분이며, 사용 시간은 합산하지 않아요. 매일 자정을 기준으로 다시 시작해요.", "Choose multiple apps and set a limit for each. The default is 30 minutes per app. Usage is counted separately and resets at midnight."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(20).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    Button(L("오늘의 약속 저장", "Save daily limits")) { model.save() }.buttonStyle(PrimaryStyle())
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("한도에 도달하면", "When you reach a limit")).font(.headline)
                        Text(L("각자의 한도를 채운 앱만 차단돼요. ‘설정한 사이트 열기’를 누르면 저장한 주소가 열려요. 기본값은 맥도날드 채용 공고예요.", "Only apps that reach their own limit are blocked. Tap ‘Open saved website’ to open your saved address. The default is a McDonald's job listing."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(L("공고 보기 · 이동 사이트 설정", "View website · Website settings")) { router.destination = .settings }.font(.headline)
                    }
                }.padding(24)
            }.background(Color(.systemBackground))
        }
        .environment(\.locale, language.locale)
        .tint(.primary)
        .alert(L("저장 완료", "Saved"), isPresented: Binding(
            get: { model.saveConfirmation != nil },
            set: { if !$0 { model.saveConfirmation = nil } }
        )) {
            Button(L("확인", "OK"), role: .cancel) { model.saveConfirmation = nil }
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
                Text(L("제한할 앱을 여러 개 선택할 수 있어요. 카테고리를 펼쳐 개별 앱을 선택해주세요. 각 앱의 한도는 다음 화면에서 정해요.", "You can select multiple apps. Expand a category to choose individual apps. Set each app's limit on the next screen."))
                    .font(.subheadline).padding(.horizontal)
                FamilyActivityPicker(selection: $selection)
                Text(valid ? L("앱 \(selection.applicationTokens.count)개를 선택했어요. 완료 후 앱별 한도를 저장해주세요.", "\(selection.applicationTokens.count) apps selected. Tap Done, then save your limits.") : L("카테고리·웹사이트를 제외하고 앱을 하나 이상 선택해주세요.", "Select at least one app, without categories or websites."))
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
            .navigationTitle(L("제한할 앱 선택", "Choose apps to limit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("완료", "Done")) { onConfirm(selection); dismiss() }.disabled(!valid)
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
                DisclosureGroup(L("이동할 사이트 설정", "Website settings")) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("https://example.com", text: $address)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.URL).textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L("한도 도달 후 열 사이트 주소", "Website address to open after reaching a limit"))
                        HStack {
                            Button(L("주소 저장", "Save address")) { save(address) }
                            Spacer()
                            Button(L("맥도날드 기본값", "McDonald's default")) { save("") }
                        }
                        Text(L("모든 앱에 공통으로 적용돼요. http:// 또는 https://로 시작하는 주소를 입력해주세요.", "Applies to all selected apps. Enter an address starting with http:// or https://."))
                            .font(.footnote).foregroundStyle(.secondary)
                        if let message { Text(message).font(.footnote) }
                    }.padding(.top, 12)
                }.padding()
                }
                SafariPage(url: displayedURL).id(displayedURL)
            }
//            .navigationTitle(allowsSettings ? L("공고 · 이동 사이트", "Jobs · Website") : L("설정한 사이트", "Saved website"))
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("닫기", "Close")) { dismiss() } } }
        }
    }
    private func save(_ input: String) {
        guard let url = DailyPolicy.destinationURL(input) else {
            message = L("올바른 웹사이트 주소를 입력해주세요. 예: https://example.com", "Enter a valid website address, such as https://example.com.")
            return
        }
        guard SharedState.saveDestination(input) else {
            message = L("주소를 저장하지 못했어요. 앱 그룹 설정을 확인해주세요.", "Couldn't save the address. Check the App Group configuration.")
            return
        }
        address = url.absoluteString
        displayedURL = url
        message = L("저장했어요. 다음부터 이 사이트가 열려요.", "Saved. This website will open next time.")
    }
}
private struct SafariPage: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
