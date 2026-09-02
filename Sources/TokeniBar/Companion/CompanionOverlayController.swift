import AppKit
import SwiftUI
import TokeniCore

@MainActor
final class CompanionOverlayController: NSObject, ObservableObject {
    private static let frameOriginKey = "companionOverlayFrameOrigin"

    private var panel: CompanionOverlayPanel?
    private var celebrationPanel: CompanionCelebrationPanel?
    private var mouseRoutingTimer: Timer?
    private weak var store: UsageStore?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func connect(to store: UsageStore) {
        self.store = store
        self.setVisible(store.showsCompanionOverlay)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            if self.panel == nil, let store {
                self.panel = self.makePanel(store: store)
            }
            guard let panel else { return }
            self.startMouseRouting()
            self.updateMouseEventRouting()
            panel.orderFrontRegardless()
        } else {
            self.closeOverlayPanel()
        }
    }

    func presentCelebration(_ celebration: CompanionCelebration) {
        guard let store,
              let screen = self.panel?.screen ?? NSScreen.main
        else { return }

        let frame = screen.frame
        let celebrationPanel: CompanionCelebrationPanel
        if let existing = self.celebrationPanel {
            celebrationPanel = existing
            celebrationPanel.setFrame(frame, display: true, animate: false)
        } else {
            celebrationPanel = CompanionCelebrationPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false)
            celebrationPanel.backgroundColor = .clear
            celebrationPanel.isOpaque = false
            celebrationPanel.hasShadow = false
            celebrationPanel.level = .screenSaver
            celebrationPanel.hidesOnDeactivate = false
            celebrationPanel.becomesKeyOnlyIfNeeded = true
            celebrationPanel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle,
            ]
            self.celebrationPanel = celebrationPanel
        }

        celebrationPanel.contentView = NSHostingView(
            rootView: CompanionCelebrationView(
                celebration: celebration,
                animationsEnabled: store.companionAnimationsEnabled,
                dismiss: { [weak self, weak store] in
                    store?.dismissCompanionCelebration()
                    self?.dismissCelebration()
                }))
        celebrationPanel.orderFrontRegardless()
        celebrationPanel.makeKey()
    }

    func dismissCelebration() {
        guard let celebrationPanel else { return }
        celebrationPanel.orderOut(nil)
        celebrationPanel.contentView = nil
        celebrationPanel.close()
        self.celebrationPanel = nil
    }

    func setSize(_ size: CompanionOverlaySize) {
        guard let panel else { return }
        let panelSize = size.panelSize
        guard panel.frame.size != panelSize else { return }
        let currentCenter = NSPoint(
            x: panel.frame.midX,
            y: panel.frame.midY)
        let requestedOrigin = NSPoint(
            x: currentCenter.x - panelSize.width / 2,
            y: currentCenter.y - panelSize.height / 2)
        let frame = NSRect(
            origin: self.constrainedOrigin(
                requestedOrigin,
                panelSize: panelSize),
            size: panelSize)
        panel.setFrame(frame, display: true, animate: false)
    }

    func setPositionLocked(_ locked: Bool) {
        self.panel?.isMovableByWindowBackground = !locked
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        if enabled {
            self.panel?.ignoresMouseEvents = true
        } else {
            self.updateMouseEventRouting()
        }
    }

    func resetPosition(size: CompanionOverlaySize) {
        guard let panel else { return }
        let panelSize = size.panelSize
        panel.setFrameOrigin(self.defaultOrigin(panelSize: panelSize))
    }

    @objc
    private func screenParametersDidChange(_ notification: Notification) {
        if let panel {
            panel.setFrameOrigin(self.constrainedOrigin(
                panel.frame.origin,
                panelSize: panel.frame.size))
        }
        if let celebrationPanel {
            let screen = celebrationPanel.screen ?? NSScreen.main
            if let screen {
                celebrationPanel.setFrame(screen.frame, display: true, animate: false)
            }
        }
    }

    private func makePanel(store: UsageStore) -> CompanionOverlayPanel {
        let panelSize = store.companionOverlaySize.panelSize
        let frame = NSRect(
            origin: self.restoredOrigin(panelSize: panelSize),
            size: panelSize)
        let panel = CompanionOverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = !store.companionOverlayPositionLocked
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = store.companionOverlayClickThroughEnabled
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.contentView = NSHostingView(
            rootView: CompanionOverlayView(store: store))
        panel.delegate = self
        panel.setFrameOrigin(self.constrainedOrigin(
            frame.origin,
            panelSize: panelSize))
        return panel
    }

    private func closeOverlayPanel() {
        self.dismissCelebration()
        self.mouseRoutingTimer?.invalidate()
        self.mouseRoutingTimer = nil
        guard let panel else { return }
        panel.orderOut(nil)
        panel.contentView = nil
        panel.delegate = nil
        panel.close()
        self.panel = nil
        CompanionAssetCatalog.shared.removeCachedImages()
    }

    private func startMouseRouting() {
        guard self.mouseRoutingTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            repeats: true)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMouseEventRouting()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.mouseRoutingTimer = timer
    }

    private func updateMouseEventRouting() {
        guard let panel, let store else { return }
        guard !store.companionOverlayClickThroughEnabled else {
            if !panel.ignoresMouseEvents {
                panel.ignoresMouseEvents = true
            }
            return
        }
        let shouldIgnore = !self.companionInteractionFrame(
            panel: panel,
            size: store.companionOverlaySize)
            .contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }
    }

    private func companionInteractionFrame(
        panel: NSPanel,
        size: CompanionOverlaySize) -> NSRect
    {
        // Route events across the complete sprite canvas and its SwiftUI
        // padding. A stage-based inner rectangle excluded ears, wings, claws,
        // and other species-specific silhouettes from dragging.
        let interactionDimension = size.spriteDimension + 16
        let interactionSize = CGSize(
            width: interactionDimension,
            height: interactionDimension)
        let center = NSPoint(
            x: panel.frame.midX,
            y: panel.frame.minY + size.panelDimension / 2 + 6)
        return NSRect(
            x: center.x - interactionSize.width / 2,
            y: center.y - interactionSize.height / 2,
            width: interactionSize.width,
            height: interactionSize.height)
    }

    private func restoredOrigin(panelSize: NSSize) -> NSPoint {
        guard let stored = UserDefaults.standard.string(forKey: Self.frameOriginKey)
        else {
            return self.defaultOrigin(panelSize: panelSize)
        }
        return NSPointFromString(stored)
    }

    private func defaultOrigin(panelSize: NSSize) -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(
            x: visibleFrame.maxX - panelSize.width - 24,
            y: visibleFrame.maxY - panelSize.height - 24)
    }

    private func constrainedOrigin(
        _ requestedOrigin: NSPoint,
        panelSize: NSSize) -> NSPoint
    {
        let requestedFrame = NSRect(origin: requestedOrigin, size: panelSize)
        let screen = NSScreen.screens.first(where: {
            $0.visibleFrame.intersects(requestedFrame)
        }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return requestedOrigin }
        return NSPoint(
            x: min(
                max(requestedOrigin.x, visibleFrame.minX),
                visibleFrame.maxX - panelSize.width),
            y: min(
                max(requestedOrigin.y, visibleFrame.minY),
                visibleFrame.maxY - panelSize.height))
    }
}

extension CompanionOverlayController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        UserDefaults.standard.set(
            NSStringFromPoint(panel.frame.origin),
            forKey: Self.frameOriginKey)
    }
}

private final class CompanionOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CompanionCelebrationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CompanionOverlayView: View {
    @ObservedObject var store: UsageStore
    @State private var speechMessageKey: String?

    var body: some View {
        VStack(spacing: 2) {
            if let speechMessageKey {
                Text(AppLocalization.string(speechMessageKey))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: 210)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 10))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 58)
            }

            ByteBotTransitionView(
                speciesID: self.store.displayedCompanionAppearanceSpeciesID,
                stage: self.store.displayedCompanionStage,
                rarity: self.store.displayedCompanionRarity,
                variantID: self.store.displayedCompanionVariantID,
                behavior: self.store.companionBehavior,
                mutationID: self.store.displayedCompanionMutationID,
                cosmeticIDs: self.store.companionRewardState.selectedCosmeticIDs,
                dimension: self.store.companionOverlaySize.spriteDimension,
                animationsEnabled: self.store.companionAnimationsEnabled,
                animationIntensity: self.store
                    .companionAnimationIntensity.motionScale,
                interactionPulse: self.store.companionInteractionPulse,
                growthPulse: self.store.isShowingArchivedCompanion
                    ? 0
                    : self.store.companionGrowthPulse)
                .padding(8)
        }
            .animation(.easeInOut(duration: 0.2), value: self.speechMessageKey)
            .contentShape(Rectangle())
            .onTapGesture {
                self.store.patCompanion()
            }
            .accessibilityAction {
                self.store.patCompanion()
            }
            .help(AppLocalization.string(
                self.store.companionOverlayPositionLocked
                    ? "companion.overlay.locked"
                    : "companion.overlay.drag"))
            .task(id: self.store.displayedCompanionLevel) {
                guard self.store.displayedCompanionLevel
                    == CompanionLevelCurve.standard.maximumLevel
                else {
                    self.speechMessageKey = nil
                    return
                }
                while !Task.isCancelled {
                    let keys = (1...7).map {
                        "companion.maxLevel.message.\($0)"
                    }
                    self.speechMessageKey = keys
                        .filter { $0 != self.speechMessageKey }
                        .randomElement()
                    try? await Task.sleep(for: .milliseconds(1800))
                    self.speechMessageKey = nil
                    let delay = Int.random(in: 180...420)
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
    }
}
