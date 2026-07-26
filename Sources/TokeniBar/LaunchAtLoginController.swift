import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var isEnabled: Bool {
        self.service.status == .enabled || self.service.status == .requiresApproval
    }

    var statusMessage: String? {
        self.service.status == .requiresApproval
            ? AppLocalization.string("settings.launchAtLogin.approval")
            : nil
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !self.isEnabled else { return }
            try self.service.register()
        } else {
            guard self.isEnabled else { return }
            try self.service.unregister()
        }
    }
}
