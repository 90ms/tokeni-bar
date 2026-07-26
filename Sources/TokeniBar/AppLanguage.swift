import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case korean = "ko"

    static let defaultsKey = "appLanguage"

    var id: String { self.rawValue }

    var localizationCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .korean: "ko"
        }
    }

    static var savedValue: Self {
        UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(Self.init(rawValue:)) ?? .system
    }
}
