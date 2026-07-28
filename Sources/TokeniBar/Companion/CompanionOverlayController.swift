import AppKit
import SwiftUI

@MainActor
final class CompanionOverlayController: NSObject, ObservableObject {
    private static let frameOriginKey = "companionOverlayFrameOrigin"

    private var panel: CompanionOverlayPanel?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    func connect(to store: UsageStore) {
        if self.panel == nil {
            self.panel = self.makePanel(store: store)
        }
        self.setSize(store.companionOverlaySize)
        self.setPositionLocked(store.companionOverlayPositionLocked)
        self.setClickThroughEnabled(
            store.companionOverlayClickThroughEnabled)
        self.setVisible(store.showsCompanionOverlay)
    }

    func setVisible(_ visible: Bool) {
        guard let panel else { return }
        if visible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
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
    private func screenParametersDidChange() {
        guard let panel else { return }
        panel.setFrameOrigin(self.constrainedOrigin(
            panel.frame.origin,
            panelSize: panel.frame.size))
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

private struct CompanionOverlayView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ByteBotTransitionView(
            speciesID: self.store.companionState.speciesID,
            stage: self.store.companionStage,
            rarity: self.store.companionState.rarity,
            behavior: self.store.companionBehavior,
            dimension: self.store.companionOverlaySize.spriteDimension,
            animationsEnabled: self.store.companionAnimationsEnabled)
            .padding(8)
            .contentShape(Rectangle())
            .help(AppLocalization.string(
                self.store.companionOverlayPositionLocked
                    ? "companion.overlay.locked"
                    : "companion.overlay.drag"))
    }
}
