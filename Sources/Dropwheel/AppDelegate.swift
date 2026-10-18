import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = WheelModel()
    private var panel: WheelPanel!
    private var watcher: DragWatcher!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = WheelPanel(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",
                                           accessibilityDescription: "Dropwheel")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Dropwheel",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu

        model.onFinish = { [weak self] in self?.panel.orderOut(nil) }

        watcher = DragWatcher()
        watcher.onStart = { [weak self] urls in self?.dragStarted(urls) }
        watcher.onModeKey = { [weak self] mode in self?.model.mode = mode }
        watcher.onEnd = { [weak self] in self?.dragEnded() }
        watcher.start()
    }

    private func dragStarted(_ urls: [URL]) {
        model.reset(files: urls)
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
}
