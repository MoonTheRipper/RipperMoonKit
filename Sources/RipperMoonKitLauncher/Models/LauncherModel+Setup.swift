import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func createBackupOnly() {
        runShell(
            title: "Create Backup",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --skip-deps --backup-only",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installToolkit() {
        runShell(
            title: "Install Toolkit",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --skip-deps",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installDependencies() {
        let work = """
        echo "Installing dependencies and Apple Game Porting Toolkit 3.0…"
        echo "macOS may ask for your Mac password once (to install Homebrew)."
        echo "Copying GPTK can take several minutes with no output — that is normal."
        echo

        \(toolkitSourceBootstrapCommand)
        set +e

        RIPPERMOON_OPEN_GPTK_PAGE=0 ./install.zsh
        """
        runScriptInTerminal(named: "install-gptk", title: "Install GPTK", work: work)
    }

    func beginGPTKInstall() {
        refreshSetupChecks()
        guard config.hasLocalGPTK || config.hasGPTKInstallMedia else {
            showGPTKDownloadStep(openBrowser: false)
            return
        }
        awaitingGPTKDownload = false
        installDependencies()
    }

    func runNextSetupStep() {
        if !toolkitSourceReady {
            prepareToolkitSource()
        } else if !config.hasToolkitScripts || !config.exists {
            installToolkit()
        } else if !config.hasLocalGPTK {
            config.hasGPTKInstallMedia ? beginGPTKInstall() : showGPTKDownloadStep(openBrowser: true)
        } else if !steamInstallerReady {
            downloadSteamInstaller()
        } else if steamInstallPending {
            reload()
            commandOutput = "Steam is still installing in the background. You can set game folders and cover art while it finishes.\n"
        } else if !steamReady {
            installSteam()
        } else {
            reload()
            commandOutput = setupChecks.map { "\($0.isOK ? "✅" : "❌") \($0.title): \($0.detail)" }.joined(separator: "\n")
        }
    }

    func startFirstRunSetup() {
        refreshSetupChecks()
        if !config.hasLocalGPTK && !config.hasGPTKInstallMedia {
            showGPTKDownloadStep(openBrowser: true)
            return
        }
        awaitingGPTKDownload = false
        runFirstRunSetup()
    }

    func runFirstRunSetup() {
        refreshSetupChecks()
        if !config.hasLocalGPTK && !config.hasGPTKInstallMedia {
            showGPTKDownloadStep(openBrowser: true)
            return
        }
        awaitingGPTKDownload = false

        let work = """
        echo "════════ RipperMoonKit — First Run Setup ════════"
        echo
        echo "This installs everything RipperMoonKit needs to run games."
        echo
        echo "  • macOS may ask for your Mac password once (to install Homebrew)."
        echo "  • Some steps copy several GB and show no output while copying."
        echo "    That is normal — leave this window open until you see the"
        echo "    SETUP FINISHED banner at the bottom."
        echo

        \(toolkitSourceBootstrapCommand)
        set +e

        echo
        echo "➡️  Step 1 of 3 — installing toolkit scripts and local config…"
        setup_status=0
        ./install.zsh --skip-deps || {
          setup_status=$?
          echo "⚠️  Toolkit step had problems — see the output above."
        }

        echo
        echo "➡️  Step 2 of 3 — dependencies + Apple Game Porting Toolkit 3.0…"
        echo "    If GPTK is missing, download Game Porting Toolkit 3.0 from Apple,"
        echo "    open the downloaded DMG so it mounts, then let this window continue."
        echo "    Copying GPTK can take several minutes with no output."
        RIPPERMOON_OPEN_GPTK_PAGE=1 ./install.zsh || {
          setup_status=$?
          echo "⚠️  GPTK 3.0 is not installed yet."
          echo "    Download Game Porting Toolkit 3.0, mount the DMG, then run setup again."
        }

        echo
        echo "➡️  Step 3 of 3 — starting Windows Steam install in the background…"
        if [[ "$setup_status" -eq 0 ]]; then
          echo "    Steam can take several minutes, but you do not need to wait here."
          echo "    RipperMoonKit will move on while Steam installs in the background."
          echo "    In the meantime, set your game folders and cover art API from the app."
          ./install.zsh --install-steam-background || echo "⚠️  Steam background install did not start — use the Steam profile's Install Steam action later."
        else
          echo "⏭️  Skipping Steam until the required toolkit pieces are installed."
        fi

        exit "$setup_status"
        """
        runScriptInTerminal(named: "guided-setup", title: "Guided Setup", work: work)
    }

    func prepareToolkitSource() {
        runShell(
            title: "Prepare Source",
            command: toolkitSourceBootstrapCommand,
            completion: { [weak self] in self?.reload() }
        )
    }

    func downloadSteamInstaller() {
        runShell(
            title: "Download Steam Installer",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk",
            completion: { [weak self] in self?.reload() }
        )
    }

    func installSteam() {
        runShell(
            title: steamReady ? "Repair Steam Install" : "Install Steam",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk --install-steam-background",
            completion: { [weak self] in self?.reload() }
        )
    }

    func openGPTKPage() {
        NSWorkspace.shared.open(URL(string: config.gptkDownloadPage)!)
    }

    func showGPTKDownloadStep(openBrowser: Bool) {
        guidedSetupRunning = false
        awaitingGPTKDownload = true
        showSetupGuide = true
        lastResult = "Download GPTK 3.0"
        commandOutput = """
        Download Game Porting Toolkit 3.0 from Apple Developer.

        Open the downloaded DMG so it appears in Finder, then return to RipperMoonKit and click Begin GPTK Install.
        """
        if openBrowser {
            openGPTKPageForCurrentSetupIfNeeded()
        }
    }

    func openGPTKPageForCurrentSetupIfNeeded() {
        guard awaitingGPTKDownload, !openedGPTKPageForCurrentSetup else { return }
        openedGPTKPageForCurrentSetup = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.awaitingGPTKDownload else { return }
            self.openGPTKPage()
        }
    }

    /// Opens the documentation bundled inside the app (offline-safe), falling
    /// back to the GitHub repository if the bundled docs are not present.
    func openHelpDocs(page: String = "index.html") {
        let local = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/docs", isDirectory: true)
            .appendingPathComponent(page)
        if FileManager.default.fileExists(atPath: local.path) {
            NSWorkspace.shared.open(local)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/MoonTheRipper/RipperMoonKit")!)
        }
    }

    func dismissSetupGuide() {
        showSetupGuide = false
    }

    /// "Set up later" — closes the window for this session. The persistent
    /// Finish Setup banner stays visible so the user can resume any time.
    func deferSetup() {
        setupDeferred = true
        awaitingGPTKDownload = false
        showSetupGuide = false
    }

    /// Reopens the setup window from the Finish Setup banner.
    func reopenSetupGuide() {
        setupDeferred = false
        config = ToolkitConfig.load()
        showSetupGuide = true
    }

    /// "Start Gaming" — leaves the finished setup window for the library.
    func finishSetup() {
        showSetupGuide = false
        pendingSelection = .library
    }

    /// Optional next step — jump into Settings for game folder / cover art.
    func openSetupRelatedSettings() {
        showSetupGuide = false
        pendingSelection = .settings
    }

    /// Optional next step — open the Steam app to finish installing Steam.
    func goToSteamSetup() {
        showSetupGuide = false
        pendingSelection = .profile(steamProfile.id)
    }

    /// Lightweight re-read so the setup checklist ticks itself off live.
    func refreshSetupChecks() {
        config = ToolkitConfig.load()
    }

    func shouldShowSetupGuide(config: ToolkitConfig) -> Bool {
        !setupDeferred && (config.needsSetupGuide || !toolkitSourceReady)
    }

    static func defaultToolkitSourceFolder(home: String) -> String {
        "\(home)/Library/Application Support/RipperMoonKit/source"
    }

    /// Toolkit source shipped inside the packaged .app, if present.
    /// Lets first-run setup work offline with no GitHub clone.
    var bundledToolkitFolder: String? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/toolkit", isDirectory: true)
        let installer = candidate.appendingPathComponent("install.zsh").path
        return FileManager.default.isExecutableFile(atPath: installer) ? candidate.path : nil
    }

    var toolkitSourceBootstrapCommand: String {
        let source = toolkitSourceFolder.shellQuoted
        let repo = rmkRepositoryURL.shellQuoted
        let bundled = (bundledToolkitFolder ?? "").shellQuoted
        return """
        set -e
        echo "➡️ Preparing RipperMoonKit source…"
        repo=\(repo)
        src=\(source)
        bundled=\(bundled)
        mkdir -p "$(dirname "$src")"
        if [[ -x "$src/install.zsh" ]]; then
          echo "✅ Toolkit source ready: $src"
          cd "$src"
        elif [[ -n "$bundled" && -x "$bundled/install.zsh" ]]; then
          echo "📦 Installing bundled toolkit source into: $src"
          rm -rf "$src.tmp"
          ditto "$bundled" "$src.tmp"
          rm -rf "$src"
          mv "$src.tmp" "$src"
          cd "$src"
        else
          echo "⬇️ Cloning toolkit source into: $src"
          rm -rf "$src.tmp" "$src.tmp.zip"
          if git --version >/dev/null 2>&1; then
            git clone --depth 1 "$repo" "$src.tmp"
          else
            curl -fL "https://github.com/MoonTheRipper/RipperMoonKit/archive/refs/heads/main.zip" -o "$src.tmp.zip"
            unzip -q "$src.tmp.zip" -d "$(dirname "$src")"
            mv "$(dirname "$src")/RipperMoonKit-main" "$src.tmp"
            rm -f "$src.tmp.zip"
          fi
          rm -rf "$src"
          mv "$src.tmp" "$src"
          cd "$src"
        fi
        chmod +x ./install.zsh scripts/*.zsh 2>/dev/null || true
        """
    }

    var setupSentinelURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit/.setup-complete")
    }

    var setupIncompleteSentinelURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit/.setup-incomplete")
    }

    /// Runs a setup script in a real Terminal window so macOS can show the
    /// admin-password prompt (Homebrew) and the long GPTK download wait.
    /// The script ends with a loud banner and writes a result sentinel so the
    /// app can refresh without treating an incomplete GPTK install as success.
    func runScriptInTerminal(named name: String, title: String, work: String) {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit", isDirectory: true)
        let scriptURL = dir.appendingPathComponent("\(name).command")
        let sentinel = setupSentinelURL
        let incompleteSentinel = setupIncompleteSentinelURL
        try? FileManager.default.removeItem(at: sentinel)
        try? FileManager.default.removeItem(at: incompleteSentinel)

        let body = """
        #!/bin/zsh
        printf '\\033]0;RipperMoonKit Setup — running…\\007'
        clear
        (
        \(work)
        )
        work_status=$?
        mkdir -p \(dir.path.shellQuoted)

        verify_status=1
        if [[ "$work_status" -eq 0 ]]; then
          config_file="$HOME/.rippermoon-gptk.env"
          [[ -r "$config_file" ]] && source "$config_file"
          gptk_home="${GPTK_HOME:-$HOME/GPTK}"
          gptk_app_path="${GPTK_APP_PATH:-$gptk_home/apps/Game Porting Toolkit.app}"
          gptk_runtime="${GPTK_RUNTIME:-$gptk_home/runtime}"
          if [[ -r "$config_file" && -x "$HOME/bin/gptk-launch" && -x "$HOME/bin/gptk-steam" && -x "$gptk_app_path/Contents/Resources/wine/bin/wine64" && -f "$gptk_runtime/lib/wine/x86_64-windows/d3d12.dll" ]]; then
            verify_status=0
          fi
        fi

        if [[ "$work_status" -eq 0 && "$verify_status" -eq 0 ]]; then
          result_sentinel=\(sentinel.path.shellQuoted)
        else
          result_sentinel=\(incompleteSentinel.path.shellQuoted)
        fi
        date "+%Y-%m-%d %H:%M:%S" > "$result_sentinel"
        printf '\\a'
        echo
        if [[ "$work_status" -eq 0 && "$verify_status" -eq 0 ]]; then
          printf '\\033]0;RipperMoonKit Setup — FINISHED\\007'
          echo "════════════════════════════════════════════════"
          echo "   ✅  SETUP FINISHED"
          echo "════════════════════════════════════════════════"
          echo
          echo "RipperMoonKit refreshed itself — switch back to it to see"
          echo "what installed. You can now close this Terminal window."
        else
          printf '\\033]0;RipperMoonKit Setup — STOPPED\\007'
          echo "════════════════════════════════════════════════"
          echo "   ⚠️  SETUP INCOMPLETE"
          echo "════════════════════════════════════════════════"
          echo
          echo "RipperMoonKit did not verify all required pieces."
          echo "If GPTK is missing, download Game Porting Toolkit 3.0 from Apple,"
          echo "open the downloaded DMG so it mounts, then run setup again."
          echo "Switch back to RipperMoonKit to see which items still need setup."
        fi
        echo
        """

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            lastResult = "\(title) failed"
            commandOutput = "Could not prepare the setup script:\n\(error.localizedDescription)\n"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", scriptURL.path]
        do {
            try process.run()
        } catch {
            lastResult = "\(title) failed"
            commandOutput = "Could not open Terminal:\n\(error.localizedDescription)\n"
            return
        }

        guidedSetupRunning = true
        lastResult = "\(title) running in Terminal"
        commandOutput = """
        \(title) is running in a Terminal window.

        Follow the steps shown there — macOS may ask for your Mac password once.
        Some steps copy several GB and look idle while they work; that is normal.

        RipperMoonKit refreshes itself the moment setup finishes — no need to watch.
        """
        watchForSetupCompletion()
    }

    /// Polls for the setup sentinel and refreshes the app when Terminal setup ends.
    func watchForSetupCompletion() {
        let sentinel = setupSentinelURL
        let incompleteSentinel = setupIncompleteSentinelURL
        Task { @MainActor [weak self] in
            for _ in 0..<1200 { // up to ~60 minutes
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self, self.guidedSetupRunning else { return }
                let complete = FileManager.default.fileExists(atPath: sentinel.path)
                let incomplete = FileManager.default.fileExists(atPath: incompleteSentinel.path)
                if complete || incomplete {
                    try? FileManager.default.removeItem(at: sentinel)
                    try? FileManager.default.removeItem(at: incompleteSentinel)
                    NSApp.activate(ignoringOtherApps: true)
                    self.reload()
                    if incomplete {
                        if !self.config.hasLocalGPTK {
                            self.awaitingGPTKDownload = true
                        }
                        self.lastResult = "Setup incomplete"
                        self.commandOutput = "Setup stopped before every required item was verified. Download and mount Game Porting Toolkit 3.0 if it is still missing, then click Begin GPTK Install.\n"
                    }
                    return
                }
            }
        }
    }
}
