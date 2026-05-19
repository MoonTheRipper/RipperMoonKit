import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    static func loadProfiles(config: ToolkitConfig, defaults: UserDefaults) -> [GameProfile] {
        if let data = defaults.data(forKey: "gameProfiles.v1"),
           let profiles = try? JSONDecoder().decode([GameProfile].self, from: data),
           !profiles.isEmpty {
            return repairProfiles(profiles, config: config)
        }
        return repairProfiles([GameProfile.steam(config: config), GameProfile.eldenRing(config: config, defaults: defaults)], config: config)
    }

    static func repairProfiles(_ profiles: [GameProfile], config: ToolkitConfig) -> [GameProfile] {
        var repaired = profiles.map { $0.repairedForCurrentToolkit(config: config) }

        if !repaired.contains(where: { $0.isSteamApp }) {
            repaired.insert(GameProfile.steam(config: config), at: 0)
        }

        if let steamIndex = repaired.firstIndex(where: { $0.isSteamApp }), steamIndex != 0 {
            let steam = repaired.remove(at: steamIndex)
            repaired.insert(steam, at: 0)
        }

        for steamGame in discoverSteamGames(config: config) {
            if let existingIndex = repaired.firstIndex(where: { $0.steamAppID == steamGame.steamAppID }) {
                repaired[existingIndex].name = repaired[existingIndex].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.name : repaired[existingIndex].name
                repaired[existingIndex].gameFolder = steamGame.gameFolder
                repaired[existingIndex].prefix = repaired[existingIndex].prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired[existingIndex].prefix
                repaired[existingIndex].requiresSteam = true
                repaired[existingIndex].systemImage = repaired[existingIndex].systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.systemImage : repaired[existingIndex].systemImage
            } else {
                repaired.append(steamGame)
            }
        }

        return repaired
    }

    func repairedProfile(_ profile: GameProfile) -> GameProfile {
        let repaired = profile.repairedForCurrentToolkit(config: config)
        guard repaired != profile else { return profile }

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = repaired
            persistProfiles()
        }
        return repaired
    }

    static func discoverSteamGames(config: ToolkitConfig) -> [GameProfile] {
        let steamAppsURL = URL(fileURLWithPath: config.steamLibrary).appendingPathComponent("steamapps")
        let manifestURLs = ((try? FileManager.default.contentsOfDirectory(
            at: steamAppsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                let name = url.lastPathComponent
                return name.hasPrefix("appmanifest_") && name.hasSuffix(".acf")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return manifestURLs.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let appID = acfValue("appid", in: text),
                  let name = acfValue("name", in: text),
                  let installDir = acfValue("installdir", in: text),
                  !appID.isEmpty,
                  !name.isEmpty,
                  !installDir.isEmpty else {
                return nil
            }

            return GameProfile.steamGame(appID: appID, name: name, installDir: installDir, config: config)
        }
    }

    static func acfValue(_ key: String, in text: String) -> String? {
        let pattern = #""\#(key)"\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }
}
