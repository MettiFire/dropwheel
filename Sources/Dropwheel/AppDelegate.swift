import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = WheelModel()
    private var panel: WheelPanel!
    private var watcher: DragWatcher!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var lastClosed = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = WheelPanel(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuIcon.make()
            button.toolTip = "Dropwheel"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 340, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(quit: { NSApp.terminate(nil) })
        )

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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !model.busy && model.status == nil {
                panel.orderOut(nil)
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else if Date().timeIntervalSince(lastClosed) > 0.25 {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosed = Date()
    }
}
