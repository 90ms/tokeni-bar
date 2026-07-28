import AppKit
import SwiftUI

@MainActor
final class CompanionOverlayController: ObservableObject {
    private static let frameOriginKey = "companionOverlayFrameOrigin"
    private static let panelSize = NSSize(width: 112, height: 112)

    private var panel: CompanionOverlayPanel?

    func connect(to store: UsageStore) {
        if self.panel == nil {
            self.panel = self.makePanel(store: store)
        }
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

    private func makePanel(store: UsageStore) -> CompanionOverlayPanel {
        let frame = NSRect(
            origin: self.restoredOrigin(),
            size: Self.panelSize)
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
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.contentView = NSHostingView(
            rootView: CompanionOverlayView(store: store))
        panel.delegate = self
        panel.setFrameOrigin(self.constrainedOrigin(frame.origin))
        return panel
    }

    private func restoredOrigin() -> NSPoint {
        guard let stored = UserDefaults.standard.string(forKey: Self.frameOriginKey)
        else {
            return self.defaultOrigin()
        }
        return NSPointFromString(stored)
    }

    private func defaultOrigin() -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(
            x: visibleFrame.maxX - Self.panelSize.width - 24,
            y: visibleFrame.maxY - Self.panelSize.height - 24)
    }

    private func constrainedOrigin(_ requestedOrigin: NSPoint) -> NSPoint {
        let requestedFrame = NSRect(origin: requestedOrigin, size: Self.panelSize)
        let screen = NSScreen.screens.first(where: {
            $0.visibleFrame.intersects(requestedFrame)
        }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return requestedOrigin }
        return NSPoint(
            x: min(
                max(requestedOrigin.x, visibleFrame.minX),
                visibleFrame.maxX - Self.panelSize.width),
            y: min(
                max(requestedOrigin.y, visibleFrame.minY),
                visibleFrame.maxY - Self.panelSize.height))
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
            dimension: 96,
            animationsEnabled: self.store.companionAnimationsEnabled)
            .padding(8)
            .contentShape(Rectangle())
            .help(AppLocalization.string("companion.overlay.drag"))
    }
}
