import Foundation
import TokeniWindowsNative

/// A virtual-screen frame for the Windows companion overlay.
public struct WindowsCompanionOverlayFrame: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Owns the lifecycle of the native companion overlay without exposing
/// Windows handles or other WinSDK types to Swift callers.
public final class WindowsCompanionOverlay: @unchecked Sendable {
    private let stateLock = NSLock()
    private var started = false

    public init() {}

    /// Creates the overlay window at the supplied virtual-screen frame.
    /// Calling `start` more than once is idempotent while this wrapper is
    /// running.
    @discardableResult
    public func start(frame: WindowsCompanionOverlayFrame) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }

        guard !self.started,
              let nativeFrame = Self.nativeFrame(frame)
        else {
            return self.started
        }

        let result = tokeni_windows_overlay_start(
            nativeFrame.x,
            nativeFrame.y,
            nativeFrame.width,
            nativeFrame.height)
        self.started = result != 0
        return self.started
    }

    @discardableResult
    public func show() -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        return tokeni_windows_overlay_show() != 0
    }

    @discardableResult
    public func hide() -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        return tokeni_windows_overlay_hide() != 0
    }

    @discardableResult
    public func setFrame(_ frame: WindowsCompanionOverlayFrame) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }

        guard self.started,
              let nativeFrame = Self.nativeFrame(frame)
        else {
            return false
        }

        return tokeni_windows_overlay_set_frame(
            nativeFrame.x,
            nativeFrame.y,
            nativeFrame.width,
            nativeFrame.height) != 0
    }

    /// Sets click-through behavior. The native boundary also accepts this
    /// setting before `start`, so callers can configure the initial window.
    @discardableResult
    public func setClickThrough(_ enabled: Bool) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        return tokeni_windows_overlay_set_click_through(enabled ? 1 : 0) != 0
    }

    public func stop() {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return }

        tokeni_windows_overlay_stop()
        self.started = false
    }

    public func isVisible() -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        return tokeni_windows_overlay_is_visible() != 0
    }

    private static func nativeFrame(
        _ frame: WindowsCompanionOverlayFrame) -> NativeFrame?
    {
        guard let x = Int32(exactly: frame.x),
              let y = Int32(exactly: frame.y),
              let width = Int32(exactly: frame.width),
              let height = Int32(exactly: frame.height)
        else {
            return nil
        }
        return NativeFrame(x: x, y: y, width: width, height: height)
    }
}

private struct NativeFrame {
    let x: Int32
    let y: Int32
    let width: Int32
    let height: Int32
}
