import Foundation
import SwiftUI
import TokeniCore
import UniformTypeIdentifiers

private struct CompanionPackFeedback: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
}

private struct CompanionPackImportRequest: Identifiable {
    let id = UUID()
    let archiveURL: URL
}

private struct CompanionPackRemovalRequest: Identifiable {
    let installation: CodexPetPackInstallation

    var id: String { self.installation.metadata.packID.rawValue }
}

@MainActor
private final class CompanionPackManager: ObservableObject {
    @Published private(set) var installedPacks: [CodexPetPackInstallation]
    @Published private(set) var isInstalling = false
    @Published var feedback: CompanionPackFeedback?

    private let store: InstalledCompanionAssetPackStore
    private let installer: CodexPetPackInstaller

    init(installationRoot: URL = InstalledCompanionAssetPackStore
        .defaultInstallationRoot())
    {
        let store = InstalledCompanionAssetPackStore(
            installationRoot: installationRoot)
        self.store = store
        self.installer = .live(installationRoot: installationRoot)
        self.installedPacks = store.installedPacks()
    }

    func install(
        archiveURL: URL,
        provenance: CompanionAssetPackProvenance) async
    {
        guard !self.isInstalling else { return }
        self.isInstalling = true
        defer { self.isInstalling = false }
        let hasSecurityScope = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try await self.installer.install(
                archiveURL: archiveURL,
                provenance: provenance)
            self.reload()
            self.feedback = CompanionPackFeedback(
                titleKey: "companion.packs.import.success.title",
                messageKey: "companion.packs.import.success.message")
        } catch let error as CodexPetPackInstallationError {
            self.feedback = CompanionPackFeedback(
                titleKey: "companion.packs.import.failure.title",
                messageKey: Self.localizationKey(for: error))
        } catch {
            self.feedback = CompanionPackFeedback(
                titleKey: "companion.packs.import.failure.title",
                messageKey: "companion.packs.error.unavailable")
        }
    }

    func remove(_ installation: CodexPetPackInstallation) {
        do {
            try self.store.remove(packID: installation.metadata.packID)
            self.reload()
        } catch {
            self.feedback = CompanionPackFeedback(
                titleKey: "companion.packs.remove.failure.title",
                messageKey: "companion.packs.remove.failure.message")
        }
    }

    private func reload() {
        self.installedPacks = self.store.installedPacks()
        CompanionAssetCatalog.shared.reloadInstalledAssets()
    }

    private static func localizationKey(
        for error: CodexPetPackInstallationError
    ) -> String {
        switch error {
        case .archiveUnavailable:
            "companion.packs.error.unavailable"
        case .archiveInspection, .archiveValidation:
            "companion.packs.error.archive"
        case .extractionFailed, .unsafeExtractedContents:
            "companion.packs.error.contents"
        case .manifestUnavailable:
            "companion.packs.error.manifest"
        case .atlasUnreadable:
            "companion.packs.error.image"
        case .packValidation:
            "companion.packs.error.contract"
        case .publishingFailed:
            "companion.packs.error.storage"
        }
    }
}

struct CompanionPackManagementView: View {
    @StateObject private var manager = CompanionPackManager()
    @State private var showsFileImporter = false
    @State private var importRequest: CompanionPackImportRequest?
    @State private var removalRequest: CompanionPackRemovalRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("companion.packs.title"))
                        .font(.title2.bold())
                    Text(AppLocalization.string("companion.packs.description"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    self.showsFileImporter = true
                } label: {
                    Label(
                        AppLocalization.string("companion.packs.import"),
                        systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.manager.isInstalling)
            }

            Label(
                AppLocalization.string("companion.packs.localOnly"),
                systemImage: "lock.shield")
                .font(.callout)
                .foregroundStyle(.secondary)

            if self.manager.isInstalling {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(AppLocalization.string(
                        "companion.packs.import.progress"))
                }
                .accessibilityElement(children: .combine)
            }

            if self.manager.installedPacks.isEmpty {
                ContentUnavailableView(
                    AppLocalization.string("companion.packs.empty.title"),
                    systemImage: "shippingbox",
                    description: Text(AppLocalization.string(
                        "companion.packs.empty.description")))
                    .frame(minHeight: 220)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 14)],
                    spacing: 14)
                {
                    ForEach(
                        self.manager.installedPacks,
                        id: \.metadata.packID)
                    { installation in
                        self.packCard(installation)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(
            isPresented: self.$showsFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false)
        { result in
            switch result {
            case let .success(urls):
                if let archiveURL = urls.first {
                    self.importRequest = CompanionPackImportRequest(
                        archiveURL: archiveURL)
                }
            case .failure:
                self.manager.feedback = CompanionPackFeedback(
                    titleKey: "companion.packs.import.failure.title",
                    messageKey: "companion.packs.error.unavailable")
            }
        }
        .sheet(item: self.$importRequest) { request in
            CompanionPackImportSheet(
                archiveURL: request.archiveURL,
                isInstalling: self.manager.isInstalling,
                cancel: { self.importRequest = nil },
                install: { provenance in
                    self.importRequest = nil
                    Task {
                        await self.manager.install(
                            archiveURL: request.archiveURL,
                            provenance: provenance)
                    }
                })
        }
        .alert(item: self.$manager.feedback) { feedback in
            Alert(
                title: Text(AppLocalization.string(feedback.titleKey)),
                message: Text(AppLocalization.string(feedback.messageKey)),
                dismissButton: .default(Text(AppLocalization.string(
                    "action.done"))))
        }
        .alert(item: self.$removalRequest) { request in
            Alert(
                title: Text(AppLocalization.string(
                    "companion.packs.remove.title")),
                message: Text(AppLocalization.format(
                    "companion.packs.remove.message",
                    request.installation.metadata.displayName)),
                primaryButton: .destructive(Text(AppLocalization.string(
                    "companion.packs.remove.action"))) {
                        self.manager.remove(request.installation)
                    },
                secondaryButton: .cancel())
        }
    }

    private func packCard(
        _ installation: CodexPetPackInstallation
    ) -> some View {
        let metadata = installation.metadata
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    ByteBotSpriteView(
                        speciesID: metadata.speciesID,
                        stage: .adult,
                        rarity: .normal,
                        behavior: .idle,
                        dimension: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metadata.displayName)
                            .font(.headline)
                        Text(AppLocalization.string(
                            metadata.format == .codexV2
                                ? "companion.packs.format.v2"
                                : "companion.packs.format.v1"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let description = metadata.description {
                            Text(description)
                                .font(.callout)
                                .lineLimit(3)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Divider()

                self.provenanceDetails(metadata.provenance)

                HStack {
                    Text(metadata.installedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(
                        AppLocalization.string("companion.packs.remove.action"),
                        role: .destructive)
                    {
                        self.removalRequest = CompanionPackRemovalRequest(
                            installation: installation)
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func provenanceDetails(
        _ provenance: CompanionAssetPackProvenance
    ) -> some View {
        if let author = provenance.author {
            LabeledContent(
                AppLocalization.string("companion.packs.author"),
                value: author)
        }
        LabeledContent(
            AppLocalization.string("companion.packs.license"),
            value: provenance.licenseIdentifier
                ?? AppLocalization.string("companion.packs.license.local"))
        if let sourceURL = provenance.sourceURL {
            LabeledContent(AppLocalization.string("companion.packs.source")) {
                Link(
                    AppLocalization.string("companion.packs.source.open"),
                    destination: sourceURL)
            }
        }
        if let notice = provenance.notice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct CompanionPackImportSheet: View {
    let archiveURL: URL
    let isInstalling: Bool
    let cancel: () -> Void
    let install: (CompanionAssetPackProvenance) -> Void

    @State private var author = ""
    @State private var sourceURL = ""
    @State private var licenseIdentifier = ""
    @State private var notice = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent(
                        AppLocalization.string("companion.packs.file"),
                        value: self.archiveURL.lastPathComponent)
                    Text(AppLocalization.string(
                        "companion.packs.import.requirements"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(AppLocalization.string(
                    "companion.packs.provenance.title"))
                {
                    TextField(
                        AppLocalization.string("companion.packs.author"),
                        text: self.$author)
                    TextField(
                        AppLocalization.string("companion.packs.source"),
                        text: self.$sourceURL)
                    TextField(
                        AppLocalization.string("companion.packs.license"),
                        text: self.$licenseIdentifier)
                    TextField(
                        AppLocalization.string("companion.packs.notice"),
                        text: self.$notice,
                        axis: .vertical)
                        .lineLimit(2...5)
                    Text(AppLocalization.string(
                        "companion.packs.provenance.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(
                    AppLocalization.string("action.cancel"),
                    action: self.cancel)
                Button(AppLocalization.string("companion.packs.install")) {
                    self.install(CompanionAssetPackProvenance(
                        author: self.author,
                        sourceURL: URL(string: self.sourceURL),
                        licenseIdentifier: self.licenseIdentifier,
                        notice: self.notice))
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.isInstalling || !self.sourceURLIsValid)
            }
            .padding()
        }
        .frame(width: 520, height: 440)
    }

    private var sourceURLIsValid: Bool {
        let value = self.sourceURL.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return true }
        guard let url = URL(string: value), let scheme = url.scheme else {
            return false
        }
        return scheme.lowercased() == "https" || scheme.lowercased() == "http"
    }
}
