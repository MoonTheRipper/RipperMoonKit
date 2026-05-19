import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ModsTab: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile

    var body: some View {
        Card(title: "Mod Stack", icon: "square.3.layers.3d", trailing: AnyView(
            Toggle("Launch through ModEngine", isOn: Binding(
                get: { profile.useModEngine ?? false },
                set: { profile.useModEngine = $0 }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11.5))
            .foregroundStyle(Onyx.textDim)
            .help("Routes launch through ModEngine2 instead of starting the game executable directly.")
        )) {
            VStack(alignment: .leading, spacing: 10) {
                modLayer(1, "Seamless Coop", "DLL",
                         profile.seamlessDllPath ?? "../SeamlessCoop/ersc.dll")
                modLayer(2, "Elden Ring Randomizer", "EXE",
                         profile.randomizerExecutable ?? "randomizer/EldenRingRandomizer.exe")
                modLayer(3, "ModEngine 2", "Loader",
                         "\(profile.modEngineLauncher ?? "modengine2_launcher.exe") · \(profile.modEngineConfig ?? "config_eldenring.toml")")
            }
        }

        CollapsibleCard(
            title: "Mod Configuration",
            icon: "wrench.adjustable.fill",
            storageKey: "profile.section.mod-configuration.collapsed",
            defaultCollapsed: true,
            help: "Advanced ModEngine paths. These tell RipperMoonKit where the ModEngine launcher, config, batch file, Randomizer, and Seamless DLL are located."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                PathEditor(title: "ModEngine", path: Binding(
                    get: { profile.modEngineFolder ?? "ModEngine2" },
                    set: { profile.modEngineFolder = $0.isEmpty ? nil : $0 }
                )) {
                    model.chooseFolder(current: model.modEngineDirectory(for: profile)) { selected in
                        profile.modEngineFolder = model.profileRelativePath(selected, from: profile.gameFolder)
                    }
                }
                .help("Folder containing modengine2_launcher.exe. Usually Game/ModEngine2.")
                FieldRow(label: "Launch Bat") {
                    OnyxField(text: optional(\.modEngineLaunchBat, "launchmod_eldenring.bat"), mono: true)
                }
                .help("Optional batch file mirroring the ModEngine launch command. Useful for compatibility with setups copied from Windows.")
                FieldRow(label: "Config") {
                    OnyxField(text: optional(\.modEngineConfig, "config_eldenring.toml"), mono: true)
                }
                .help("The ModEngine TOML file that lists external DLLs and mod folders.")
                FieldRow(label: "Launcher") {
                    OnyxField(text: optional(\.modEngineLauncher, "modengine2_launcher.exe"), mono: true)
                }
                .help("The ModEngine executable RipperMoonKit launches.")
                FieldRow(label: "Randomizer") {
                    OnyxField(text: optional(\.randomizerExecutable, "randomizer/EldenRingRandomizer.exe"), mono: true)
                }
                .help("The Randomizer GUI executable relative to the ModEngine folder.")
                FieldRow(label: "Seamless DLL") {
                    OnyxField(text: optional(\.seamlessDllPath, "../SeamlessCoop/ersc.dll"), mono: true)
                }
                .help("The Seamless Co-op DLL path as written into ModEngine config. It is usually relative to ModEngine2.")
            }
        }

        CollapsibleCard(
            title: "Mod Files",
            icon: "wrench.and.screwdriver.fill",
            storageKey: "profile.section.mod-files.collapsed",
            help: "Install, back up, import, prepare, randomize, and launch the Elden Ring mod toolchain."
        ) {
            FlowLayout(spacing: 8) {
                RMKButton(kind: .primary, icon: "square.and.arrow.down.fill",
                          title: "Install ModEngine + Randomizer") {
                    model.installModEngineRandomizerProfile(for: profile)
                }
                .help("Installs the standard ModEngine2, Randomizer, Seamless Co-op, and related setup files for this profile.")
                RMKButton(kind: .ghost, icon: "externaldrive.badge.timemachine", title: "Backup Mod State") {
                    model.backupEldenModState(for: profile)
                }
                .help("Creates a rollback backup of ModEngine2, SeamlessCoop, and the mod helper executables.")
                RMKButton(kind: .ghost, icon: "person.2.badge.gearshape.fill", title: "Import From Friend") {
                    model.importFriendKit(for: profile)
                }
                .help("Imports a host's friend kit: bundled mod ZIPs, Randomizer options, and Seamless password.")
                RMKButton(kind: .ghost, icon: "archivebox.fill", title: "Install Mod Zips") {
                    model.installModZips(for: profile)
                }
                .help("Manually install selected ModEngine, Randomizer, Seamless, or anti-cheat toggler ZIP files.")
                RMKButton(kind: .ghost, icon: "wrench.adjustable.fill", title: "Prepare Mod Files") {
                    model.prepareModEngine(for: profile)
                }
                .help("Rewrites the ModEngine config and launch batch file for this Mac path.")
                RMKButton(kind: .ghost, icon: "shuffle", title: "Run Randomizer") {
                    model.runRandomizer(for: profile)
                }
                .help("Opens the Randomizer GUI. Import a .randomizeopt file there, then click Randomize.")
                RMKButton(kind: .primary, icon: "play.circle.fill", title: "Launch Modded") {
                    model.launchModEngine(profile)
                }
                .help("Launches Elden Ring through ModEngine2 with the current mod configuration.")
            }
        }
    }

    private func optional(_ keyPath: WritableKeyPath<GameProfile, String?>,
                          _ fallback: String) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? fallback },
            set: { profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func modLayer(_ n: Int, _ name: String, _ type: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Onyx.accentInk)
                .frame(width: 26, height: 26)
                .background(Onyx.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                    Text(type)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Onyx.textDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Onyx.surface2, in: Capsule())
                        .overlay { Capsule().strokeBorder(Onyx.hairline, lineWidth: 0.75) }
                }
                Text(desc)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Onyx.textMute)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct CommandPreview: View {
    let title: String
    let command: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Onyx.textDim)
            Text(command)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Onyx.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Onyx.hairline2, lineWidth: 0.75)
                }
        }
    }
}

struct ActivityCard: View {
    @EnvironmentObject private var model: LauncherModel
    var body: some View {
        Card(title: "Activity", icon: "waveform.path.ecg", trailing: AnyView(
            HStack(spacing: 6) {
                if model.isRunning { ProgressView().controlSize(.small) }
                Text(model.lastResult)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
            }
        )) {
            Terminal(title: "rippermoon.log", text: model.commandOutput, live: model.isRunning)
                .frame(minHeight: 150)
        }
    }
}
