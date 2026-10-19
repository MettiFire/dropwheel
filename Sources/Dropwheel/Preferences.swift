import AppKit
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case lilac, sky, mint, rose, orange, graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lilac: return "Lilac"
        case .sky: return "Sky blue"
        case .mint: return "Mint"
        case .rose: return "Rose"
        case .orange: return "Orange"
        case .graphite: return "Graphite"
        }
    }

    private var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .lilac: return (0.561, 0.420, 1.000)
        case .sky: return (0.176, 0.612, 1.000)
        case .mint: return (0.122, 0.749, 0.561)
        case .rose: return (0.941, 0.337, 0.549)
        case .orange: return (1.000, 0.541, 0.239)
        case .graphite: return (0.357, 0.384, 0.439)
        }
    }

    private var hue: Double {
        let c = NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }

    var hover: Color { Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1) }
    var base: Color { Color(hue: hue, saturation: 0.09, brightness: 1.0) }
    var ink: Color { Color(hue: hue, saturation: 0.70, brightness: 0.32) }
    var stroke: Color { hover.opacity(0.3) }
}

enum TriggerKey: String, CaseIterable, Identifiable {
    case shift, command, control, option

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shift: return "⇧ Shift"
        case .command: return "⌘ Command"
        case .control: return "⌃ Control"
        case .option: return "⌥ Option"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .command: return .command
        case .control: return .control
        case .option: return .option
        }
    }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published private(set) var keys: [Mode: TriggerKey]
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    private init() {
        let d = UserDefaults.standard
        func load(_ m: Mode, _ fallback: TriggerKey) -> TriggerKey {
            TriggerKey(rawValue: d.string(forKey: "key.\(m.rawValue)") ?? "") ?? fallback
        }
        keys = [.convert: load(.convert, .shift),
                .tools: load(.tools, .command),
                .actions: load(.actions, .control)]
        theme = Theme(rawValue: d.string(forKey: "theme") ?? "") ?? .lilac
    }

    func key(for mode: Mode) -> TriggerKey { keys[mode] ?? .shift }

    func mode(for key: TriggerKey) -> Mode? {
        Mode.allCases.first { keys[$0] == key }
    }

    /// Assigns a key to a mode; if another mode already used it, the two swap.
    func set(_ key: TriggerKey, for mode: Mode) {
        var next = keys
        if let other = Mode.allCases.first(where: { $0 != mode && next[$0] == key }) {
            next[other] = next[mode]
        }
        next[mode] = key
        keys = next
        for (m, k) in next {
            UserDefaults.standard.set(k.rawValue, forKey: "key.\(m.rawValue)")
        }
    }
}
