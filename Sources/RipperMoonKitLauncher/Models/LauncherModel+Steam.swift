import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func fileExists(_ relativePath: String, in profile: GameProfile) -> Bool {
        guard !relativePath.isEmpty else { return false }
        let path = URL(fileURLWithPath: profile.gameFolder).appendingPathComponent(relativePath).path
        return FileManager.default.fileExists(atPath: path)
    }

    func prefixPath(for profile: GameProfile) -> String {
        if profile.prefix.hasPrefix("/") || profile.prefix.hasPrefix("./") || profile.prefix.hasPrefix("../") {
            return NSString(string: profile.prefix).expandingTildeInPath
        }
        return "\(config.prefixRoot)/\(profile.prefix)"
    }

    func steamExecutableExists(in profile: GameProfile) -> Bool {
        FileManager.default.fileExists(atPath: steamExecutablePath(in: profile))
    }

    func steamExecutablePath(in profile: GameProfile) -> String {
        "\(prefixPath(for: profile))/drive_c/Program Files (x86)/Steam/steam.exe"
    }

    func startSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        guard ensureSteamReady(for: profile) else { return }
        runShell(
            title: "Start Steam",
            command: previewStartSteamCommand(for: profile, detached: true),
            detached: true
        )
    }

    func installSpacewarFromSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        guard ensureSteamReady(for: profile) else { return }
        runShell(
            title: "Install Spacewar AppID 480",
            command: previewInstallSpacewarCommand(for: profile, detached: true),
            detached: true
        )
    }

    func stopSteam() {
        runShell(title: "Stop Steam", command: previewStopSteamCommand())
    }

    func ensureSteamReady(for profile: GameProfile) -> Bool {
        let steam = profile.isSteamApp ? profile : steamProfile
        guard steamExecutableExists(in: steam) else {
            lastResult = "Steam install required"
            commandOutput = """
            Windows Steam is not ready for \(profile.name).

            Missing:
            \(steamExecutablePath(in: steam))

            Use the Steam profile's Install Steam / Repair Steam button, or run Set Up RipperMoonKit.
            """
            showSetupGuide = true
            return false
        }
        return true
    }

    func previewStartSteamCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let writeState = steamStateWriteCommand(for: profile)
        if detached {
            return "\(sourceConfig); \(writeState); \(steamStartDetachedCommand(for: profile))"
        }
        let envPart = steamEnvAssignment(for: profile)
        return "\(sourceConfig); \(writeState); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log"
    }

    func previewInstallSpacewarCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let writeState = steamStateWriteCommand(for: profile)
        let envPart = steamEnvAssignment(for: profile)
        let logPath = "\(config.logsPath)/steam-spacewar-480.log"
        if detached {
            return "\(sourceConfig); \(writeState); nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log --install-spacewar >> \(logPath.shellQuoted) 2>&1 &"
        }
        return "\(sourceConfig); \(writeState); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log --install-spacewar"
    }

    func previewInstallSteamCommand() -> String {
        "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk --install-steam-background"
    }

    func previewStopSteamCommand() -> String {
        "\(sourceConfig); \(config.gptkSteamPath.shellQuoted) --kill"
    }

    func steamStatePath(for profile: GameProfile) -> String {
        "\(config.gptkHome)/state/steam-\(profile.prefix.safeShellIdentifier).env"
    }

    func steamStateWriteCommand(for profile: GameProfile) -> String {
        let statePath = steamStatePath(for: profile)
        let stateDir = (statePath as NSString).deletingLastPathComponent
        let lines = [
            "prefix=\(profile.prefix)",
            "runner=\(profile.runnerPath)",
            "noEsync=\(profile.noEsync ? "1" : "0")",
            "updatedAt=\(ISO8601DateFormatter().string(from: Date()))"
        ]
        let payload = lines.map(\.shellQuoted).joined(separator: " ")
        return "mkdir -p \(stateDir.shellQuoted); printf '%s\\n' \(payload) > \(statePath.shellQuoted)"
    }

    func steamStartDetachedCommand(for profile: GameProfile) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-steam.log"
        let envPart = steamEnvAssignment(for: profile)
        return "nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log >> \(logPath.shellQuoted) 2>&1 &"
    }

    func steamWaitForUICommand(timeout: Int = 45) -> String {
        """
        steam_ready=0; \
        for i in {1..\(timeout)}; do \
          if ps -axww -o command= | grep -qi '[s]teamwebhelper.exe'; then steam_ready=1; break; fi; \
          sleep 1; \
        done; \
        if [[ "$steam_ready" != "1" ]]; then \
          echo "RipperMoonKit: Steam did not finish bringing up its UI within \(timeout) seconds. Launch Steam from this profile first, wait for the library window, then launch again."; \
          exit 74; \
        fi
        """
    }

    func steamDependencyPreflightCommand(for profile: GameProfile) -> String {
        guard profile.requiresSteam && !profile.isSteamManaged else { return "" }

        let expectedRunner = profile.runnerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let statePath = steamStatePath(for: profile)
        let noEsync = profile.noEsync ? "1" : "0"
        let startSteam = "\(steamStateWriteCommand(for: profile)); \(steamStartDetachedCommand(for: profile))"
        let waitForSteam = steamWaitForUICommand()

        return """
        steam_lines="$(ps -axww -o command= | grep -i '[s]team.exe' || true)"; \
        if [[ -n "$steam_lines" ]]; then \
          if [[ -n \(expectedRunner.shellQuoted) ]] && ! print -r -- "$steam_lines" | grep -Fq \(expectedRunner.shellQuoted); then \
            echo "RipperMoonKit: Steam is already running with a different Wine runner. Close Steam, then use this profile's Start Steam button before launching."; \
            exit 72; \
          fi; \
          if [[ \(noEsync.shellQuoted) == "1" ]] && { [[ ! -r \(statePath.shellQuoted) ]] || ! grep -Fq 'noEsync=1' \(statePath.shellQuoted); }; then \
            echo "RipperMoonKit: Steam is already running without this profile's no-esync startup marker. Close Steam, then use this profile's Start Steam button before launching."; \
            exit 73; \
          fi; \
        else \
          \(startSteam); \
        fi; \
        \(waitForSteam)
        """
    }
}
