// Claude Profiles: a menu bar app to open, focus or create Claude Desktop profiles side by side.
// A profile is "~/Library/Application Support/Claude-<Name>" with a ".claude-config-dir"
// file holding the CLAUDE_CONFIG_DIR its Code sessions use. "Main" is the default
// instance (default data folder, ~/.claude).
import AppKit
import ServiceManagement
import SwiftUI

let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support")
let claudeBin = "/Applications/Claude.app/Contents/MacOS/Claude"
let home = FileManager.default.homeDirectoryForCurrentUser.path

struct Profile: Identifiable, Equatable {
    let name: String
    let dataDir: URL?  // nil = Main
    let configDir: String
    var pid: pid_t?
    var id: String { name }
    var commandLine: String {
        dataDir.map { "\(claudeBin) --user-data-dir=\($0.path)" } ?? claudeBin
    }
}

func shortPath(_ p: String) -> String {
    p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
}

final class Store: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let running = runningCommandLines()
        var list = [Profile(name: "Main", dataDir: nil, configDir: home + "/.claude")]
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: supportDir, includingPropertiesForKeys: nil)) ?? []
        for dir in dirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where dir.lastPathComponent.hasPrefix("Claude-") {
            let cfgFile = dir.appendingPathComponent(".claude-config-dir")
            guard let cfg = try? String(contentsOf: cfgFile, encoding: .utf8) else { continue }
            list.append(Profile(
                name: String(dir.lastPathComponent.dropFirst("Claude-".count)),
                dataDir: dir,
                configDir: cfg.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        for i in list.indices { list[i].pid = running[list[i].commandLine] }
        if list != profiles { profiles = list }
    }

    // Exact command line -> pid for every running Claude Desktop main process.
    private func runningCommandLines() -> [String: pid_t] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axo", "pid=,command="]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        var map: [String: pid_t] = [:]
        for line in out.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard let sp = t.firstIndex(of: " "), let pid = pid_t(t[..<sp]) else { continue }
            let cmd = t[sp...].trimmingCharacters(in: .whitespaces)
            if cmd.hasPrefix(claudeBin) { map[cmd] = pid }
        }
        return map
    }

    func open(_ profile: Profile) {
        if let pid = profile.pid, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
            return
        }
        var args = ["-n", "-a", "Claude"]
        if let dir = profile.dataDir {
            args += ["--env", "CLAUDE_CONFIG_DIR=\(profile.configDir)", "--args", "--user-data-dir=\(dir.path)"]
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = args
        try? p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
    }

    func reveal(_ profile: Profile) {
        let url = profile.dataDir ?? supportDir.appendingPathComponent("Claude")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // Returns an error message, or nil when the profile was created and opened.
    func create(name: String, configDir: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let valid = trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !trimmed.isEmpty, valid else { return "Use only letters, numbers, - or _." }
        if trimmed.lowercased() == "main"
            || profiles.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return "A profile named \(trimmed) already exists."
        }
        let dir = supportDir.appendingPathComponent("Claude-\(trimmed)")
        let cfg = configDir.hasPrefix("~/") ? home + configDir.dropFirst(1) : configDir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: cfg, withIntermediateDirectories: true)
            try (cfg + "\n").write(to: dir.appendingPathComponent(".claude-config-dir"),
                                   atomically: true, encoding: .utf8)
        } catch {
            return "Could not create it: \(error.localizedDescription)"
        }
        refresh()
        if let p = profiles.first(where: { $0.name == trimmed }) { open(p) }
        return nil
    }

    // Asks for confirmation, quits the profile if it is open and moves its folders to the Trash.
    func confirmDelete(_ profile: Profile) {
        guard let dataDir = profile.dataDir else { return }
        let configShared = profile.configDir == home + "/.claude"
            || profiles.contains { $0.id != profile.id && $0.configDir == profile.configDir }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete the \(profile.name) profile?"
        alert.informativeText = """
            Its Claude window loses the sign-in, settings and local data saved in \
            \(shortPath(dataDir.path)). \(profile.pid != nil ? "The open window will be closed. " : "")\
            Your chats stay in your Claude account.

            Everything is moved to the Trash, so you can still recover it from there.
            """
        let checkbox = NSButton(checkboxWithTitle: "Also delete its Claude Code folder (\(shortPath(profile.configDir)))",
                                target: nil, action: nil)
        checkbox.toolTip = "Settings, skills, plugins and Claude Code session history for this profile"
        if configShared {
            checkbox.state = .off
            checkbox.isEnabled = false
            checkbox.title = "Its Claude Code folder is shared with another profile and is kept"
        }
        alert.accessoryView = checkbox
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let pid = profile.pid, let app = NSRunningApplication(processIdentifier: pid) {
            app.terminate()
            let deadline = Date().addingTimeInterval(15)
            while !app.isTerminated && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
            guard app.isTerminated else {
                showError("\(profile.name) is still open. Quit it and try again.")
                return
            }
        }
        do {
            try FileManager.default.trashItem(at: dataDir, resultingItemURL: nil)
            if checkbox.state == .on, FileManager.default.fileExists(atPath: profile.configDir) {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: profile.configDir), resultingItemURL: nil)
            }
        } catch {
            showError("Could not delete it: \(error.localizedDescription)")
        }
        refresh()
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("launch at login: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Views

// Monochrome version of the app icon for the menu bar: an asterisk on the front card of a stack.
let menuBarIcon: NSImage = {
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        NSColor.black.setStroke()
        NSColor.black.setFill()
        // Back cards: outline corners peeking above and to the right.
        for offset in [CGFloat(4), 2] {
            let back = NSBezierPath(roundedRect: NSRect(x: 1 + offset, y: 1 + offset, width: 12, height: 12),
                                    xRadius: 3, yRadius: 3)
            back.lineWidth = 1.2
            back.stroke()
        }
        // Front card, filled, with the asterisk cut out of it.
        let front = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 12, height: 12), xRadius: 3, yRadius: 3)
        front.fill()
        NSGraphicsContext.current?.compositingOperation = .clear
        let star = NSBezierPath()
        let c = NSPoint(x: 7, y: 7)
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            star.move(to: NSPoint(x: c.x + cos(a) * 1.3, y: c.y + sin(a) * 1.3))
            star.line(to: NSPoint(x: c.x + cos(a) * 4, y: c.y + sin(a) * 4))
        }
        star.lineWidth = 1.3
        star.lineCapStyle = .round
        star.stroke()
        return true
    }
    img.isTemplate = true
    return img
}()

let tilePalette: [Color] = [.indigo, .teal, .pink, .green, .blue, .purple, .mint]

func tileColor(_ name: String) -> Color {
    if name == "Main" { return .orange }
    let h = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xffff }
    return tilePalette[h % tilePalette.count]
}

struct ProfileRow: View {
    let profile: Profile
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tileColor(profile.name).gradient, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        if profile.pid != nil {
                            Circle().fill(.green)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.background, lineWidth: 2))
                                .offset(x: 2, y: 2)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name).font(.system(size: 13, weight: .semibold))
                    Text(shortPath(profile.configDir))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(profile.pid != nil ? "Go to" : "Open")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hover ? .primary : .secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(hover ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(profile.pid != nil ? "Go to the \(profile.name) window" : "Open \(profile.name)")
    }
}

struct NewProfileForm: View {
    @ObservedObject var store: Store
    let done: () -> Void
    @State private var name = ""
    @State private var configDir = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onChange(of: name) { old, new in
                    let auto = old.isEmpty ? "" : "~/.claude-\(old.lowercased())"
                    if configDir.isEmpty || configDir == auto {
                        configDir = new.isEmpty ? "" : "~/.claude-\(new.lowercased())"
                    }
                }
            TextField("Claude Code folder", text: $configDir)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text("How to sign in while other profiles are open")
                    .font(.system(size: 11, weight: .semibold))
                Text("""
                    1. Choose Continue with email, not Google.
                    2. When asked, pick the sign-in code option.
                    3. Open the link Anthropic emails you in the browser.
                    4. If the browser offers to open Claude, decline and choose to sign in with a code.
                    5. Type the code it shows into this profile's window.
                    """)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", action: done).keyboardShortcut(.cancelAction)
                Button("Create and open") {
                    error = store.create(name: name, configDir: configDir)
                    if error == nil { done() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || configDir.isEmpty)
            }
        }
        .onAppear { nameFocused = true }
    }
}

struct PanelView: View {
    @ObservedObject var store: Store
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 1) {
                ForEach(store.profiles) { p in
                    ProfileRow(profile: p) { store.open(p) }
                        .contextMenu {
                            Button(p.pid != nil ? "Go to window" : "Open") { store.open(p) }
                            Button("Show folder in Finder") { store.reveal(p) }
                            if p.dataDir != nil {
                                Divider()
                                Button("Delete profile…", role: .destructive) { store.confirmDelete(p) }
                            }
                        }
                }
            }
            .padding(6)
            Divider()
            Group {
                if creating {
                    NewProfileForm(store: store) { creating = false }
                        .padding(12)
                } else {
                    HStack {
                        Button { creating = true } label: {
                            Label("New profile", systemImage: "plus")
                        }
                        Spacer()
                        Menu {
                            Toggle("Open at login", isOn: Binding(
                                get: { store.launchAtLogin },
                                set: { store.setLaunchAtLogin($0) }))
                            Divider()
                            Button("Quit Claude Profiles") { NSApp.terminate(nil) }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
        }
        .frame(width: 300)
        .onAppear { store.refresh() }
    }
}

@main
struct ClaudeProfilesApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            Image(nsImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
