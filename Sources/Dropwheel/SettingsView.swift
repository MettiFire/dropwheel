import AppKit
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var loginEnabled = SMAppService.mainApp.status != .notRegistered
    @State private var loginNote = ""
    @State private var doctorText = ""

    var body: some View {
        Form {
            Section {
                ForEach(Mode.allCases) { mode in
                    Picker(mode.title, selection: Binding(
                        get: { prefs.key(for: mode) },
                        set: { prefs.set($0, for: mode) }
                    )) {
                        ForEach(TriggerKey.allCases) { Text($0.label).tag($0) }
                    }
                }
            } header: {
                Text("Trigger keys")
            } footer: {
                Text("Start dragging a file, then tap one of these keys to open the wheel.")
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginEnabled },
                    set: { setLogin($0) }
                ))
                if !loginNote.isEmpty {
                    Text(loginNote).font(.caption).foregroundColor(.secondary)
                }
            }

            Section("Tools") {
                HStack {
                    Button("Check installed tools") {
                        Task {
                            let r = await Engine.run(["doctor"])
                            doctorText = r.output
                        }
                    }
                    Button("Open log") {
                        Log.ensureExists()
                        NSWorkspace.shared.open(Log.url)
                    }
                }
                if !doctorText.isEmpty {
                    Text(doctorText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginNote = SMAppService.mainApp.status == .requiresApproval
                ? "Approve Dropwheel in System Settings › General › Login Items."
                : ""
        } catch {
            loginNote = "Couldn't change the login item (works only from the installed Dropwheel.app): \(error.localizedDescription)"
        }
        loginEnabled = SMAppService.mainApp.status != .notRegistered
    }
}
