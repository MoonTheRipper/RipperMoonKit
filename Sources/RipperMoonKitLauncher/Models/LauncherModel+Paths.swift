import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
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

    var sourceConfig: String {
        "[[ -r \(config.configPath.shellQuoted) ]] && source \(config.configPath.shellQuoted); ulimit -n \"${GPTK_NOFILE_LIMIT:-49152}\" 2>/dev/null || true"
    }

    func envPath(_ path: String) -> String {
        if path == config.home {
            return "$HOME"
        }
        if path.hasPrefix(config.home + "/") {
            return "$HOME/" + path.dropFirst(config.home.count + 1)
        }
        return path
    }

    func saveEnvValues(_ values: [String: String]) {
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

    func backupConfigForEdit() throws {
        guard FileManager.default.fileExists(atPath: config.configPath) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(config.gptkHome)/backups/env-edit-\(stamp)/.rippermoon-gptk.env"
        try FileManager.default.createDirectory(atPath: (backup as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: config.configPath, toPath: backup)
    }
}
