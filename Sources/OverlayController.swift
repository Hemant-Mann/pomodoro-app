import AppKit
import SwiftUI

/// A borderless window that floats above everything, including full-screen apps.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows the break overlay on every attached screen and tears it down again.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []

    var isVisible: Bool { !windows.isEmpty }

    func show(message: String, onSkip: @escaping () -> Void) {
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            // The break screen is deliberately dark in both Light and Dark mode.
            window.appearance = NSAppearance(named: .darkAqua)
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: BreakOverlay(message: message, onSkip: onSkip)
            )
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
    }
}
