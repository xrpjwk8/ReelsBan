import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }
    var title: String { self == .korean ? "한국어" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }

    private static var file: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ReelsBanAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("language.json")
    }

    static var current: AppLanguage {
        if let file, let data = try? Data(contentsOf: file),
           let value = try? JSONDecoder().decode(String.self, from: data),
           let language = AppLanguage(rawValue: value) { return language }
        return AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "ko") ?? .korean
    }

    static func save(_ language: AppLanguage) -> Bool {
        guard let file else { return false }
        do {
            try JSONEncoder().encode(language.rawValue).write(to: file, options: .atomic)
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            return true
        } catch { return false }
    }
}

func L(_ korean: String, _ english: String) -> String {
    AppLanguage.current == .english ? english : korean
}
