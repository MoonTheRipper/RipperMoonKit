import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func openLogsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.logsPath))
    }

    func reportTestResult(for profile: GameProfile?) {
        let report = testerReportMarkdown(for: profile)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        var components = URLComponents(string: "https://github.com/MoonTheRipper/RipperMoonKit/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Game test report: \(profile?.name ?? "New game")"),
            URLQueryItem(name: "body", value: report)
        ]

        if let url = components?.url {
            NSWorkspace.shared.open(url)
            lastResult = "Tester report copied"
            commandOutput = "A structured tester report was copied to the clipboard and opened in GitHub Issues. GitHub may still ask the tester to sign in before submitting."
        } else {
            lastResult = "Tester report copied"
            commandOutput = report
        }
    }

    func testerReportMarkdown(for profile: GameProfile?) -> String {
        let p = profile ?? profiles.first(where: { !$0.isSteamApp })
        let name = p?.name ?? "New game"
        let executable = p?.executable ?? ""
        let prefix = p?.prefix ?? ""
        let runner = redactedPath(p?.runnerPath ?? "")
        let folder = redactedPath(p?.gameFolder ?? "")
        let modEngine = p?.useModEngine == true ? "enabled" : "disabled"
        let steam = p?.requiresSteam == true || p?.isSteamManaged == true ? "yes" : "no"

        return """
        ## Tester Report

        ### Game
        - Name: \(name)
        - Executable: \(executable.isEmpty ? "unknown" : executable)
        - Result: launched / playable / crash / black screen / freeze / other

        ### Profile
        - Prefix: \(prefix.isEmpty ? "unknown" : prefix)
        - Requires Steam: \(steam)
        - ModEngine: \(modEngine)
        - Winver: \(p?.winver ?? "unknown")
        - No DXR: \(p?.noDXR == true ? "yes" : "no")
        - No esync: \(p?.noEsync == true ? "yes" : "no")
        - MetalFX: \(p?.metalFX == true ? "yes" : "no")
        - HUD: \(p?.hud == true ? "yes" : "no")
        - Runner: \(runner.isEmpty ? "default" : runner)
        - Game folder: \(folder.isEmpty ? "not set" : folder)

        ### Machine
        - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        - Architecture: \(machineArchitecture)
        - RipperMoonKit: \(rmkAppVersion)

        ### What happened?
        Describe the launch result, what screen appeared, and whether sound/input/networking worked.

        ### Steps tried
        1.
        2.
        3.

        ### Expected result
        What should have happened?

        ### Actual result
        What happened instead?

        ### Useful log lines
        Paste only the relevant lines from \(redactedPath(config.logsPath)).
        """
    }

    func redactedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard !path.isEmpty else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + path.dropFirst(home.count + 1)
        }
        return path
    }

    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
