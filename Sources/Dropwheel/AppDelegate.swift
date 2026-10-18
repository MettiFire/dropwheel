import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = WheelModel()
    private var panel: WheelPanel!
    private var watcher: DragWatcher!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = WheelPanel(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuIcon.make()
        statusItem.button?.toolTip = "Dropwheel"

        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Dropwheel",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu

        model.onFinish = { [weak self] in self?.panel.orderOut(nil) }

        watcher = DragWatcher()
        watcher.onActivate = { [weak self] urls, mode in self?.activate(urls, mode) }
        watcher.onModeKey = { [weak self] mode in self?.model.mode = mode }
        watcher.onEnd = { [weak self] in self?.dragEnded() }
        watcher.start()
    }

    private func activate(_ urls: [URL], _ mode: Mode) {
        model.reset(files: urls)
        model.mode = mode
        panel.present(at: NSEvent.mouseLocation)
    }

    private func dragEnded() {
        // Give the drop a moment to land before closing the wheel.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !model.busy && model.status == nil {
                panel.orderOut(nil)
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Dropwheel Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
