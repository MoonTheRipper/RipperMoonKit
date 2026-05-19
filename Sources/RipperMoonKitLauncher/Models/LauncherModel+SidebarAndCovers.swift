import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    /// The effective TheGamesDB key — the key entered in Settings, stored locally
    /// in user defaults. Seeded once from GPTK_TGDB_API_KEY in the env file.
    var tgdbAPIKey: String {
        tgdbAPIKeyLocal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ── Pinned sidebar games ──────────────────────────────────────────────

    /// Pinned profiles, in pin order, resolved against the current library.
    var pinnedProfiles: [GameProfile] {
        pinnedProfileIDs.compactMap { id in profiles.first { $0.id == id } }
    }

    /// Profiles not currently pinned — the candidates for the Add menu.
    var unpinnedProfiles: [GameProfile] {
        profiles.filter { !pinnedProfileIDs.contains($0.id) }
    }

    func pinProfile(_ id: UUID) {
        guard !pinnedProfileIDs.contains(id) else { return }
        pinnedProfileIDs.append(id)
        persistPins()
    }

    func unpinProfile(_ id: UUID) {
        pinnedProfileIDs.removeAll { $0 == id }
        persistPins()
    }

    func persistPins() {
        defaults.set(pinnedProfileIDs.map { $0.uuidString }, forKey: pinnedProfilesKey)
    }

    /// Polls the process list and marks profiles whose game executable is running.
    ///
    /// Uses `ps -axww` so long Wine command lines are not truncated (the default
    /// `ps` width hides the `.exe` deep in a GPTK launch line). Each row is parsed
    /// as PID + state + command so the launcher's own process and dead/zombie
    /// entries can be excluded before matching executable names.
    func refreshLiveStatus() async {
        let result = await ShellExecutor.run("ps -axww -o pid=,state=,command=")
        guard !result.output.isEmpty else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var entries: [(pid: Int32, command: String)] = []
        for line in result.output.split(separator: "\n") {
            let fields = line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3,
                  let pid = Int32(fields[0]), pid != ownPID,
                  !fields[1].contains("Z") else { continue }   // skip self + zombies
            entries.append((pid, fields[2].lowercased()))
        }

        var live: Set<UUID> = []
        var pidMap: [UUID: [Int32]] = [:]
        for profile in profiles {
            var targets = closeTargets(for: profile)
            if profile.isSteamApp { targets.append(contentsOf: ["steam.exe", "steamwebhelper"]) }
            let needles = targets.map { $0.lowercased() }.filter { !$0.isEmpty }
            guard !needles.isEmpty else { continue }
            let pids = entries
                .filter { entry in needles.contains { entry.command.contains($0) } }
                .map(\.pid)
            if !pids.isEmpty {
                live.insert(profile.id)
                pidMap[profile.id] = pids
            }
        }
        if live != liveProfileIDs { liveProfileIDs = live }
        liveProfilePIDs = pidMap
    }

    /// Persists the Settings-entered TheGamesDB key to local user defaults.
    func saveTGDBKey() {
        let trimmed = tgdbAPIKeyLocal.trimmingCharacters(in: .whitespacesAndNewlines)
        tgdbAPIKeyLocal = trimmed
        defaults.set(trimmed, forKey: tgdbAPIKeyDefaultsKey)
        lastResult = trimmed.isEmpty ? "TheGamesDB key cleared" : "TheGamesDB key saved"
    }

    /// Downloads a chosen cover, caches it under GPTK Home, and assigns it to a profile.
    func saveCover(_ match: TheGamesDB.Match, for profileID: UUID) async {
        guard let url = match.fullURL else {
            lastResult = "That result has no cover image."
            return
        }
        isRunning = true
        defer { isRunning = false }
        do {
            let data = try await TheGamesDB.download(url)
            let directory = "\(pathSettings.gptkHome)/covers"
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destination = "\(directory)/tgdb-\(match.id).\(ext)"
            try data.write(to: URL(fileURLWithPath: destination))
            if let index = profiles.firstIndex(where: { $0.id == profileID }) {
                profiles[index].iconPath = destination
                persistProfiles()
            }
            commandOutput = "TheGamesDB · cover set for “\(match.title)” → \(destination)"
            lastResult = "Cover set from TheGamesDB"
        } catch {
            commandOutput = "TheGamesDB · \(error.localizedDescription)"
            lastResult = "Cover download failed"
        }
    }
}
