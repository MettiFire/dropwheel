import AppKit

struct Outcome {
    let ok: Bool
    let message: String
}

struct WheelOption: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let perform: @MainActor ([URL]) async -> Outcome
}

enum Mode {
    case convert, tools, actions

    var title: String {
        switch self {
        case .convert: return "⇧ Convert"
        case .tools: return "⌘ Tools"
        case .actions: return "⌃ Actions"
        }
    }
}

enum Options {
    static func build(for files: [URL], mode: Mode?) -> [WheelOption] {
        guard let mode, !files.isEmpty else { return [] }
        switch mode {
        case .convert: return convertOptions(files)
        case .tools: return toolOptions(files)
        case .actions: return actionOptions(files)
        }
    }

    // MARK: - Convert (Shift)

    private static func convertOptions(_ files: [URL]) -> [WheelOption] {
        let cats = Set(files.map(Category.of))
        guard cats.count == 1, let cat = cats.first, cat != .other else { return [] }
        let own = Set(files.map { Category.normalized($0.pathExtension) })

        return cat.targets
            .filter { !own.contains($0) }
            .map { target in
                WheelOption(id: "convert-\(target)",
                            title: target.uppercased(),
                            symbol: "arrow.right.circle") { files in
                    await runEach(files) { ["convert", $0.path, target] }
                }
            }
    }

    // MARK: - Tools (Command)

    private struct ToolSpec {
        let name: String
        let title: String
        let symbol: String
    }

    private static func toolOptions(_ files: [URL]) -> [WheelOption] {
        let cats = Set(files.map(Category.of))
        guard cats.count == 1, let cat = cats.first else { return [] }

        let compress = ToolSpec(name: "compress", title: "Compress", symbol: "arrow.down.right.and.arrow.up.left")
        let strip = ToolSpec(name: "strip-metadata", title: "Strip meta", symbol: "eraser")
        var specs: [ToolSpec] = []

        switch cat {
        case .image:
            specs = [compress,
                     ToolSpec(name: "resize-50", title: "Resize 50%", symbol: "arrow.up.left.and.arrow.down.right"),
                     ToolSpec(name: "rotate-90", title: "Rotate", symbol: "rotate.right"),
                     strip]
        case .video:
            specs = [compress, strip]
        case .audio:
            specs = [strip]
        case .pdf:
            specs = [compress, ToolSpec(name: "split-pdf", title: "Split", symbol: "scissors")]
            if files.count > 1 {
                specs.append(ToolSpec(name: "merge-pdf", title: "Merge", symbol: "square.stack"))
            }
        default:
            break
        }

        return specs.map { spec in
            WheelOption(id: "tool-\(spec.name)", title: spec.title, symbol: spec.symbol) { files in
                if spec.name == "merge-pdf" {
                    let r = await Engine.run(["tool", spec.name] + files.map(\.path))
                    return Outcome(ok: r.ok, message: r.output)
                }
                return await runEach(files) { ["tool", spec.name, $0.path] }
            }
        }
    }

    // MARK: - Actions (Control)

    private static func actionOptions(_ files: [URL]) -> [WheelOption] {
        [
            WheelOption(id: "airdrop", title: "AirDrop", symbol: "airdrop") { files in
                guard let service = NSSharingService(named: .sendViaAirDrop) else {
                    return Outcome(ok: false, message: "AirDrop unavailable")
                }
                NSApp.activate(ignoringOtherApps: true)
                service.perform(withItems: files)
                return Outcome(ok: true, message: "")
            },
            WheelOption(id: "copy", title: "Copy", symbol: "doc.on.clipboard") { files in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects(files as [NSURL])
                return Outcome(ok: true, message: "")
            },
            WheelOption(id: "copy-path", title: "Copy Path", symbol: "doc.on.doc") { files in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string)
                return Outcome(ok: true, message: "")
            },
            WheelOption(id: "reveal", title: "Reveal", symbol: "folder") { files in
                NSWorkspace.shared.activateFileViewerSelecting(files)
                return Outcome(ok: true, message: "")
            },
            WheelOption(id: "terminal", title: "Terminal", symbol: "terminal") { files in
                let first = files[0]
                let isDir = (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let dir = isDir ? first : first.deletingLastPathComponent()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-a", "Terminal", dir.path]
                try? p.run()
                return Outcome(ok: true, message: "")
            },
        ]
    }

    // MARK: - Helpers

    private static func runEach(_ files: [URL],
                                _ args: @Sendable (URL) -> [String]) async -> Outcome {
        var failures: [String] = []
        for f in files {
            let r = await Engine.run(args(f))
            if !r.ok { failures.append(r.output) }
        }
        return failures.isEmpty
            ? Outcome(ok: true, message: "")
            : Outcome(ok: false, message: failures.joined(separator: "\n"))
    }
}
