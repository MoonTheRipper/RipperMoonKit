import AppKit
import SwiftUI

@main
struct RipperMoonKitLauncherApp: App {
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}

private enum LauncherSection: String, CaseIterable, Identifiable {
    case launch
    case backups
    case settings
    case roadmap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launch: "Launch"
        case .backups: "Backups"
        case .settings: "Settings"
        case .roadmap: "Roadmap"
        }
    }

    var symbol: String {
        switch self {
        case .launch: "gamecontroller.fill"
        case .backups: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        case .roadmap: "square.stack.3d.up.fill"
        }
    }
}

private struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selection: LauncherSection? = .launch

    var body: some View {
        NavigationSplitView {
            List(LauncherSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("RipperMoonKit")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderView()

                    switch selection ?? .launch {
                    case .launch:
                        LaunchView()
                    case .backups:
                        BackupsView()
                    case .settings:
                        SettingsView()
                    case .roadmap:
                        RoadmapView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            model.reload()
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        HStack(spacing: 16) {
            Image("RipperMoonKitLogo", bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.18))
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("RipperMoonKit")
                    .font(.largeTitle.weight(.semibold))
                Text(model.statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.reload()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LaunchView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Profile", systemImage: "slider.horizontal.3") {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        FieldLabel("Game")
                        Picker("Game", selection: $model.profile) {
                            Text("Elden Ring ERSC").tag(CompatibilityProfile.eldenRingERSC)
                            Text("Custom").tag(CompatibilityProfile.custom)
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    GridRow {
                        FieldLabel("Prefix")
                        TextField("Prefix", text: $model.prefix)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }

                    GridRow {
                        FieldLabel("Winver")
                        Picker("Winver", selection: $model.winver) {
                            Text("win10").tag("win10")
                            Text("win11").tag("win11")
                            Text("win7").tag("win7")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }
            }

            Panel("Paths", systemImage: "folder.fill") {
                PathEditor(title: "Game Folder", path: $model.gameFolder) {
                    model.chooseGameFolder()
                }
                PathEditor(title: "Runner", path: $model.runnerPath) {
                    model.chooseRunnerFolder()
                }
                PathEditor(title: "Toolkit Source", path: $model.toolkitSourceFolder) {
                    model.chooseToolkitFolder()
                }
            }

            Panel("Options", systemImage: "switch.2") {
                HStack(spacing: 18) {
                    Toggle("No DXR", isOn: $model.noDXR)
                    Toggle("HUD", isOn: $model.hud)
                    Toggle("No esync", isOn: $model.noEsync)
                    Toggle("Native winmm", isOn: $model.nativeWinmm)
                    Toggle("Native steam_api64", isOn: $model.nativeSteamAPI)
                }
                .toggleStyle(.checkbox)
            }

            Panel("Actions", systemImage: "play.circle.fill") {
                HStack(spacing: 12) {
                    Button {
                        model.startSteam()
                    } label: {
                        Label("Start Steam", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.launchGame()
                    } label: {
                        Label("Launch ERSC", systemImage: "gamecontroller.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        model.stopSteam()
                    } label: {
                        Label("Stop Steam", systemImage: "power")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        model.openLogsFolder()
                    } label: {
                        Label("Logs", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Panel("Validation", systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ValidationRow(title: "ersc_launcher.exe", isOK: model.fileExists(inGameFolder: "ersc_launcher.exe"))
                    ValidationRow(title: "eldenring.exe", isOK: model.fileExists(inGameFolder: "eldenring.exe"))
                    ValidationRow(title: "SeamlessCoop", isOK: model.fileExists(inGameFolder: "SeamlessCoop"))
                    ValidationRow(title: "Runner folder", isOK: FileManager.default.fileExists(atPath: model.runnerPath))
                }
            }

            CommandOutputView()
        }
    }
}

private struct BackupsView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selectedBackup: BackupItem.ID?
    @State private var confirmRollback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Update Safeguards", systemImage: "externaldrive.badge.timemachine") {
                HStack(spacing: 12) {
                    Button {
                        model.createBackupOnly()
                    } label: {
                        Label("Create Backup", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.refreshBackups()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        confirmRollback = true
                    } label: {
                        Label("Rollback", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedBackup == nil)
                }
            }

            Panel("Backups", systemImage: "archivebox.fill") {
                List(model.backups, selection: $selectedBackup) { backup in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(backup.name)
                                .font(.headline)
                            Text(backup.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(backup.id)
                }
                .frame(minHeight: 220)
            }
        }
        .confirmationDialog("Rollback selected backup?", isPresented: $confirmRollback) {
            Button("Rollback", role: .destructive) {
                if let selectedBackup {
                    model.rollbackBackup(id: selectedBackup)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Detected Paths", systemImage: "terminal.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow("Config", model.config.configPath)
                    InfoRow("GPTK Home", model.config.gptkHome)
                    InfoRow("Prefix Root", model.config.prefixRoot)
                    InfoRow("External Root", model.config.externalRoot)
                    InfoRow("Steam Library", model.config.steamLibrary)
                    InfoRow("Logs", model.config.logsPath)
                }
            }

            Panel("Commands", systemImage: "chevron.left.forwardslash.chevron.right") {
                VStack(alignment: .leading, spacing: 12) {
                    CommandPreview(title: "Start Steam", command: model.previewStartSteamCommand())
                    CommandPreview(title: "Launch ERSC", command: model.previewLaunchCommand())
                    CommandPreview(title: "Stop Steam", command: model.previewStopSteamCommand())
                }
            }

            Panel("Maintenance", systemImage: "wrench.and.screwdriver.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Button {
                            model.installToolkit()
                        } label: {
                            Label("Install Toolkit", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.installDependencies()
                        } label: {
                            Label("Install GPTK", systemImage: "externaldrive.fill.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.updateFromGitHub()
                        } label: {
                            Label("Update From GitHub", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.installGUIApp()
                        } label: {
                            Label("Install .app", systemImage: "macwindow.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    HStack(spacing: 18) {
                        Toggle("Remove config", isOn: $model.removeConfigOnUninstall)
                        Toggle("Remove Wine prefixes and saves", isOn: $model.removePrefixesOnUninstall)
                    }
                    .toggleStyle(.checkbox)

                    Button(role: .destructive) {
                        model.uninstallToolkit()
                    } label: {
                        Label("Uninstall Toolkit", systemImage: "trash.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct RoadmapView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Compatibility Profiles", systemImage: "square.stack.3d.up.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    RoadmapRow("Profile-based launch settings")
                    RoadmapRow("Per-game validation rules")
                    RoadmapRow("Saved command presets")
                    RoadmapRow("Future game compatibility modules")
                }
            }

            Panel("Native App Plan", systemImage: "macwindow") {
                VStack(alignment: .leading, spacing: 12) {
                    RoadmapRow("Signed app bundle packaging")
                    RoadmapRow("Menu bar launch status")
                    RoadmapRow("Guided first-run setup")
                    RoadmapRow("Safe update and rollback UI")
                }
            }
        }
    }
}

private struct Panel<Content: View>: View {
    private let title: String
    private let systemImage: String
    @ViewBuilder private let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }
}

private struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
    }
}

private struct PathEditor: View {
    let title: String
    @Binding var path: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FieldLabel(title)
            TextField(title, text: $path)
                .textFieldStyle(.roundedBorder)
            Button {
                action()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Choose \(title)")
        }
    }
}

private struct ValidationRow: View {
    let title: String
    let isOK: Bool

    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .red)
            Text(title)
            Spacer()
            Text(isOK ? "Found" : "Missing")
                .foregroundStyle(.secondary)
        }
    }
}

private struct InfoRow: View {
    private let title: String
    private let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

private struct CommandPreview: View {
    let title: String
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct CommandOutputView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        Panel("Activity", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(model.isRunning ? 1 : 0)
                    Text(model.lastResult)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Text(model.commandOutput.isEmpty ? "No activity yet." : model.commandOutput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct RoadmapRow: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.grid.cross.fill")
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
        }
    }
}

@MainActor
private final class LauncherModel: ObservableObject {
    @Published var config = ToolkitConfig.load()
    @Published var profile: CompatibilityProfile = .eldenRingERSC
    @Published var gameFolder: String
    @Published var runnerPath: String
    @Published var toolkitSourceFolder: String
    @Published var prefix: String
    @Published var winver: String
    @Published var noDXR: Bool
    @Published var hud: Bool
    @Published var noEsync: Bool
    @Published var nativeWinmm: Bool
    @Published var nativeSteamAPI: Bool
    @Published var isRunning = false
    @Published var commandOutput = ""
    @Published var lastResult = "Ready"
    @Published var backups: [BackupItem] = []
    @Published var removeConfigOnUninstall = false
    @Published var removePrefixesOnUninstall = false

    private let defaults = UserDefaults.standard

    var statusLine: String {
        config.exists ? "Config loaded from \(config.configPath)" : "Config not found at \(config.configPath)"
    }

    init() {
        let loaded = ToolkitConfig.load()
        config = loaded
        gameFolder = defaults.string(forKey: "gameFolder") ?? "\(loaded.externalRoot)/Games/EldenRing/Game"
        runnerPath = defaults.string(forKey: "runnerPath") ?? "\(loaded.gptkHome)/runners/gptk-dsound-nocap-20260513"
        toolkitSourceFolder = defaults.string(forKey: "toolkitSourceFolder") ?? "\(loaded.home)/Desktop/RipperMoonToolKit"
        prefix = defaults.string(forKey: "prefix") ?? "Steam"
        winver = defaults.string(forKey: "winver") ?? "win10"
        noDXR = defaults.object(forKey: "noDXR") as? Bool ?? true
        hud = defaults.object(forKey: "hud") as? Bool ?? false
        noEsync = defaults.object(forKey: "noEsync") as? Bool ?? false
        nativeWinmm = defaults.object(forKey: "nativeWinmm") as? Bool ?? true
        nativeSteamAPI = defaults.object(forKey: "nativeSteamAPI") as? Bool ?? true
        refreshBackups()
    }

    func reload() {
        persist()
        config = ToolkitConfig.load()
        refreshBackups()
        lastResult = "Refreshed"
    }

    func chooseGameFolder() {
        chooseFolder(current: gameFolder) { gameFolder = $0 }
    }

    func chooseRunnerFolder() {
        chooseFolder(current: runnerPath) { runnerPath = $0 }
    }

    func chooseToolkitFolder() {
        chooseFolder(current: toolkitSourceFolder) { toolkitSourceFolder = $0 }
    }

    func fileExists(inGameFolder relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: URL(fileURLWithPath: gameFolder).appendingPathComponent(relativePath).path)
    }

    func startSteam() {
        persist()
        runShell(
            title: "Start Steam",
            command: previewStartSteamCommand(detached: true),
            detached: true
        )
    }

    func stopSteam() {
        persist()
        runShell(title: "Stop Steam", command: previewStopSteamCommand())
    }

    func launchGame() {
        persist()
        runShell(
            title: "Launch ERSC",
            command: previewLaunchCommand(detached: true),
            detached: true
        )
    }

    func createBackupOnly() {
        persist()
        runShell(
            title: "Create Backup",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps --backup-only",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installToolkit() {
        persist()
        runShell(
            title: "Install Toolkit",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installDependencies() {
        persist()
        runShell(
            title: "Install GPTK",
            command: "cd \(toolkitSourceFolder.shellQuoted) && RIPPERMOON_OPEN_GPTK_PAGE=1 ./install.zsh",
            completion: { [weak self] in self?.reload() }
        )
    }

    func installGUIApp() {
        persist()
        runShell(
            title: "Install .app",
            command: "cd \(toolkitSourceFolder.shellQuoted) && zsh scripts/install-gui-app.zsh",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func updateFromGitHub() {
        persist()
        let command = """
        cd \(toolkitSourceFolder.shellQuoted) && \
        git fetch --tags origin && \
        if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then git pull --ff-only origin main; else echo "Already up to date."; fi && \
        ./install.zsh --skip-deps && \
        zsh scripts/install-gui-app.zsh
        """
        runShell(
            title: "Update From GitHub",
            command: command,
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func uninstallToolkit() {
        persist()
        var args: [String] = []
        if removeConfigOnUninstall {
            args.append("--remove-config")
        }
        if removePrefixesOnUninstall {
            args.append("--remove-prefixes")
        }

        runShell(
            title: "Uninstall Toolkit",
            command: "cd \(toolkitSourceFolder.shellQuoted) && zsh scripts/uninstall.zsh \(args.joined(separator: " "))",
            completion: { [weak self] in self?.reload() }
        )
    }

    func rollbackBackup(id: BackupItem.ID) {
        guard let backup = backups.first(where: { $0.id == id }) else { return }
        runShell(
            title: "Rollback",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --rollback \(backup.name.shellQuoted)",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func refreshBackups() {
        let backupRoot = URL(fileURLWithPath: config.gptkHome)
            .appendingPathComponent("backups")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        backups = contents
            .filter { $0.lastPathComponent.hasPrefix("rippermoon-update-") }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return BackupItem(name: url.lastPathComponent, path: url.path, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    func openLogsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.logsPath))
    }

    func previewStartSteamCommand(detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/RipperMoonKitLauncher-steam.log"
        let envPart = runnerEnvAssignment()
        let base = "\(sourceConfig); nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log >> \(logPath.shellQuoted) 2>&1 &"
        return detached ? base : "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log"
    }

    func previewStopSteamCommand() -> String {
        "\(sourceConfig); \(config.gptkSteamPath.shellQuoted) --kill"
    }

    func previewLaunchCommand(detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/ERSC-gui.log"
        let overrides = dllOverrides()
        var args: [String] = [
            "--prefix", prefix,
            "--set-winver", winver
        ]

        if noDXR { args.append("--no-dxr") }
        if noEsync { args.append("--no-esync") }
        if hud { args.append("--hud") }

        args.append(contentsOf: ["--log-file", logPath, "--", "./ersc_launcher.exe"])

        let launch = "cd \(gameFolder.shellQuoted) && nohup env \(runnerEnvAssignment()) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " ")) >> \(logPath.shellQuoted) 2>&1 &"
        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); cd \(gameFolder.shellQuoted) && env \(runnerEnvAssignment()) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))"
    }

    private var sourceConfig: String {
        "[[ -r \(config.configPath.shellQuoted) ]] && source \(config.configPath.shellQuoted)"
    }

    private func runnerEnvAssignment() -> String {
        runnerPath.isEmpty ? "" : "GPTK_WINE_HOME=\(runnerPath.shellQuoted)"
    }

    private func dllOverrides() -> String {
        var values: [String] = []
        if nativeWinmm { values.append("winmm=n,b") }
        if nativeSteamAPI { values.append("steam_api64=n,b") }
        return values.joined(separator: ";")
    }

    private func chooseFolder(current: String, assign: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: current)
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
            persist()
        }
    }

    private func persist() {
        defaults.set(gameFolder, forKey: "gameFolder")
        defaults.set(runnerPath, forKey: "runnerPath")
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        defaults.set(prefix, forKey: "prefix")
        defaults.set(winver, forKey: "winver")
        defaults.set(noDXR, forKey: "noDXR")
        defaults.set(hud, forKey: "hud")
        defaults.set(noEsync, forKey: "noEsync")
        defaults.set(nativeWinmm, forKey: "nativeWinmm")
        defaults.set(nativeSteamAPI, forKey: "nativeSteamAPI")
    }

    private func runShell(title: String, command: String, detached: Bool = false, completion: (() -> Void)? = nil) {
        isRunning = true
        lastResult = "\(title) running"
        commandOutput = "$ \(command)\n"

        Task {
            let result = await ShellExecutor.run(command)
            isRunning = false
            commandOutput += result.output
            if let error = result.error {
                commandOutput += "\(error)\n"
                lastResult = "\(title) failed"
            } else {
                lastResult = detached ? "\(title) sent" : "\(title) finished with status \(result.status)"
            }
            completion?()
        }
    }
}

private enum ShellExecutor {
    static func run(_ command: String) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(status: process.terminationStatus, output: output, error: nil))
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: "", error: error.localizedDescription))
                }
            }
        }
    }
}

private struct ShellResult: Sendable {
    let status: Int32
    let output: String
    let error: String?
}

private enum CompatibilityProfile: String, CaseIterable, Hashable {
    case eldenRingERSC
    case custom
}

private struct BackupItem: Identifiable, Hashable {
    let name: String
    let path: String
    let modified: Date

    var id: String { path }
}

private struct ToolkitConfig {
    let home: String
    let configPath: String
    let values: [String: String]
    let exists: Bool

    var gptkHome: String { expand(values["GPTK_HOME"] ?? "$HOME/GPTK") }
    var prefixRoot: String { expand(values["GPTK_PREFIX_ROOT"] ?? "$HOME/WinePrefixes") }
    var externalRoot: String { expand(values["GPTK_EXTERNAL_ROOT"] ?? "/Volumes/GameCoreApp") }
    var steamLibrary: String { expand(values["GPTK_STEAM_LIBRARY"] ?? "$GPTK_EXTERNAL_ROOT/SteamLibrary") }
    var logsPath: String { expand(values["GPTK_LOG_DIR"] ?? "$GPTK_HOME/logs") }
    var gptkLaunchPath: String { "\(home)/bin/gptk-launch" }
    var gptkSteamPath: String { "\(home)/bin/gptk-steam" }

    static func load() -> ToolkitConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.rippermoon-gptk.env"
        let url = URL(fileURLWithPath: configPath)
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return ToolkitConfig(
            home: home,
            configPath: configPath,
            values: parse(text),
            exists: FileManager.default.fileExists(atPath: configPath)
        )
    }

    private func expand(_ raw: String) -> String {
        var result = raw.strippedShellQuotes
        for _ in 0..<6 {
            result = result
                .replacingOccurrences(of: "${HOME}", with: home)
                .replacingOccurrences(of: "$HOME", with: home)

            for (key, value) in values {
                let expandedValue = value.strippedShellQuotes
                    .replacingOccurrences(of: "${HOME}", with: home)
                    .replacingOccurrences(of: "$HOME", with: home)
                result = result
                    .replacingOccurrences(of: "${\(key)}", with: expandedValue)
                    .replacingOccurrences(of: "$\(key)", with: expandedValue)
            }
        }
        return result
    }

    private static func parse(_ text: String) -> [String: String] {
        var output: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line.removeFirst("export ".count)
            }
            guard let equalIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                output[key] = value.strippedShellQuotes
            }
        }
        return output
    }
}

private extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var strippedShellQuotes: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2 {
            let first = value.first
            let last = value.last
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value.removeFirst()
                value.removeLast()
            }
        }
        return value
    }
}
