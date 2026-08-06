import AppKit
import SwiftUI
import UserNotifications
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let overlay = OverlayController()
    private let engine = TimerEngine.shared
    private var prefsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var notificationsAllowed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPopover()
        requestNotificationPermission()

        engine.onBreakStarted = { [weak self] phase in
            self?.presentBreak(phase)
        }
        engine.onBreakEnded = { [weak self] in
            self?.overlay.hide()
        }
        engine.onBreakUpcoming = { [weak self] phase in
            self?.notifyUpcoming(phase)
        }

        // Keep the menu bar clock in step with the timer.
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusTitle() }
            .store(in: &cancellables)

        engine.boot()
        updateStatusTitle()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    private func updateStatusTitle() {
        let symbol: String
        if engine.phase == .idle {
            symbol = "⏹"
        } else if engine.isPaused {
            symbol = "⏸"
        } else {
            switch engine.phase {
            case .focus: symbol = "🍅"
            case .shortBreak: symbol = "☕️"
            case .longBreak: symbol = "🚶"
            case .idle: symbol = "⏹"
            }
        }
        let time = engine.phase == .idle ? "" : " \(clock(engine.remaining))"
        statusItem.button?.title = "\(symbol)\(time)"
    }

    private func clock(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Popover

    private func setUpPopover() {
        let dashboard = DashboardView(
            onPreferences: { [weak self] in
                self?.popover.performClose(nil)
                self?.openPreferences()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        let controller = NSHostingController(rootView: dashboard)
        controller.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Break presentation

    private func presentBreak(_ phase: Phase) {
        let message = Quotes.message(for: phase)
        overlay.show(message: message) { [weak self] in
            self?.engine.skipBreak()
        }
        notify(title: Quotes.notificationTitle(for: phase), body: message)
    }

    private func notifyUpcoming(_ phase: Phase) {
        let minutes = phase == .longBreak ? 2 : 1
        let kind = phase == .longBreak ? "Long break" : "Break"
        notify(title: "Almost break time", body: "\(kind) in \(minutes) minute\(minutes == 1 ? "" : "s").")
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                Task { @MainActor in self?.notificationsAllowed = granted }
            }
    }

    private func notify(title: String, body: String) {
        guard notificationsAllowed else {
            NSSound(named: "Glass")?.play()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Preferences

    private func openPreferences() {
        if let window = prefsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Pomodoro Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow = window
    }
}
