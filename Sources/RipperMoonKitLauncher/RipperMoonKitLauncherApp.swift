import AppKit
import SwiftUI

@main
struct RipperMoonKitLauncherApp: App {
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}

private enum SidebarSelection: Hashable {
    case profile(UUID)
    case backups
    case settings
}

private struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selection: SidebarSelection?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Section("Apps & Games") {
                        ForEach(model.profiles) { profile in
                            Label(profile.name, systemImage: profile.systemImage)
                                .tag(SidebarSelection.profile(profile.id))
                        }
                    }

                    Section("Toolkit") {
                        Label("Backups", systemImage: "clock.arrow.circlepath")
                            .tag(SidebarSelection.backups)
                        Label("Settings", systemImage: "gearshape.fill")
                            .tag(SidebarSelection.settings)
                    }
                }

                Divider()

                Button {
                    let profile = model.addProfile()
                    selection = .profile(profile.id)
                } label: {
                    Label("Add App", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(12)
            }
            .navigationTitle("RipperMoonKit")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderView()

                    switch selection ?? model.defaultSelection {
                    case .profile(let id):
                        if let profile = model.profileBinding(id: id) {
                            ProfileDetailView(profile: profile)
                        } else {
                            EmptyStateView(title: "Profile Missing", detail: "Choose another app or add a new one.")
                        }
                    case .backups:
                        BackupsView()
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            model.reload()
            selection = selection ?? model.defaultSelection
        }
        .sheet(isPresented: $model.showSetupGuide) {
            SetupGuideView()
                .environmentObject(model)
                .frame(width: 620)
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

private struct ProfileDetailView: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("App Settings", systemImage: profile.systemImage) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        FieldLabel("Name")
                        TextField("Name", text: $profile.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        FieldLabel("Prefix")
                        TextField("Prefix", text: $profile.prefix)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }

                    GridRow {
                        FieldLabel("Winver")
                        Picker("Winver", selection: $profile.winver) {
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
                PathEditor(title: "Folder", path: $profile.gameFolder) {
                    model.chooseFolder(current: profile.gameFolder) { profile.gameFolder = $0 }
                }

                HStack(spacing: 10) {
                    FieldLabel("Executable")
                    TextField("Executable", text: $profile.executable)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        model.chooseExecutable(for: &profile)
                    } label: {
                        Image(systemName: "doc.badge.gearshape")
                    }
                    .buttonStyle(.bordered)
                    .help("Choose executable")
                }

                PathEditor(title: "Runner", path: $profile.runnerPath) {
                    model.chooseFolder(current: profile.runnerPath) { profile.runnerPath = $0 }
                }
            }

            Panel("Launch Options", systemImage: "switch.2") {
                HStack(spacing: 18) {
                    Toggle("Steam required", isOn: $profile.requiresSteam)
                    Toggle("No DXR", isOn: $profile.noDXR)
                    Toggle("MetalFX/DLSS", isOn: Binding(
                        get: { profile.metalFX ?? false },
                        set: { profile.metalFX = $0 }
                    ))
                    Toggle("HUD", isOn: $profile.hud)
                    Toggle("No esync", isOn: $profile.noEsync)
                }
                .toggleStyle(.checkbox)

                HStack(spacing: 18) {
                    Toggle("Native winmm", isOn: $profile.nativeWinmm)
                    Toggle("Native steam_api64", isOn: $profile.nativeSteamAPI)
                }
                .toggleStyle(.checkbox)

                HStack(spacing: 10) {
                    FieldLabel("Arguments")
                    TextField("Extra arguments", text: $profile.extraArguments)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Panel("Actions", systemImage: "play.circle.fill") {
                HStack(spacing: 12) {
                    Button {
                        model.startSteam(for: profile)
                    } label: {
                        Label("Start Steam", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!profile.requiresSteam)

                    Button {
                        model.launch(profile)
                    } label: {
                        Label("Launch", systemImage: "gamecontroller.fill")
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

                    Spacer()

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Panel("Validation", systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ValidationRow(title: profile.executable, isOK: model.fileExists(profile.executable, in: profile))
                    ForEach(profile.requiredFiles, id: \.self) { item in
                        ValidationRow(title: item, isOK: model.fileExists(item, in: profile))
                    }
                    ValidationRow(title: "Runner folder", isOK: profile.runnerPath.isEmpty || FileManager.default.fileExists(atPath: profile.runnerPath))
                }
            }

            Panel("Commands", systemImage: "chevron.left.forwardslash.chevron.right") {
                VStack(alignment: .leading, spacing: 12) {
                    if profile.requiresSteam {
                        CommandPreview(title: "Start Steam", command: model.previewStartSteamCommand(for: profile))
                    }
                    CommandPreview(title: "Launch", command: model.previewLaunchCommand(for: profile))
                    if profile.requiresSteam {
                        CommandPreview(title: "Stop Steam", command: model.previewStopSteamCommand())
                    }
                }
            }

            CommandOutputView()
        }
        .onChange(of: profile) { _, _ in
            model.persistProfiles()
        }
        .confirmationDialog("Delete this app profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                model.deleteProfile(id: profile.id)
            }
            Button("Cancel", role: .cancel) {}
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
            Panel("Paths", systemImage: "folder.fill") {
                PathEditor(title: "GPTK Home", path: $model.pathSettings.gptkHome) {
                    model.chooseFolder(current: model.pathSettings.gptkHome) { model.pathSettings.gptkHome = $0 }
                }
                PathEditor(title: "Prefix Root", path: $model.pathSettings.prefixRoot) {
                    model.chooseFolder(current: model.pathSettings.prefixRoot) { model.pathSettings.prefixRoot = $0 }
                }
                PathEditor(title: "Games Root", path: $model.pathSettings.gamesRoot) {
                    model.chooseFolder(current: model.pathSettings.gamesRoot) { model.pathSettings.gamesRoot = $0 }
                }
                PathEditor(title: "External Root", path: $model.pathSettings.externalRoot) {
                    model.chooseFolder(current: model.pathSettings.externalRoot) { model.pathSettings.externalRoot = $0 }
                }
                PathEditor(title: "Steam Library", path: $model.pathSettings.steamLibrary) {
                    model.chooseFolder(current: model.pathSettings.steamLibrary) { model.pathSettings.steamLibrary = $0 }
                }
                PathEditor(title: "Toolkit Source", path: $model.toolkitSourceFolder) {
                    model.chooseFolder(current: model.toolkitSourceFolder) { model.toolkitSourceFolder = $0 }
                }

                HStack {
                    Spacer()
                    Button {
                        model.savePathSettings()
                    } label: {
                        Label("Save Paths", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Panel("Drive Mappings", systemImage: "externaldrive.connected.to.line.below.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($model.driveMaps) { $drive in
                        HStack(spacing: 10) {
                            TextField("Letter", text: $drive.letter)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                            TextField("Path", text: $drive.path)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                model.chooseFolder(current: drive.path) { drive.path = $0 }
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) {
                                model.removeDriveMap(id: drive.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack {
                        Button {
                            model.addDriveMap()
                        } label: {
                            Label("Add Drive", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            model.saveDriveMaps()
                        } label: {
                            Label("Save Drives", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
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

            CommandOutputView()
        }
    }
}

private struct SetupGuideView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("RipperMoonKitLogo", bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("First Run Setup")
                        .font(.title2.weight(.semibold))
                    Text("Initialize the toolkit paths and Apple Game Porting Toolkit before launching games.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SetupRow(title: "Toolkit scripts", isOK: FileManager.default.fileExists(atPath: model.config.gptkLaunchPath))
                SetupRow(title: "GPTK runtime", isOK: model.config.hasLocalGPTK)
                SetupRow(title: "Config file", isOK: model.config.exists)
            }

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
                    model.openGPTKPage()
                } label: {
                    Label("Apple GPTK Page", systemImage: "safari.fill")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Spacer()
                Button {
                    model.dismissSetupGuide()
                } label: {
                    Text("Done")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

private struct SetupRow: View {
    let title: String
    let isOK: Bool

    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isOK ? .green : .orange)
            Text(title)
            Spacer()
            Text(isOK ? "Ready" : "Needs setup")
                .foregroundStyle(.secondary)
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

private struct EmptyStateView: View {
    let title: String
    let detail: String

    var body: some View {
        Panel(title, systemImage: "questionmark.folder.fill") {
            Text(detail)
                .foregroundStyle(.secondary)
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
            .frame(width: 112, alignment: .leading)
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

@MainActor
private final class LauncherModel: ObservableObject {
    @Published var config = ToolkitConfig.load()
    @Published var profiles: [GameProfile]
    @Published var pathSettings: PathSettings
    @Published var driveMaps: [DriveMap]
    @Published var toolkitSourceFolder: String
    @Published var isRunning = false
    @Published var commandOutput = ""
    @Published var lastResult = "Ready"
    @Published var backups: [BackupItem] = []
    @Published var removeConfigOnUninstall = false
    @Published var removePrefixesOnUninstall = false
    @Published var showSetupGuide = false

    private let defaults = UserDefaults.standard

    var defaultSelection: SidebarSelection {
        if let id = profiles.first?.id {
            return .profile(id)
        }
        return .settings
    }

    var statusLine: String {
        config.exists ? "Config loaded from \(config.configPath)" : "Config not found at \(config.configPath)"
    }

    init() {
        let loaded = ToolkitConfig.load()
        config = loaded
        profiles = Self.loadProfiles(config: loaded, defaults: defaults)
        pathSettings = PathSettings(config: loaded)
        driveMaps = DriveMap.parse(loaded.values["GPTK_DRIVE_MAPS"] ?? "")
        toolkitSourceFolder = defaults.string(forKey: "toolkitSourceFolder") ?? "\(loaded.home)/Desktop/RipperMoonToolKit"
        refreshBackups()
        showSetupGuide = !defaults.bool(forKey: "setupGuideSeen.v2") || !loaded.hasLocalGPTK
        persistProfiles()
    }

    func reload() {
        persistProfiles()
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        config = ToolkitConfig.load()
        profiles = Self.repairProfiles(profiles, config: config)
        persistProfiles()
        pathSettings = PathSettings(config: config)
        driveMaps = DriveMap.parse(config.values["GPTK_DRIVE_MAPS"] ?? "")
        refreshBackups()
        lastResult = "Refreshed"
    }

    func profileBinding(id: UUID) -> Binding<GameProfile>? {
        guard profiles.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.profiles.first(where: { $0.id == id }) ?? GameProfile.empty(config: self.config) },
            set: { newValue in
                if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                    self.profiles[index] = newValue
                    self.persistProfiles()
                }
            }
        )
    }

    func addProfile() -> GameProfile {
        let profile = GameProfile.empty(config: config)
        profiles.append(profile)
        persistProfiles()
        return profile
    }

    func deleteProfile(id: UUID) {
        guard profiles.count > 1 else {
            lastResult = "At least one app profile is required"
            return
        }
        profiles.removeAll { $0.id == id }
        persistProfiles()
    }

    func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "gameProfiles.v1")
        }
    }

    func chooseFolder(current: String, assign: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: current)
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
        }
    }

    func chooseExecutable(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        if panel.runModal() == .OK, let url = panel.url {
            profile.gameFolder = url.deletingLastPathComponent().path
            profile.executable = url.lastPathComponent
            persistProfiles()
        }
    }

    func fileExists(_ relativePath: String, in profile: GameProfile) -> Bool {
        guard !relativePath.isEmpty else { return false }
        let path = URL(fileURLWithPath: profile.gameFolder).appendingPathComponent(relativePath).path
        return FileManager.default.fileExists(atPath: path)
    }

    func startSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Start Steam",
            command: previewStartSteamCommand(for: profile, detached: true),
            detached: true
        )
    }

    func stopSteam() {
        runShell(title: "Stop Steam", command: previewStopSteamCommand())
    }

    func launch(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Launch \(profile.name)",
            command: previewLaunchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func createBackupOnly() {
        runShell(
            title: "Create Backup",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps --backup-only",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installToolkit() {
        runShell(
            title: "Install Toolkit",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installDependencies() {
        runShell(
            title: "Install GPTK",
            command: "cd \(toolkitSourceFolder.shellQuoted) && RIPPERMOON_OPEN_GPTK_PAGE=1 ./install.zsh",
            completion: { [weak self] in self?.reload() }
        )
    }

    func updateFromGitHub() {
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
            completion: { [weak self] in self?.reload() }
        )
    }

    func uninstallToolkit() {
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
        let backupRoot = URL(fileURLWithPath: config.gptkHome).appendingPathComponent("backups")
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

    func openGPTKPage() {
        NSWorkspace.shared.open(URL(string: config.gptkDownloadPage)!)
    }

    func dismissSetupGuide() {
        defaults.set(true, forKey: "setupGuideSeen.v2")
        showSetupGuide = false
    }

    func addDriveMap() {
        let used = Set(driveMaps.map { $0.letter.uppercased() })
        let letter = (["D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "T", "U", "V", "W", "Y", "Z"].first { !used.contains($0) }) ?? "D"
        driveMaps.append(DriveMap(letter: letter, path: config.externalRoot))
    }

    func removeDriveMap(id: UUID) {
        driveMaps.removeAll { $0.id == id }
    }

    func savePathSettings() {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        saveEnvValues([
            "GPTK_HOME": envPath(pathSettings.gptkHome),
            "GPTK_PREFIX_ROOT": envPath(pathSettings.prefixRoot),
            "GPTK_GAMES_ROOT": envPath(pathSettings.gamesRoot),
            "GPTK_EXTERNAL_ROOT": envPath(pathSettings.externalRoot),
            "GPTK_STEAM_LIBRARY": envPath(pathSettings.steamLibrary)
        ])
    }

    func saveDriveMaps() {
        var seen = Set<String>()
        var parts: [String] = []

        for map in driveMaps {
            let letter = map.letter.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let path = map.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard letter.count == 1, letter != "C", !path.isEmpty, !seen.contains(letter) else {
                continue
            }
            seen.insert(letter)
            parts.append("\(letter)=\(envPath(path))")
        }

        driveMaps = parts.compactMap { DriveMap(line: $0) }
        saveEnvValues(["GPTK_DRIVE_MAPS": parts.joined(separator: ";")])
    }

    func previewStartSteamCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-steam.log"
        let envPart = runnerEnvAssignment(for: profile)
        let base = "\(sourceConfig); nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log >> \(logPath.shellQuoted) 2>&1 &"
        return detached ? base : "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log"
    }

    func previewStopSteamCommand() -> String {
        "\(sourceConfig); \(config.gptkSteamPath.shellQuoted) --kill"
    }

    func previewLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: ["--log-file", logPath, "--", "./\(profile.executable)"])

        let extra = profile.extraArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraPart = extra.isEmpty ? "" : " \(extra)"
        let overrides = dllOverrides(for: profile)
        let launch = "cd \(profile.gameFolder.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart) >> \(logPath.shellQuoted) 2>&1 &"

        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); cd \(profile.gameFolder.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart)"
    }

    private var sourceConfig: String {
        "[[ -r \(config.configPath.shellQuoted) ]] && source \(config.configPath.shellQuoted)"
    }

    private func runnerEnvAssignment(for profile: GameProfile) -> String {
        profile.runnerPath.isEmpty ? "" : "GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)"
    }

    private func dllOverrides(for profile: GameProfile) -> String {
        var values: [String] = []
        if profile.nativeWinmm { values.append("winmm=n,b") }
        if profile.nativeSteamAPI { values.append("steam_api64=n,b") }
        if profile.metalFX == true {
            values.append("nvapi64=b,n")
            values.append("nvngx=b,n")
        }
        return values.joined(separator: ";")
    }

    private func envPath(_ path: String) -> String {
        if path == config.home {
            return "$HOME"
        }
        if path.hasPrefix(config.home + "/") {
            return "$HOME/" + path.dropFirst(config.home.count + 1)
        }
        return path
    }

    private func saveEnvValues(_ values: [String: String]) {
        do {
            try backupConfigForEdit()
            var lines: [String]
            if FileManager.default.fileExists(atPath: config.configPath) {
                let text = try String(contentsOfFile: config.configPath, encoding: .utf8)
                lines = text.components(separatedBy: .newlines)
            } else {
                lines = ["# RipperMoonToolKit configuration"]
            }

            var remaining = Set(values.keys)
            for index in lines.indices {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                let body = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst("export ".count)) : trimmed
                guard let equal = body.firstIndex(of: "=") else { continue }
                let key = String(body[..<equal]).trimmingCharacters(in: .whitespaces)
                if let value = values[key] {
                    lines[index] = "export \(key)=\"\(value.envEscaped)\""
                    remaining.remove(key)
                }
            }

            for key in remaining.sorted() {
                lines.append("export \(key)=\"\(values[key, default: ""].envEscaped)\"")
            }

            try lines.joined(separator: "\n").write(toFile: config.configPath, atomically: true, encoding: .utf8)
            config = ToolkitConfig.load()
            pathSettings = PathSettings(config: config)
            lastResult = "Saved config"
        } catch {
            lastResult = "Config save failed"
            commandOutput += "\(error.localizedDescription)\n"
        }
    }

    private func backupConfigForEdit() throws {
        guard FileManager.default.fileExists(atPath: config.configPath) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(config.gptkHome)/backups/env-edit-\(stamp)/.rippermoon-gptk.env"
        try FileManager.default.createDirectory(atPath: (backup as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: config.configPath, toPath: backup)
    }

    private func runShell(title: String, command: String, detached: Bool = false, completion: (() -> Void)? = nil) {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
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

    private static func loadProfiles(config: ToolkitConfig, defaults: UserDefaults) -> [GameProfile] {
        if let data = defaults.data(forKey: "gameProfiles.v1"),
           let profiles = try? JSONDecoder().decode([GameProfile].self, from: data),
           !profiles.isEmpty {
            return repairProfiles(profiles, config: config)
        }
        return repairProfiles([GameProfile.eldenRing(config: config, defaults: defaults)], config: config)
    }

    private static func repairProfiles(_ profiles: [GameProfile], config: ToolkitConfig) -> [GameProfile] {
        profiles.map { $0.repairedForCurrentToolkit(config: config) }
    }

    private func repairedProfile(_ profile: GameProfile) -> GameProfile {
        let repaired = profile.repairedForCurrentToolkit(config: config)
        guard repaired != profile else { return profile }

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = repaired
            persistProfiles()
        }
        return repaired
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

private struct GameProfile: Codable, Identifiable, Hashable {
    private static let eldenRingERSCID = UUID(uuidString: "00000000-0000-0000-0000-000000000480") ?? UUID()

    var id: UUID
    var name: String
    var prefix: String
    var gameFolder: String
    var executable: String
    var runnerPath: String
    var winver: String
    var requiresSteam: Bool
    var noDXR: Bool
    var metalFX: Bool?
    var hud: Bool
    var noEsync: Bool
    var nativeWinmm: Bool
    var nativeSteamAPI: Bool
    var extraArguments: String
    var requiredFiles: [String]
    var systemImage: String

    var safeName: String {
        name.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
    }

    var isEldenRingERSC: Bool {
        id == Self.eldenRingERSCID ||
            executable.localizedCaseInsensitiveContains("ersc_launcher.exe") ||
            name.localizedCaseInsensitiveContains("elden ring ersc")
    }

    func repairedForCurrentToolkit(config: ToolkitConfig) -> GameProfile {
        guard isEldenRingERSC else { return self }

        var repaired = self
        let patchedRunner = "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513"
        let patchedRunnerExists = FileManager.default.isExecutableFile(atPath: "\(patchedRunner)/bin/wine64")
        let stockRunnerPaths = [
            config.gptkWineHome,
            "\(config.gptkHome)/apps/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
        ]

        repaired.prefix = repaired.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired.prefix
        repaired.executable = "ersc_launcher.exe"
        repaired.winver = repaired.winver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "win10" : repaired.winver
        repaired.requiresSteam = true
        repaired.noDXR = true
        repaired.noEsync = false
        repaired.nativeWinmm = true
        repaired.nativeSteamAPI = true
        repaired.systemImage = "gamecontroller.fill"

        for required in ["eldenring.exe", "SeamlessCoop"] where !repaired.requiredFiles.contains(required) {
            repaired.requiredFiles.append(required)
        }

        let runner = repaired.runnerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let runnerMissing = runner.isEmpty || !FileManager.default.isExecutableFile(atPath: "\(runner)/bin/wine64")
        let runnerIsStock = stockRunnerPaths.contains(runner)
        if patchedRunnerExists, runnerMissing || runnerIsStock {
            repaired.runnerPath = patchedRunner
        }

        return repaired
    }

    static func eldenRing(config: ToolkitConfig, defaults: UserDefaults) -> GameProfile {
        GameProfile(
            id: eldenRingERSCID,
            name: "Elden Ring ERSC",
            prefix: defaults.string(forKey: "prefix") ?? "Steam",
            gameFolder: defaults.string(forKey: "gameFolder") ?? "\(config.externalRoot)/Games/EldenRing/Game",
            executable: "ersc_launcher.exe",
            runnerPath: defaults.string(forKey: "runnerPath") ?? "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513",
            winver: defaults.string(forKey: "winver") ?? "win10",
            requiresSteam: true,
            noDXR: defaults.object(forKey: "noDXR") as? Bool ?? true,
            metalFX: false,
            hud: defaults.object(forKey: "hud") as? Bool ?? false,
            noEsync: defaults.object(forKey: "noEsync") as? Bool ?? false,
            nativeWinmm: defaults.object(forKey: "nativeWinmm") as? Bool ?? true,
            nativeSteamAPI: defaults.object(forKey: "nativeSteamAPI") as? Bool ?? true,
            extraArguments: "",
            requiredFiles: ["eldenring.exe", "SeamlessCoop"],
            systemImage: "gamecontroller.fill"
        )
    }

    static func empty(config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: UUID(),
            name: "New App",
            prefix: "MyGame",
            gameFolder: "\(config.externalRoot)/Games",
            executable: "Game.exe",
            runnerPath: "",
            winver: "win10",
            requiresSteam: false,
            noDXR: false,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "app.fill"
        )
    }
}

private struct PathSettings: Hashable {
    var gptkHome: String
    var prefixRoot: String
    var gamesRoot: String
    var externalRoot: String
    var steamLibrary: String

    init(config: ToolkitConfig) {
        gptkHome = config.gptkHome
        prefixRoot = config.prefixRoot
        gamesRoot = config.gamesRoot
        externalRoot = config.externalRoot
        steamLibrary = config.steamLibrary
    }
}

private struct DriveMap: Codable, Identifiable, Hashable {
    var id = UUID()
    var letter: String
    var path: String

    init(letter: String, path: String) {
        self.letter = letter
        self.path = path
    }

    init?(line: String) {
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        letter = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        path = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ value: String) -> [DriveMap] {
        value.strippedShellQuotes
            .split(separator: ";")
            .compactMap { DriveMap(line: String($0)) }
    }
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
    var gamesRoot: String { expand(values["GPTK_GAMES_ROOT"] ?? "$HOME/Games") }
    var externalRoot: String { expand(values["GPTK_EXTERNAL_ROOT"] ?? "/Volumes/GameCoreApp") }
    var steamLibrary: String { expand(values["GPTK_STEAM_LIBRARY"] ?? "$GPTK_EXTERNAL_ROOT/SteamLibrary") }
    var logsPath: String { expand(values["GPTK_LOG_DIR"] ?? "$GPTK_HOME/logs") }
    var gptkWineHome: String { expand(values["GPTK_WINE_HOME"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine") }
    var gptkRuntime: String { expand(values["GPTK_RUNTIME"] ?? "$GPTK_HOME/runtime") }
    var gptkDownloadPage: String { expand(values["GPTK_DOWNLOAD_PAGE"] ?? "https://developer.apple.com/games/game-porting-toolkit/") }
    var gptkLaunchPath: String { "\(home)/bin/gptk-launch" }
    var gptkSteamPath: String { "\(home)/bin/gptk-steam" }
    var hasLocalGPTK: Bool {
        FileManager.default.isExecutableFile(atPath: "\(gptkWineHome)/bin/wine64")
            && FileManager.default.fileExists(atPath: "\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll")
    }

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

private extension DateFormatter {
    static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var envEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
