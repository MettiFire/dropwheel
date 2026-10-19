import AppKit
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let quit: () -> Void

    @ObservedObject private var prefs = Preferences.shared
    @State private var loginEnabled = SettingsView.loginIsOn
    @State private var loginNote = ""
    @State private var doctorText = ""

    init(quit: @escaping () -> Void) {
        self.quit = quit
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dropwheel").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    triggerSection
                    accentSection
                    generalSection
                    toolsSection
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit Dropwheel", action: quit)
            }
            .padding(12)
        }
        .frame(width: 340, height: 500)
        .tint(prefs.theme.hover)
    }

    // MARK: - Sections

    private var triggerSection: some View {
        section("Trigger keys",
                footer: "Start dragging a file, then tap one of these keys to open the wheel.") {
            ForEach(Mode.allCases) { mode in
                HStack {
                    Text(mode.title)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { prefs.key(for: mode) },
                        set: { prefs.set($0, for: mode) }
                    )) {
                        ForEach(TriggerKey.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
        }
    }

    private var accentSection: some View {
        section("Accent color") {
            HStack(spacing: 12) {
                ForEach(Theme.allCases) { theme in
                    Button {
                        prefs.theme = theme
                    } label: {
                        Circle()
                            .fill(theme.hover)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(prefs.theme == theme ? 0.85 : 0), lineWidth: 2)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(theme.label)
                }
            }
            .padding(.vertical, 4)
            Text(prefs.theme.label).font(.caption).foregroundColor(.secondary)
        }
    }

    private var generalSection: some View {
        section("General", footer: loginNote.isEmpty ? nil : loginNote) {
            Toggle("Launch at login", isOn: Binding(
                get: { loginEnabled },
                set: { setLogin($0) }
            ))
        }
    }

    private var toolsSection: some View {
        section("Tools") {
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

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        footer: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
            if let footer {
                Text(footer).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private static var loginIsOn: Bool {
        let s = SMAppService.mainApp.status
        return s == .enabled || s == .requiresApproval
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
        loginEnabled = SettingsView.loginIsOn
    }
}
