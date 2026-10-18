import AppKit

enum MenuIcon {
    /// An open ring with an arrow dropping into it: "drop onto the wheel".
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

            let ring = NSBezierPath()
            ring.appendArc(withCenter: NSPoint(x: 9, y: 8.5), radius: 6.5,
                           startAngle: 125, endAngle: 55, clockwise: false)
            ring.lineWidth = 1.5
            ring.lineCapStyle = .round
            ring.stroke()

            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 9, y: 16.5))
            arrow.line(to: NSPoint(x: 9, y: 5.5))
            arrow.move(to: NSPoint(x: 6.2, y: 8.3))
            arrow.line(to: NSPoint(x: 9, y: 5.5))
            arrow.line(to: NSPoint(x: 11.8, y: 8.3))
            arrow.lineWidth = 1.6
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
