import Foundation

/// A game already installed in the Windows Steam library inside the Steam prefix.
struct InstalledSteamGame: Identifiable, Hashable {
    let appID: String
    let name: String
    let installDir: String
    /// Host path to the installed game folder (…/steamapps/common/<installDir>).
    let commonPath: String
    var id: String { appID }
}

extension LauncherModel {
    /// Steam app ids that are runtimes/tools rather than playable games.
    private static let steamNonGameAppIDs: Set<String> = [
        "228980", // Steamworks Common Redistributables
        "1070560", // Steam Linux Runtime
        "1391110", // Steam Linux Runtime - Soldier
        "1628350"  // Steam Linux Runtime - Sniper
    ]

    /// Scan every reachable Steam library inside the Steam prefix and return the
    /// installed games (parsed from appmanifest_*.acf). Libraries on unmounted
    /// drives are skipped automatically.
    func installedSteamGames() -> [InstalledSteamGame] {
        let steamPrefix = prefixPath(for: steamProfile)
        let clientDir = "\(steamPrefix)/drive_c/Program Files (x86)/Steam"

        var steamappsDirs: [String] = ["\(clientDir)/steamapps"]
        let libraryFolders = "\(clientDir)/steamapps/libraryfolders.vdf"
        if let text = try? String(contentsOfFile: libraryFolders, encoding: .utf8) {
            for winePath in vdfAllValues(key: "path", in: text) {
                guard let host = resolveWineDrivePath(winePath, steamPrefix: steamPrefix) else { continue }
                let dir = "\(host)/steamapps"
                if !steamappsDirs.contains(dir) { steamappsDirs.append(dir) }
            }
        }

        var seen = Set<String>()
        var games: [InstalledSteamGame] = []
        for steamapps in steamappsDirs {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: steamapps) else { continue }
            for entry in entries where entry.hasPrefix("appmanifest_") && entry.hasSuffix(".acf") {
                guard let text = try? String(contentsOfFile: "\(steamapps)/\(entry)", encoding: .utf8) else { continue }
                let appID = (vdfValue(key: "appid", in: text) ?? "").trimmingCharacters(in: .whitespaces)
                let name = (vdfValue(key: "name", in: text) ?? "").trimmingCharacters(in: .whitespaces)
                let installDir = (vdfValue(key: "installdir", in: text) ?? "").trimmingCharacters(in: .whitespaces)
                guard !appID.isEmpty, !name.isEmpty,
                      !Self.steamNonGameAppIDs.contains(appID),
                      !seen.contains(appID) else { continue }
                seen.insert(appID)
                games.append(InstalledSteamGame(
                    appID: appID,
                    name: name,
                    installDir: installDir,
                    commonPath: "\(steamapps)/common/\(installDir)"
                ))
            }
        }
        return games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Whether a profile for this Steam app id already exists in the library.
    func steamGameAlreadyAdded(_ appID: String) -> Bool {
        profiles.contains { ($0.steamAppID ?? "") == appID && !$0.isSteamApp }
    }

    /// Create (or return the existing) Steam-managed profile for an installed game.
    /// The profile launches through `gptk-steam -applaunch <appID>`, which starts
    /// Steam in the background, so it never requires opening Steam by hand.
    @discardableResult
    func addSteamGame(_ game: InstalledSteamGame) -> GameProfile {
        if let existing = profiles.first(where: { ($0.steamAppID ?? "") == game.appID && !$0.isSteamApp }) {
            return existing
        }
        var profile = GameProfile.steamGame(
            appID: game.appID,
            name: game.name,
            installDir: game.installDir,
            config: config
        )
        profile.gameFolder = game.commonPath
        profiles.append(profile)
        persistProfiles()
        return profile
    }

    /// Resolve a Wine path like `S:\\SteamLibrary` to its host path via the
    /// prefix's dosdevices drive links.
    private func resolveWineDrivePath(_ winePath: String, steamPrefix: String) -> String? {
        guard let colon = winePath.firstIndex(of: ":") else { return nil }
        let letter = String(winePath[winePath.startIndex]).lowercased()
        let rest = String(winePath[winePath.index(after: colon)...]).replacingOccurrences(of: "\\", with: "/")
        let link = "\(steamPrefix)/dosdevices/\(letter):"
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link) else { return nil }
        let base: String
        if target.hasPrefix("/") {
            base = target
        } else {
            base = URL(fileURLWithPath: "\(steamPrefix)/dosdevices").appendingPathComponent(target).standardized.path
        }
        return base + rest
    }

    private func vdfValue(key: String, in text: String) -> String? {
        vdfAllValues(key: key, in: text).first
    }

    private func vdfAllValues(key: String, in text: String) -> [String] {
        let pattern = "\"\(NSRegularExpression.escapedPattern(for: key))\"\\s+\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        var out: [String] = []
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            if let match, match.numberOfRanges > 1 {
                out.append(ns.substring(with: match.range(at: 1)))
            }
        }
        return out
    }
}
