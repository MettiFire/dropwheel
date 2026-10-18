import AppKit

@main
struct DropwheelApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar agent: no Dock icon
        app.run()
    }
}
