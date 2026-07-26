import AppKit

@main
enum PomodoroApp {
    /// NSApplication.delegate is a weak reference, so hold the delegate here.
    @MainActor static var delegate: AppDelegate?

    @MainActor static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        app.delegate = appDelegate
        // Menu bar only: no Dock icon, no app switcher entry.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
