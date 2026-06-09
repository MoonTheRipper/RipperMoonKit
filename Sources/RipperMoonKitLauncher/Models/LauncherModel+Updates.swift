import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    /// Beta builds (version contains "beta") track the GPTK4.0-Development branch
    /// and only see prerelease tags. Stable builds keep using /releases/latest,
    /// which already skips prereleases on GitHub's side.
    static var isBetaChannel: Bool {
        rmkAppVersion.lowercased().contains("beta")
    }

    static let betaBranchName = "GPTK4.0-Development"

    func checkForAvailableUpdate(force: Bool = false) async {
        if isCheckingForUpdates || (!force && hasCheckedForUpdates) {
            return
        }

        isCheckingForUpdates = true
        hasCheckedForUpdates = true
        defer { isCheckingForUpdates = false }

        let endpoint = Self.isBetaChannel
            ? "https://api.github.com/repos/MoonTheRipper/RipperMoonKit/releases?per_page=20"
            : "https://api.github.com/repos/MoonTheRipper/RipperMoonKit/releases/latest"

        guard let url = URL(string: endpoint) else {
            return
        }

        do {
            var request = URLRequest(url: url, timeoutInterval: 8)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("RipperMoonKit/\(rmkAppVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                if force {
                    lastResult = "Update check failed"
                    commandOutput = "GitHub did not return the latest release information.\n"
                }
                return
            }

            let release: GitHubReleaseInfo
            if Self.isBetaChannel {
                let all = try JSONDecoder().decode([GitHubReleaseInfo].self, from: data)
                let betas = all.filter { $0.tagName.lowercased().contains("beta") }
                guard let newest = betas.max(by: { Self.isVersion($1.tagName, newerThan: $0.tagName) }) else {
                    if force {
                        lastResult = "No beta releases yet"
                        commandOutput = "No GPTK 4.0 beta releases have been published. Installed: \(rmkAppVersion)\n"
                    }
                    updateNotice = nil
                    return
                }
                release = newest
            } else {
                release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            }

            let releaseURL = release.htmlURL ?? URL(string: "https://github.com/MoonTheRipper/RipperMoonKit/releases/latest")!
            if Self.isVersion(release.tagName, newerThan: rmkAppVersion) {
                updateNotice = UpdateNotice(version: release.tagName, url: releaseURL)
                if force {
                    lastResult = "Update available"
                    commandOutput = "RipperMoonKit \(release.tagName) is available. Open Settings > Maintenance > Update From GitHub.\n"
                }
            } else {
                updateNotice = nil
                if force {
                    lastResult = "Already on latest release"
                    commandOutput = "Installed version: \(rmkAppVersion)\nLatest GitHub release: \(release.tagName)\n"
                }
            }
        } catch {
            if force {
                lastResult = "Update check failed"
                commandOutput = "\(error.localizedDescription)\n"
            }
        }
    }

    func updateFromGitHub() {
        let source = toolkitSourceFolder.shellQuoted
        let repo = rmkRepositoryURL.shellQuoted
        let installPath = updateInstallPath()
        let installTarget = installPath.shellQuoted
        let branch = Self.isBetaChannel ? Self.betaBranchName : "main"
        let branchQuoted = branch.shellQuoted
        let archivePathQuoted = "RipperMoonKit-\(branch)".shellQuoted
        let command = """
        \(toolkitSourceBootstrapCommand)
        src=\(source)
        repo=\(repo)
        branch=\(branchQuoted)
        if [[ -d "$src/.git" ]]; then
          cd "$src"
          git fetch --tags origin && \
          git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" && \
          if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/$branch)" ]]; then git pull --ff-only origin "$branch"; else echo "Already up to date."; fi
        else
          echo "Toolkit source has no Git metadata; replacing it with a fresh GitHub checkout."
          parent="$(dirname "$src")"
          stamp="$(date +%Y%m%d-%H%M%S)"
          mkdir -p "$parent"
          rm -rf "$src.update" "$src.update.zip"
          if git --version >/dev/null 2>&1; then
            git clone --depth 1 --branch "$branch" "$repo" "$src.update"
          else
            curl -fL "https://github.com/MoonTheRipper/RipperMoonKit/archive/refs/heads/$branch.zip" -o "$src.update.zip"
            unzip -q "$src.update.zip" -d "$parent"
            mv "$parent/"\(archivePathQuoted) "$src.update"
            rm -f "$src.update.zip"
          fi
          if [[ -e "$src" ]]; then
            mv "$src" "$src.previous-$stamp"
          fi
          mv "$src.update" "$src"
          cd "$src"
        fi
        ./install.zsh --skip-deps && \
        zsh scripts/install-gui-app.zsh \(installTarget)
        """
        runShell(
            title: "Update From GitHub",
            command: command,
            completion: { [weak self] in self?.reload() },
            successCompletion: { [weak self] in self?.relaunchAfterUpdate(appPath: installPath) }
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
            command: "\(toolkitSourceBootstrapCommand)\nzsh scripts/uninstall.zsh \(args.joined(separator: " "))",
            completion: { [weak self] in self?.reload() }
        )
    }

    func rollbackBackup(id: BackupItem.ID) {
        guard let backup = backups.first(where: { $0.id == id }) else { return }
        runShell(
            title: "Rollback",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --rollback \(backup.name.shellQuoted)",
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

    func updateInstallPath() -> String {
        "\(NSHomeDirectory())/Applications/RipperMoonKit Launcher.app"
    }

    func relaunchAfterUpdate(appPath: String) {
        let bundleURL = URL(fileURLWithPath: appPath)
        guard bundleURL.pathExtension == "app" else {
            commandOutput += "\nUpdate installed. Relaunch is only automatic from the packaged .app.\n"
            return
        }

        lastResult = "Update installed. Restarting app"
        commandOutput += "\nUpdate installed. RipperMoonKit will close and reopen.\n"
        let command = "sleep 1; open \(bundleURL.path.shellQuoted)"

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            try? process.run()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSApp.terminate(nil)
        }
    }

    static func isVersion(_ candidate: String, newerThan installed: String) -> Bool {
        let lhs = versionParts(candidate)
        let rhs = versionParts(installed)
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    static func versionParts(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.drop { $0 == "v" || $0 == "V" }
        return withoutPrefix
            .split { $0 == "." || $0 == "-" || $0 == "_" }
            .map { token in
                let digits = token.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}
