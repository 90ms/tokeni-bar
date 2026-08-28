import Foundation
import Testing
import TokeniCore
@testable import TokeniBar

@MainActor
struct CaffeineControllerTests {
    @Test("Caffeine owns exactly one sleep-prevention activity")
    func togglesOneActivity() {
        let preventer = TestSleepPreventer()
        let controller = CaffeineController(
            sleepPreventer: preventer,
            settings: TestSettingsStore())

        controller.setEnabled(true)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(preventer.beginValues == [false])

        controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(preventer.endCount == 1)
    }

    @Test("Changing the display option replaces the active activity")
    func replacesActiveActivityForDisplaySleep() {
        let preventer = TestSleepPreventer()
        let settings = TestSettingsStore()
        let controller = CaffeineController(
            sleepPreventer: preventer,
            settings: settings)

        controller.setEnabled(true)
        controller.setPreventsDisplaySleep(true)

        #expect(controller.isEnabled)
        #expect(controller.preventsDisplaySleep)
        #expect(preventer.beginValues == [false, true])
        #expect(preventer.endCount == 1)
        #expect(settings.bool(forKey: "caffeinePreventsDisplaySleep"))
    }
}

@MainActor
private final class TestSleepPreventer: SleepPreventing {
    private final class Token: NSObject {}
    var beginValues: [Bool] = []
    var endCount = 0

    func begin(preventsDisplaySleep: Bool) -> NSObjectProtocol {
        self.beginValues.append(preventsDisplaySleep)
        return Token()
    }

    func end(_ activity: NSObjectProtocol) {
        self.endCount += 1
    }
}

private final class TestSettingsStore: SettingsStoring, @unchecked Sendable {
    private var values: [String: Any] = [:]

    func containsValue(forKey key: String) -> Bool { self.values[key] != nil }
    func bool(forKey key: String) -> Bool { self.values[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { self.values[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { self.values[key] as? Double ?? 0 }
    func string(forKey key: String) -> String? { self.values[key] as? String }
    func stringArray(forKey key: String) -> [String]? {
        self.values[key] as? [String]
    }
    func date(forKey key: String) -> Date? { self.values[key] as? Date }
    func set(_ value: Bool, forKey key: String) { self.values[key] = value }
    func set(_ value: Int, forKey key: String) { self.values[key] = value }
    func set(_ value: Double, forKey key: String) { self.values[key] = value }
    func set(_ value: String, forKey key: String) { self.values[key] = value }
    func set(_ value: [String], forKey key: String) { self.values[key] = value }
    func set(_ value: Date, forKey key: String) { self.values[key] = value }
    func removeValue(forKey key: String) { self.values[key] = nil }
}
