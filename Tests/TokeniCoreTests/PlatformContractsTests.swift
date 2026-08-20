@testable import TokeniCore
import Foundation
import Testing

struct PlatformContractsTests {
    @Test
    func applicationDirectoriesPreserveEachPlatformRoot() {
        let directories = ApplicationDirectories(
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
            applicationSupportDirectory: URL(fileURLWithPath: "/Users/example/Library/Application Support"),
            cachesDirectory: URL(fileURLWithPath: "/Users/example/Library/Caches"),
            localApplicationSupportDirectory: URL(fileURLWithPath: "/Users/example/Library/Application Support"))

        #expect(directories.homeDirectory.path == "/Users/example")
        #expect(directories.applicationSupportDirectory.path.hasSuffix("Application Support"))
        #expect(directories.cachesDirectory.path.hasSuffix("Caches"))
        #expect(directories.localApplicationSupportDirectory == directories.applicationSupportDirectory)
    }

    @Test
    func appNotificationIsStableAcrossDeliveryImplementations() {
        let notification = AppNotification(
            id: "provider-low-claude",
            title: "Usage warning",
            body: "The remaining quota is low.")

        #expect(notification.id == "provider-low-claude")
        #expect(notification.title == "Usage warning")
        #expect(notification.body == "The remaining quota is low.")
    }
}
