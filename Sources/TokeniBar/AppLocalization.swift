import TokeniCore
import Foundation

enum AppLocalization {
    static func string(_ key: String, value: String? = nil) -> String {
        self.bundle.localizedString(forKey: key, value: value, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: self.string(key),
            locale: Locale.current,
            arguments: arguments)
    }

    static func sourceName(_ source: UsageDataSource) -> String {
        self.string("source.\(source.rawValue)", value: source.displayName)
    }

    private static var bundle: Bundle {
        guard let code = AppLanguage.savedValue.localizationCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}
