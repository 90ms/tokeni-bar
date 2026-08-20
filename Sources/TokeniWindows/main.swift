import Foundation
import TokeniApplication
import TokeniCore

@main
struct TokeniWindowsApp {
    static func main() async {
        let providers = ProviderRegistry.defaultProviders()
        let session = UsageApplicationSession(providers: providers)

        _ = try? await session.bootstrap()
        await session.start()

        // The Win32 tray message loop and presentation surface are introduced in
        // the next layer. Keep the host alive so its refresh lifecycle is already
        // exercised by the Windows executable target.
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(86_400))
        }

        await session.stop()
    }
}
