import AppKit

/// Detects a system-wide file drag by watching the drag pasteboard, and
/// edge-detects Shift / Command / Control taps while the mouse is down.
/// Polling NSEvent.modifierFlags needs no Accessibility permission.
@MainActor
final class DragWatcher {
    var onStart: (([URL]) -> Void)?
    var onModeKey: ((Mode) -> Void)?
    var onEnd: (() -> Void)?

    private let pb = NSPasteboard(name: .drag)
    private var lastCount: Int
    private var dragging = false
    private var lastFlags: NSEvent.ModifierFlags = []
    private var timer: Timer?

    private static let tracked: NSEvent.ModifierFlags = [.shift, .command, .control]

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
               let urls = pb.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL],
               !urls.isEmpty {
                dragging = true
                lastFlags = NSEvent.modifierFlags.intersection(Self.tracked)
                onStart?(urls)
            }
        }

        guard dragging else { return }

        if !mouseDown {
            dragging = false
            onEnd?()
            return
        }

        let flags = NSEvent.modifierFlags.intersection(Self.tracked)
        let newlyPressed = flags.subtracting(lastFlags)
        lastFlags = flags

        if newlyPressed.contains(.shift) { onModeKey?(.convert) }
        else if newlyPressed.contains(.command) { onModeKey?(.tools) }
        else if newlyPressed.contains(.control) { onModeKey?(.actions) }
    }
}
