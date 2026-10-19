import AppKit

/// Watches the drag pasteboard. Nothing is shown until, during a file drag,
/// the user taps one of the configured trigger keys.
@MainActor
final class DragWatcher {
    var onActivate: (([URL], Mode) -> Void)?
    var onModeKey: ((Mode) -> Void)?
    var onEnd: (() -> Void)?

    private let pb = NSPasteboard(name: .drag)
    private var lastCount: Int
    private var dragging = false
    private var activated = false
    private var urls: [URL] = []
    private var lastFlags: NSEvent.ModifierFlags = []
    private var timer: Timer?

    private static let tracked: NSEvent.ModifierFlags = [.shift, .command, .control, .option]

    init() {
        lastCount = NSPasteboard(name: .drag).changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0

        if pb.changeCount != lastCount {
            lastCount = pb.changeCount
            if mouseDown, !dragging,
               let found = pb.readObjects(forClasses: [NSURL.self],
                                          options: [.urlReadingFileURLsOnly: true]) as? [URL],
               !found.isEmpty {
                dragging = true
                activated = false
                urls = found
                lastFlags = NSEvent.modifierFlags.intersection(Self.tracked)
            }
        }

        guard dragging else { return }

        if !mouseDown {
            if activated { onEnd?() }
            dragging = false
            activated = false
            return
        }

        let flags = NSEvent.modifierFlags.intersection(Self.tracked)
        let newlyPressed = flags.subtracting(lastFlags)
        lastFlags = flags
        guard !newlyPressed.isEmpty else { return }

        for key in TriggerKey.allCases where newlyPressed.contains(key.flag) {
            if let mode = Preferences.shared.mode(for: key) {
                if activated {
                    onModeKey?(mode)
                } else {
                    activated = true
                    onActivate?(urls, mode)
                }
                break
            }
        }
    }
}
