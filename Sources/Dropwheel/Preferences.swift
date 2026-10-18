import AppKit

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

    private init() {
        let d = UserDefaults.standard
        func load(_ m: Mode, _ fallback: TriggerKey) -> TriggerKey {
            TriggerKey(rawValue: d.string(forKey: "key.\(m.rawValue)") ?? "") ?? fallback
        }
        keys = [.convert: load(.convert, .shift),
                .tools: load(.tools, .command),
                .actions: load(.actions, .control)]
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
