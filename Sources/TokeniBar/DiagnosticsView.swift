import TokeniCore
import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var store: UsageStore
    @State private var copied = false

    private var report: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return ProviderDiagnosticReportBuilder.text(
            appName: info["CFBundleName"] as? String ?? "Tokeni Bar",
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            snapshots: self.store.snapshots)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalization.string("diagnostics.description"))
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: .constant(self.report))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .accessibilityLabel(AppLocalization.string("diagnostics.report"))

            HStack {
                Text(AppLocalization.string("diagnostics.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(self.copied
                    ? AppLocalization.string("diagnostics.copied")
                    : AppLocalization.string("diagnostics.copy"))
                {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(self.report, forType: .string)
                    self.copied = true
                }
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 440)
    }
}
