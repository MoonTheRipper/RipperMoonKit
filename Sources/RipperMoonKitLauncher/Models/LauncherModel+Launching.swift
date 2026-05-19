import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func closeGame(_ profile: GameProfile) {
        // Prefer killing the actual macOS process tree the live poller found — a
        // Wine `taskkill` round-trip through gptk-launch is slow and unreliable.
        if let pids = liveProfilePIDs[profile.id], !pids.isEmpty {
            let list = pids.map(String.init).joined(separator: " ")
            liveProfileIDs.remove(profile.id)          // instant UI feedback
            liveProfilePIDs[profile.id] = nil
            runShell(
                title: "Close \(profile.name)",
                command: "kill \(list) 2>/dev/null; sleep 1; kill -9 \(list) 2>/dev/null; true"
            )
        } else {
            let repaired = repairedProfile(profile)
            runShell(title: "Close \(repaired.name)", command: previewCloseGameCommand(for: repaired))
        }
    }

    func launch(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        if (profile.requiresSteam || profile.isSteamManaged), !ensureSteamReady(for: profile) {
            return
        }
        runShell(
            title: "Launch \(profile.name)",
            command: launchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func launchModEngine(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        if profile.requiresSteam, !ensureSteamReady(for: profile) {
            return
        }
        runShell(
            title: "Launch \(profile.name) ModEngine",
            command: previewModEngineLaunchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func runRandomizer(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Run Randomizer",
            command: previewRandomizerCommand(for: profile, detached: true),
            detached: true
        )
    }

    func previewSteamManagedLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        let appLaunch = (profile.steamAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let appArgs = appLaunch.isEmpty ? "" : " -applaunch \(appLaunch.shellQuoted)"
        let envPart = steamEnvAssignment(for: profile)
        let launch = "nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs) >> \(logPath.shellQuoted) 2>&1 &"

        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs)"
    }

    func launchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        if profile.isSteamManaged {
            return previewSteamManagedLaunchCommand(for: profile, detached: detached)
        }
        if profile.useModEngine == true {
            return previewModEngineLaunchCommand(for: profile, detached: detached)
        }
        return previewLaunchCommand(for: profile, detached: detached)
    }

    func previewCloseGameCommand(for profile: GameProfile) -> String {
        let commands = closeTargets(for: profile).map { target in
            "env \(runnerEnvAssignment(for: profile)) \(config.gptkLaunchPath.shellQuoted) --prefix \(profile.prefix.shellQuoted) --no-log -- taskkill /IM \(target.shellQuoted) /F >/dev/null 2>&1 || true"
        }
        if commands.isEmpty {
            return "\(sourceConfig); echo \("No process target configured for \(profile.name)".shellQuoted)"
        }
        return "\(sourceConfig); \(commands.joined(separator: "; "))"
    }

    func previewLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.avx == true { args.append("--avx") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: ["--log-file", logPath, "--", "./\(profile.executable)"])

        let extra = profile.extraArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraPart = extra.isEmpty ? "" : " \(extra)"
        let overrides = dllOverrides(for: profile)
        let launch = "cd \(profile.gameFolder.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart) >> \(logPath.shellQuoted) 2>&1 &"
        let preflight = steamDependencyPreflightCommand(for: profile)
        let detachedLaunch = [preflight, launch].filter { !$0.isEmpty }.joined(separator: "; ")

        if detached {
            return "\(sourceConfig); \(detachedLaunch)"
        }
        let foregroundLaunch = "cd \(profile.gameFolder.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart)"
        return "\(sourceConfig); \([preflight, foregroundLaunch].filter { !$0.isEmpty }.joined(separator: "; "))"
    }

    func previewModEngineLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-modengine.log"
        let modEngineDir = modEngineDirectory(for: profile)
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.avx == true { args.append("--avx") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: [
            "--log-file", logPath,
            "--",
            "./\(profile.modEngineLauncherName)",
            "-t", "er",
            "-c", "./\(profile.modEngineConfigName)",
            "--game-path", winePath(forMacPath: "\(profile.gameFolder)/eldenring.exe")
        ])

        let overrides = dllOverrides(for: profile)
        let launch = "cd \(modEngineDir.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " ")) >> \(logPath.shellQuoted) 2>&1 &"
        let preflight = steamDependencyPreflightCommand(for: profile)
        let detachedLaunch = [preflight, launch].filter { !$0.isEmpty }.joined(separator: "; ")

        if detached {
            return "\(sourceConfig); \(detachedLaunch)"
        }
        let foregroundLaunch = "cd \(modEngineDir.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))"
        return "\(sourceConfig); \([preflight, foregroundLaunch].filter { !$0.isEmpty }.joined(separator: "; "))"
    }

    func previewRandomizerCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-randomizer.log"
        let modEngineDir = modEngineDirectory(for: profile)
        let randomizerRelative = profile.randomizerExecutablePath
        let randomizerDir = URL(fileURLWithPath: modEngineDir).appendingPathComponent(randomizerRelative).deletingLastPathComponent().path
        var args: [String] = ["--prefix", toolPrefixName(for: profile), "--set-winver", profile.winver, "--no-esync", "--no-dxr"]
        args.append(contentsOf: ["--log-file", logPath, "--", "./\((randomizerRelative as NSString).lastPathComponent)"])
        let toolEnv = toolRunnerEnvAssignment()

        let launch = "cd \(randomizerDir.shellQuoted) && nohup env \(toolEnv) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " ")) >> \(logPath.shellQuoted) 2>&1 &"
        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); cd \(randomizerDir.shellQuoted) && env \(toolEnv) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))"
    }

    func closeTargets(for profile: GameProfile) -> [String] {
        var targets: [String] = []
        let executable = (profile.executable as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !executable.isEmpty {
            targets.append(executable)
        }
        if profile.isEldenRingERSC {
            targets.append("eldenring.exe")
        }
        if profile.useModEngine == true {
            targets.append(profile.modEngineLauncherName)
            targets.append("eldenring.exe")
        }
        var seen = Set<String>()
        return targets.filter { seen.insert($0.localizedLowercase).inserted }
    }

    func runnerEnvAssignment(for profile: GameProfile) -> String {
        profile.runnerPath.isEmpty ? "" : "GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)"
    }

    func toolPrefixName(for profile: GameProfile) -> String {
        let suffix = config.toolWineHome.localizedCaseInsensitiveContains("Wine Staging.app") ? "ToolsStaging" : "Tools"
        return profile.isEldenRingERSC ? "EldenRing\(suffix)" : "\(profile.safeName)-\(suffix)"
    }

    func toolRunnerEnvAssignment() -> String {
        let wineHome = config.toolWineHome
        return wineHome.isEmpty ? "" : "GPTK_WINE_HOME=\(wineHome.shellQuoted)"
    }

    func steamEnvAssignment(for profile: GameProfile) -> String {
        var assignments: [String] = []
        if !profile.runnerPath.isEmpty {
            assignments.append("GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)")
        }
        assignments.append("GPTK_MTL_HUD_ENABLED=\(profile.hud ? "1" : "0")")
        assignments.append("GPTK_WINEESYNC=\(profile.noEsync ? "0" : "1")")
        return assignments.joined(separator: " ")
    }

    func dllOverrides(for profile: GameProfile) -> String {
        var values: [String] = []
        if profile.nativeWinmm { values.append("winmm=n,b") }
        if profile.nativeSteamAPI { values.append("steam_api64=n,b") }
        if profile.metalFX == true {
            values.append("nvapi64=b,n")
            values.append("nvngx=b,n")
        }
        if let extra = profile.extraDllOverrides, !extra.trimmingCharacters(in: .whitespaces).isEmpty {
            values.append(extra.trimmingCharacters(in: .whitespaces))
        }
        return values.joined(separator: ";")
    }
}
