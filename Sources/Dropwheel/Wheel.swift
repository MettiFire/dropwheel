import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model

@MainActor
final class WheelModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var mode: Mode? = nil
    @Published var busy = false
    @Published var status: String? = nil

    var onFinish: (() -> Void)?

    var options: [WheelOption] { Options.build(for: files, mode: mode) }

    func reset(files: [URL]) {
        self.files = files
        mode = nil
        busy = false
        status = nil
    }

    func run(_ option: WheelOption) {
        guard !busy else { return }
        busy = true
        let files = self.files
        Task {
            let outcome = await option.perform(files)
            busy = false
            if outcome.ok {
                status = "✓ \(option.title)"
            } else {
                status = "✕ Failed"
                FileHandle.standardError.write(Data(outcome.message.utf8))
            }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            onFinish?()
        }
    }
}

// MARK: - Panel

@MainActor
final class WheelPanel: NSPanel {
    static let size: CGFloat = 440

    init(model: WheelModel) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: WheelView(model: model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present(at point: NSPoint) {
        var origin = NSPoint(x: point.x - Self.size / 2, y: point.y - Self.size / 2)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let f = screen.visibleFrame
            origin.x = min(max(origin.x, f.minX), f.maxX - Self.size)
            origin.y = min(max(origin.y, f.minY), f.maxY - Self.size)
        }
        setFrameOrigin(origin)
        orderFrontRegardless()
    }
}

// MARK: - Views

struct WheelView: View {
    @ObservedObject var model: WheelModel
    private let radius: CGFloat = 140

    var body: some View {
        let opts = model.options
        ZStack {
            CenterView(model: model)
            ForEach(Array(opts.enumerated()), id: \.element.id) { index, option in
                let angle = 2 * Double.pi * Double(index) / Double(max(opts.count, 1)) - Double.pi / 2
                WheelItem(option: option, model: model)
                    .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            }
        }
        .frame(width: WheelPanel.size, height: WheelPanel.size)
    }
}

struct CenterView: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        VStack(spacing: 4) {
            if let status = model.status {
                Text(status).font(.system(size: 14, weight: .semibold))
            } else if model.busy {
                ProgressView().controlSize(.small)
            } else if let mode = model.mode {
                Text(mode.title).font(.system(size: 13, weight: .semibold))
                if model.options.isEmpty {
                    Text("nothing for this selection").font(.system(size: 10))
                }
            } else {
                Text("⇧ convert").font(.system(size: 11))
                Text("⌘ tools").font(.system(size: 11))
                Text("⌃ actions").font(.system(size: 11))
            }
            Text("\(model.files.count) item\(model.files.count == 1 ? "" : "s")")
                .font(.system(size: 9))
                .opacity(0.6)
        }
        .foregroundColor(.white)
        .frame(width: 120, height: 120)
        .background(Circle().fill(Color.black.opacity(0.6)))
    }
}

struct WheelItem: View {
    let option: WheelOption
    @ObservedObject var model: WheelModel
    @State private var hover = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: option.symbol).font(.system(size: 20))
            Text(option.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
        }
        .foregroundColor(.white)
        .frame(width: 72, height: 72)
        .background(Circle().fill(hover ? Color.orange : Color.black.opacity(0.6)))
        .scaleEffect(hover ? 1.12 : 1)
        .animation(.easeOut(duration: 0.12), value: hover)
        .onDrop(of: [.fileURL], isTargeted: $hover) { _ in
            model.run(option)
            return true
        }
    }
}
