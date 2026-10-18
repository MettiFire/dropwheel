import Foundation

enum Category: Hashable {
    case image, audio, video, pdf, document, slides, spreadsheet, subtitle, archive, other

    static func of(_ url: URL) -> Category {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
           url.pathExtension.lowercased() != "rtfd" {
            return .other
        }
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "webp", "heic", "tiff", "tif", "avif", "bmp": return .image
        case "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma": return .audio
        case "mp4", "mov", "mkv", "webm", "avi", "wmv", "gif": return .video
        case "pdf": return .pdf
        case "docx", "md", "txt", "epub", "html", "rtf", "rtfd": return .document
        case "pptx", "ppt": return .slides
        case "xlsx", "xls", "ods", "csv", "tsv": return .spreadsheet
        case "srt", "vtt": return .subtitle
        case "zip", "tar", "tgz", "gz", "rar": return .archive
        default: return .other
        }
    }

    var targets: [String] {
        switch self {
        case .image: return ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"]
        case .audio: return ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff"]
        case .video: return ["mp4", "mov", "mkv", "webm", "avi", "gif", "mp3"]
        case .pdf: return ["docx", "png", "jpg", "txt"]
        case .document: return ["docx", "md", "txt", "epub", "html", "pdf"]
        case .slides: return ["pdf", "png", "jpg"]
        case .spreadsheet: return ["xlsx", "ods", "csv", "tsv", "pdf"]
        case .subtitle: return ["srt", "vtt", "txt"]
        case .archive: return ["zip", "tar", "tgz"]
        case .other: return []
        }
    }

    static func normalized(_ ext: String) -> String {
        let e = ext.lowercased()
        switch e {
        case "jpeg": return "jpg"
        case "tif": return "tiff"
        default: return e
        }
    }
}

enum Engine {
    /// Path to engine/engine.py. Override with DROPWHEEL_ENGINE;
    /// by default it is resolved relative to the working directory (run from the repo root).
    static var scriptPath: String {
        ProcessInfo.processInfo.environment["DROPWHEEL_ENGINE"]
            ?? FileManager.default.currentDirectoryPath + "/engine/engine.py"
    }

    static func run(_ args: [String]) async -> (ok: Bool, output: String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                p.arguments = ["python3", scriptPath] + args

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
                p.environment = env

                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do {
                    try p.run()
                } catch {
                    cont.resume(returning: (false, "\(error)"))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: (p.terminationStatus == 0,
                                        String(decoding: data, as: UTF8.self)))
            }
        }
    }
}
