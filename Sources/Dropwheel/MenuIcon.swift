import AppKit

enum MenuIcon {
    /// A tiny wheel: six rounded slices around a center dot (template image).
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let center = NSPoint(x: 9, y: 9)
            let n = 6
            let span = 2 * Double.pi / Double(n)
            for k in 0..<n {
                let mid = Double.pi / 2 + Double(k) * span
                sector(center: center, a0: mid - span / 2 + 0.11, a1: mid + span / 2 - 0.11,
                       r1: 3.7, r2: 8.5, c: 0.9).fill()
            }
            NSBezierPath(ovalIn: NSRect(x: 6.9, y: 6.9, width: 4.2, height: 4.2)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func sector(center: NSPoint, a0: Double, a1: Double,
                               r1: Double, r2: Double, c: Double) -> NSBezierPath {
        let ro = r2 - c, ri = r1 + c
        let dO = asin(c / ro), dI = asin(c / ri)
        let lineO = (ro * ro - c * c).squareRoot()
        let lineI = (ri * ri - c * c).squareRoot()
        let half = Double.pi / 2
        var pts: [NSPoint] = []

        func arc(_ centerR: Double, _ centerA: Double, _ r: Double, _ from: Double, _ to: Double) {
            let cx = centerR * cos(centerA), cy = centerR * sin(centerA)
            let steps = max(2, Int(abs(to - from) * r / 0.4))
            for i in 0...steps {
                let t = from + (to - from) * Double(i) / Double(steps)
                pts.append(NSPoint(x: center.x + cx + r * cos(t), y: center.y + cy + r * sin(t)))
            }
        }

        arc(0, 0, r2, a0 + dO, a1 - dO)
        arc(ro, a1 - dO, c, a1 - dO, a1 + half)
        pts.append(NSPoint(x: center.x + lineI * cos(a1), y: center.y + lineI * sin(a1)))
        arc(ri, a1 - dI, c, a1 + half, a1 - dI + Double.pi)
        arc(0, 0, r1, a1 - dI, a0 + dI)
        arc(ri, a0 + dI, c, a0 + dI + Double.pi, a0 + 3 * half)
        pts.append(NSPoint(x: center.x + lineO * cos(a0), y: center.y + lineO * sin(a0)))
        arc(ro, a0 + dO, c, a0 + 3 * half, a0 + dO + 2 * Double.pi)

        let path = NSBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.close()
        return path
    }
}
