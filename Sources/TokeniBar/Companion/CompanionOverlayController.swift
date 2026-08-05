import AppKit
import SwiftUI

@MainActor
final class CompanionOverlayController: NSObject, ObservableObject {
    private static let frameOriginKey = "companionOverlayFrameOrigin"

    private var panel: CompanionOverlayPanel?
    private var celebrationPanel: CompanionCelebrationPanel?
    private weak var store: UsageStore?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
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
        let panelSize = NSSize(
            width: size.panelDimension,
            height: size.panelDimension)
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
        self.panel?.ignoresMouseEvents = enabled
    }

    func resetPosition(size: CompanionOverlaySize) {
        guard let panel else { return }
        let panelSize = NSSize(
            width: size.panelDimension,
            height: size.panelDimension)
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
        let panelSize = NSSize(
            width: store.companionOverlaySize.panelDimension,
            height: store.companionOverlaySize.panelDimension)
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
        guard let panel else { return }
        panel.orderOut(nil)
        panel.contentView = nil
        panel.delegate = nil
        panel.close()
        self.panel = nil
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

    var body: some View {
        ByteBotTransitionView(
            speciesID: self.store.displayedCompanionSpeciesID,
            stage: self.store.displayedCompanionStage,
            rarity: self.store.displayedCompanionRarity,
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
    }
}
