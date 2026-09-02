import Foundation

enum PackagedApplicationSmokeTest {
    static let argument = "--smoke-test"
    static let successMarker = "TOKENI_MACOS_PACKAGE_SMOKE_OK"

    static func run() -> Int32 {
        let bundle = Bundle.main
        guard bundle.bundleURL.pathExtension == "app" else {
            return self.fail("not-app-bundle")
        }
        guard bundle.bundleIdentifier == "dev.agentsstatusbar.app" else {
            return self.fail("bundle-identifier")
        }
        guard self.hasNonemptyBundleValue("CFBundleShortVersionString", in: bundle),
              self.hasNonemptyBundleValue("CFBundleVersion", in: bundle)
        else {
            return self.fail("bundle-version")
        }
        guard let resources = bundle.resourceURL else {
            return self.fail("resource-root")
        }

        let requiredResources = [
            "AppIcon.icns",
            "TokeniBar_TokeniCore.bundle",
            "TokeniBar_TokeniBar.bundle",
            "BrandIcons/openai.svg",
            "CompanionAssets/bytebot/manifest.json",
        ]
        guard requiredResources.allSatisfy({ self.exists($0, below: resources) }) else {
            return self.fail("packaged-resources")
        }

        for language in ["en", "ko"] {
            guard let localizationPath = bundle.path(forResource: language, ofType: "lproj"),
                  let localizationBundle = Bundle(path: localizationPath),
                  localizationBundle.localizedString(
                      forKey: "main.title",
                      value: nil,
                      table: nil) != "main.title"
            else {
                return self.fail("localization-(language)")
            }
        }

        let companionRoot = resources
            .appendingPathComponent("CompanionAssets", isDirectory: true)
            .appendingPathComponent("bytebot", isDirectory: true)
        guard self.validateCompanionManifest(at: companionRoot) else {
            return self.fail("companion-manifest")
        }

        print(self.successMarker)
        return 0
    }

    private static func hasNonemptyBundleValue(_ key: String, in bundle: Bundle) -> Bool {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return false
        }
        return !value.isEmpty
    }

    private static func exists(_ relativePath: String, below root: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: root.appendingPathComponent(relativePath).path)
    }

    private static func validateCompanionManifest(at root: URL) -> Bool {
        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let manifest = object as? [String: Any],
              manifest["schemaVersion"] as? Int == 2,
              manifest["id"] as? String == "bytebot",
              let forms = manifest["forms"] as? [String: String]
        else {
            return false
        }

        let requiredForms = [
            "egg.normal",
            "hatchling.normal",
            "hatchling.legendary",
            "junior.normal",
            "junior.legendary",
            "adult.normal",
            "adult.legendary",
        ]
        return requiredForms.allSatisfy { form in
            guard let filename = forms[form] else { return false }
            return self.exists(filename, below: root)
        }
    }

    private static func fail(_ reason: String) -> Int32 {
        let message = "TOKENI_MACOS_PACKAGE_SMOKE_FAILED:\(reason)\n"
        FileHandle.standardError.write(Data(message.utf8))
        return 1
    }
}
