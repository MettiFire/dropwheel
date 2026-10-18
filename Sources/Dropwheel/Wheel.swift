import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let wheelSize: CGFloat = 240

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
                status = "✕ Failed, see log"
                Log.write("\(option.id) failed: \(outcome.message)")
            }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            onFinish?()
        }
    }
}

// MARK: - Panel

@MainActor
final class WheelPanel: NSPanel {
    init(model: WheelModel) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: wheelSize, height: wheelSize),
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
        var origin = NSPoint(x: point.x - wheelSize / 2, y: point.y - wheelSize / 2)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let f = screen.visibleFrame
            origin.x = min(max(origin.x, f.minX), f.maxX - wheelSize)
            origin.y = min(max(origin.y, f.minY), f.maxY - wheelSize)
        }
        setFrameOrigin(origin)
        orderFrontRegardless()
    }
}

// MARK: - Views

private let wheelInner: CGFloat = 40
private let wheelOuter: CGFloat = 110
private let wheelCorner: CGFloat = 6
private let wheelGap: Double = 0.05

struct WheelView: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        let opts = model.options
        ZStack {
            ForEach(Array(opts.enumerated()), id: \.element.id) { index, option in
                WheelSlice(option: option, index: index, count: opts.count, model: model)
            }
            CenterView(model: model)
        }
        .frame(width: wheelSize, height: wheelSize)
        .preferredColorScheme(.light)
    }
}

struct CenterView: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        VStack(spacing: 2) {
            if let status = model.status {
                Text(status).font(.system(size: 10, weight: .semibold)).lineLimit(2)
            } else if model.busy {
                ProgressView().controlSize(.small)
            } else {
                Text(model.mode?.title ?? "").font(.system(size: 11, weight: .semibold))
                if model.options.isEmpty {
                    Text("nothing here").font(.system(size: 9))
                }
            }
            Text("\(model.files.count) file\(model.files.count == 1 ? "" : "s")")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .foregroundColor(Color(white: 0.15))
        .multilineTextAlignment(.center)
        .frame(width: 72, height: 72)
        .background(Circle().fill(Color.white.opacity(0.96)))
        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
    }
}

struct WheelSlice: View {
    let option: WheelOption
    let index: Int
    let count: Int
    @ObservedObject var model: WheelModel
    @State private var hover = false

    var body: some View {
        let span = 2 * Double.pi / Double(count)
        let start = -Double.pi / 2 + Double(index) * span + wheelGap / 2
        let end = start + span - wheelGap
        let mid = (start + end) / 2
        let labelRadius = Double(wheelInner + wheelOuter) / 2
        let shape = SectorShape(startAngle: start, endAngle: end,
                                innerRadius: wheelInner, outerRadius: wheelOuter,
                                cornerRadius: wheelCorner)
        ZStack {
            shape
                .fill(hover ? Color.orange : Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            shape.stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            VStack(spacing: 1) {
                Image(systemName: option.symbol).font(.system(size: 14))
                Text(option.title)
                    .font(.system(size: 8.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 48)
            .foregroundColor(hover ? .white : Color(white: 0.15))
            .offset(x: CGFloat(labelRadius * cos(mid)), y: CGFloat(labelRadius * sin(mid)))
        }
        .contentShape(shape)
        .onDrop(of: [.fileURL], isTargeted: $hover) { _ in
            model.run(option)
            return true
        }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// Annular sector with four rounded corners, attached to the center circle.
struct SectorShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a0 = startAngle, a1 = endAngle
        let r1 = Double(innerRadius), r2 = Double(outerRadius), c = Double(cornerRadius)
        let ro = r2 - c, ri = r1 + c
        let dO = asin(c / ro), dI = asin(c / ri)
        let lineO = (ro * ro - c * c).squareRoot()
        let lineI = (ri * ri - c * c).squareRoot()
        let half = Double.pi / 2

        var pts: [CGPoint] = []

        func arc(_ centerR: Double, _ centerA: Double, _ r: Double, _ from: Double, _ to: Double) {
            let cx = centerR * cos(centerA), cy = centerR * sin(centerA)
            let steps = max(2, Int(abs(to - from) * r / 1.5))
            for i in 0...steps {
                let t = from + (to - from) * Double(i) / Double(steps)
                pts.append(CGPoint(x: center.x + CGFloat(cx + r * cos(t)),
                                   y: center.y + CGFloat(cy + r * sin(t))))
            }
        }

        arc(0, 0, r2, a0 + dO, a1 - dO)
        arc(ro, a1 - dO, c, a1 - dO, a1 + half)
        pts.append(CGPoint(x: center.x + CGFloat(lineI * cos(a1)), y: center.y + CGFloat(lineI * sin(a1))))
        arc(ri, a1 - dI, c, a1 + half, a1 - dI + Double.pi)
        arc(0, 0, r1, a1 - dI, a0 + dI)
        arc(ri, a0 + dI, c, a0 + dI + Double.pi, a0 + 3 * half)
        pts.append(CGPoint(x: center.x + CGFloat(lineO * cos(a0)), y: center.y + CGFloat(lineO * sin(a0))))
        arc(ro, a0 + dO, c, a0 + 3 * half, a0 + dO + 2 * Double.pi)

        var path = Path()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
