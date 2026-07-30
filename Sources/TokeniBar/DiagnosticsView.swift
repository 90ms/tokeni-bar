import TokeniCore
import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var store: UsageStore
    @State private var copied = false
    @State private var includeTokenDetails = false

    private var report: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return ProviderDiagnosticReportBuilder.text(
            appName: info["CFBundleName"] as? String ?? "Tokeni Bar",
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            snapshots: self.store.snapshots,
            includeTokenDetails: self.includeTokenDetails)
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
                .accessibilityHint(AppLocalization.string(
                    "diagnostics.report.hint"))

            Toggle(
                AppLocalization.string("diagnostics.includeTokenDetails"),
                isOn: self.$includeTokenDetails)
                .onChange(of: self.includeTokenDetails) { _, _ in
                    self.copied = false
                }

            if self.includeTokenDetails {
                TokeniStatusBanner(
                    text: AppLocalization.string(
                        "diagnostics.tokenDetailsWarning"),
                    kind: .warning)
            }

            HStack {
                Text(AppLocalization.string("diagnostics.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(self.report, forType: .string)
                    self.copied = true
                } label: {
                    Label(
                        AppLocalization.string(
                            self.copied
                                ? "diagnostics.copied"
                                : "diagnostics.copy"),
                        systemImage: self.copied
                            ? "checkmark"
                            : "doc.on.doc")
                }
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 440)
    }
}
