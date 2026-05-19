# RipperMoonKit

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I2I61WTJ6V)

RipperMoonKit is a macOS toolkit for running selected Windows games through Apple Game Porting Toolkit 3 and Wine. It provides helper scripts, a SwiftUI launcher, per-game profiles, update backups, and documentation for the workflows that have been tested on this machine.

The project is intentionally narrow. It is not a game store, not Proton, not Heroic, not a compatibility database, and not a redistribution of Apple GPTK, Steam, games, saves, or third-party mods. Users provide their own game files and download Apple GPTK from Apple.

## License

RipperMoonKit is free to run, inspect, and modify for personal use, but it is not licensed for repackaging, resale, rebranding, or embedding into another product. See [LICENSE](LICENSE) for the full source-available personal-use terms.

## Current Scope

The app and scripts are meant for users who are comfortable with external drives, Wine prefixes, logs, and occasional breakage. The GUI reduces the amount of command-line work, but the project is still a compatibility toolkit rather than a finished consumer game launcher.

Tested workflows:

- Apple Game Porting Toolkit 3.
- Windows Steam running through a dedicated `Steam` prefix.
- Elden Ring ERSC from a copied pre-installed offline/non-Steam Windows `Game` folder.
- Elden Ring ModEngine 2 plus Item and Enemy Randomizer profile preparation.
- Elden Ring randomized output launching through ModEngine 2; launching without ModEngine returns the game to the non-randomized path.
- Save transfer into the real Wine prefix save directory after confirming the game-created save path.
- Elden Ring Seamless Coop Golden Pot lobby opening with a GPTK DirectSound capture workaround.

## Known Limits

- Apple Silicon Macs are the target platform.
- Game compatibility is not guaranteed. Each game can need a different prefix, runner, runtime, launch flag, or workaround.
- Online features that depend on kernel anti-cheat are expected to fail under Wine/GPTK.
- The project does not bypass DRM, anti-cheat, game ownership checks, or platform rules.
- Installers are often less reliable than copied, already-installed Windows game folders.
- External drives must stay mounted at the same paths, or drive mappings need to be updated in Settings.

## Proof Of Concept

![RipperMoonKit launcher showing an Elden Ring ERSC game profile](docs/assets/rippermoonkit-gui.png)

![Elden Ring running on macOS through Apple Game Porting Toolkit with the HUD visible](docs/assets/elden-ring-grace-hud.png)

The screenshots show the launcher profile and a live Elden Ring GPTK run. See [docs/proof-of-concept.md](docs/proof-of-concept.md) for the full example.

## What This Provides

- `gptk-launch`: runs Windows executables or Wine tools inside a named prefix.
- `gptk-steam`: installs, launches, repairs, and stops Windows Steam.
- `gptk-game`: creates small per-game launcher scripts.
- `gptk-vcrun`: downloads and installs Microsoft Visual C++ runtimes into Wine prefixes.
- `gptk-dotnet6`: downloads and installs Microsoft .NET 6 Desktop Runtime into Wine prefixes for tools like Elden Ring Randomizer.
- `gptk-stubs`: cross-compiles and installs minimal stub DLLs for Wine/GPTK missing APIs (GameInput, etc.) so delay-load crashes are resolved without touching game files.
- Dynamic path configuration through `~/.rippermoon-gptk.env`.
- Configurable Wine drive mappings with any letters except `C:`.
- Installer bootstrap with timestamped logs.
- Update backups and rollback for existing local installs.
- A SwiftUI launcher target with per-app profiles, ERSC defaults, validation, logs, path editing, drive mapping, close-game control, VC++ runtime install actions, and rollback.
- An Elden Ring Mod Manager panel that installs selected mod ZIPs, prepares ModEngine 2 config/launch files, runs the randomizer GUI, and launches the modded profile without copying another PC's drive letters.
- Documentation for GPTK 3, Steam, ERSC, copied game folders, saves, and troubleshooting.

## Quick Start

Read [docs/normal-user-guide.md](docs/normal-user-guide.md) first if you installed the DMG and want the simplest app-first path. Use [docs/quickstart.md](docs/quickstart.md) if you want the shorter technical checklist.

Short version:

For the app-first path, download the latest DMG, open it, and drag **RipperMoonKit Launcher.app** into Applications:

```text
https://github.com/MoonTheRipper/RipperMoonKit/releases/latest/download/RipperMoonKit-Launcher.dmg
```

Then open the app and follow the first-run setup:

1. Allow the app in **System Settings > Privacy & Security** if macOS blocks it.
2. Use the first-run guide to connect **Apple Game Porting Toolkit 3**. The DMG does not include GPTK; the app runner can be installed with Homebrew, while Apple's DMG supplies the official runtime.
3. Confirm paths in **Settings > Paths**.
4. Install Windows Steam from the **Steam** profile when a game needs Steam. The DMG does not include Steam.
5. For Elden Ring ERSC/co-op Steamworks test paths, use **Steam > Install Spacewar** once, wait for AppID 480 setup, then close Spacewar.
6. Add or open a game profile, set the game folder/executable, and launch.

For source install:

1. Download **Game Porting Toolkit 3** from Apple:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

2. Mount the downloaded GPTK `.dmg`.
3. Clone or copy this repository.
4. Run:

```zsh
cd RipperMoonToolKit
./install.zsh
```

5. Open a new terminal or run:

```zsh
source ~/.zshrc
```

The installer writes logs to:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

Before updating an existing install, the installer also writes a rollback backup to:

```text
$GPTK_HOME/backups/rippermoon-update-YYYYmmdd-HHMMSS
```

See [docs/update-safety.md](docs/update-safety.md).
See [docs/installation.md](docs/installation.md) for the full DMG and source install paths.

## Common Commands

Start Steam:

```zsh
gptk-steam --log
```

Stop Steam:

```zsh
gptk-steam --kill
```

Install Spacewar / AppID 480 once for co-op Steamworks test paths:

```zsh
gptk-steam --log --install-spacewar
```

Run a Windows executable:

```zsh
gptk-launch --prefix MyGame -- "/path/to/game.exe"
```

Install Windows Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

That foreground command validates Steam and closes it after install. Open the Steam profile later when you are ready to sign in.

For app-style first-run setup, start Steam in the background so users can configure game folders and cover art while Steam finishes:

```zsh
./install.zsh --install-steam-background
```

See [docs/commands.md](docs/commands.md) for the full command reference.

Run the SwiftUI launcher:

```zsh
zsh scripts/install-gui-app.zsh
```

See [docs/gui.md](docs/gui.md).

Uninstall without deleting configs or saves:

```zsh
zsh scripts/uninstall.zsh
```

See [docs/uninstall.md](docs/uninstall.md).

## Configuration

The installer creates:

```text
~/.rippermoon-gptk.env
```

Important defaults:

```zsh
export GPTK_HOME="$HOME/GPTK"
export GPTK_PREFIX_ROOT="$HOME/WinePrefixes"
export GPTK_GAMES_ROOT="$HOME/Games"
export GPTK_EXTERNAL_ROOT="/Volumes/GameCoreApp"
export GPTK_STEAM_LIBRARY="$GPTK_EXTERNAL_ROOT/SteamLibrary"
export GPTK_DRIVE_MAPS="S=$GPTK_STEAM_LIBRARY;X=$GPTK_EXTERNAL_ROOT/Games;I=$GPTK_EXTERNAL_ROOT/Installers"
export GPTK_APP_PATH="$GPTK_HOME/apps/Game Porting Toolkit.app"
export GPTK_RUNTIME="$GPTK_HOME/runtime"
export GPTK_WINE_HOME="$GPTK_APP_PATH/Contents/Resources/wine"
```

See [docs/configuration.md](docs/configuration.md).

## Elden Ring ERSC

See [docs/elden-ring-ersc.md](docs/elden-ring-ersc.md).

Important tested constraint:

- Use a copied, already-installed Windows `Game` folder.
- Do not use the original installation files as the runtime source.
- Start Steam first.
- From the Steam profile, run **Install Spacewar** once so Steam installs AppID 480 / Spacewar. Close Spacewar after setup finishes.
- Launch ERSC from the same `Steam` prefix.
- Do not mix esync states. The current ERSC profile starts Steam and ERSC with esync disabled for Golden Pot stability.
- If Golden Pot lobby opening freezes the frame while audio continues, use the no-capture GPTK runner documented in [docs/steam-voice-capture-fix-2026-05-13.md](docs/steam-voice-capture-fix-2026-05-13.md).

For Randomizer plus Seamless Coop, use the GUI's Elden Ring **Mod Manager** panel. **Install ModEngine + Randomizer** installs .NET 6 Desktop Runtime into a randomizer tools prefix, clones or updates the `elden-randomizer-coop` setup reference repo under `$GPTK_HOME/tools`, opens the download pages, installs recognized ZIPs from its `inputs/` folder, prepares `ModEngine2/config_eldenring.toml` and `ModEngine2/launchmod_eldenring.bat`, runs `ModEngine2/randomizer/EldenRingRandomizer.exe`, and launches through `modengine2_launcher.exe` after the `.randomizeopt` seed has been imported and randomized. When Wine Staging is installed, the randomizer GUI uses that tool runner while Elden Ring itself remains on the configured GPTK game runner.

The randomizer generates files that ModEngine mounts at launch. If you start Elden Ring without ModEngine, the randomized layout is not loaded. That behavior is expected and is used as a quick sanity check that the randomized profile is isolated from the regular game path.

## Credits

RipperMoonKit does not redistribute third-party mods or game files. It automates local setup around tools the user downloads separately:

- [ModEngine 2](https://github.com/soulsmods/ModEngine2) by the Souls modding community provides the mod loader path used for randomized Elden Ring launches.
- [Elden Ring Seamless Co-op / ERSC](https://www.nexusmods.com/eldenring/mods/510) provides the co-op DLL and launcher used by the ERSC workflow.
- [MoonTheRipper/elden-randomizer-coop](https://github.com/MoonTheRipper/elden-randomizer-coop) provides the Windows setup reference that informed the native macOS helper flow.
- Elden Ring Item and Enemy Randomizer is installed from the user's downloaded ZIP and run locally through a dedicated tools prefix.

## Repository Safety

The `.gitignore` excludes common local state:

- Wine prefixes.
- GPTK runtime files.
- Installed games.
- Steam libraries.
- Logs.
- Saves and backups.
- macOS metadata.

Keep this repository limited to scripts, docs, examples, and small configuration templates.

## Documentation

The documentation is grouped so users can start with setup, then move into app use, game workflows, and repair notes.

<details open>
<summary><strong>First-Time Setup</strong></summary>

- [Documentation index](docs/index.md): full documentation map.
- [Quickstart](docs/quickstart.md): shortest working install path.
- [Installation](docs/installation.md): DMG install and source install paths.
- [Setup model](docs/setup.md): first-time folders, prefixes, and path model.
- [GPTK 3](docs/gptk.md): download from Apple, mount, and copy locally.
- [Dependencies](docs/dependencies.md): dependency download, unpack, install, and logs.

</details>

<details>
<summary><strong>Launcher And Configuration</strong></summary>

- [SwiftUI launcher](docs/gui.md): app build/run notes and profile behavior.
- [Configuration](docs/configuration.md): environment variables and path configuration.
- [Drive mappings](docs/drives.md): custom Wine drive letters.
- [Update safety](docs/update-safety.md): update backups, protected paths, and rollback.
- [Uninstall](docs/uninstall.md): keep or remove configs/saves by choice.

</details>

<details>
<summary><strong>Game Workflows</strong></summary>

- [Game folder workflow](docs/game-folder-workflow.md): copying pre-installed game folders instead of fragile installers.
- [Known tested games](docs/tested-games.md): field notes for tried games.
- [Elden Ring ERSC](docs/elden-ring-ersc.md): ERSC launch sequence.
- [REFramework plan](docs/reframework.md): planned Resident Evil / RE Engine compatibility track.
- [Clair Obscur DLSS/MetalFX](docs/clair-obscur-dlss-metalfx.md): DLSS through GPTK MetalFX.
- [Save transfer](docs/save-transfer.md): save discovery and restore workflow.

</details>

<details>
<summary><strong>Commands And Repair</strong></summary>

- [Commands](docs/commands.md): command reference.
- [Steam](docs/steam.md): Windows Steam install and launch flow.
- [Visual C++ runtime](docs/visual-c-runtime.md): Microsoft runtime installation for Wine prefixes.
- [API stubs](docs/stubs.md): missing Wine/GPTK delay-load API stubs.
- [Troubleshooting](docs/troubleshooting.md): common failure modes.
- [Golden Pot voice capture fix](docs/steam-voice-capture-fix-2026-05-13.md): freeze bug report and workaround.
- [Golden Pot runner precedence fix](docs/golden-pot-runner-precedence-fix-2026-05-14.md): update regression guard.
- [ERSC esync descriptor fix](docs/ersc-esync-file-descriptor-fix-2026-05-16.md): Wine esync file descriptor exhaustion notes.

</details>

<details>
<summary><strong>Project</strong></summary>

- [Q&A](docs/faq.md): common questions.
- [License summary](docs/license.html): plain-language license summary.
- [Release checklist](docs/release-checklist.md): maintainer checklist before publishing.
- [Roadmap](docs/roadmap.md): planned launcher and compatibility profile work.

</details>

## Project Page

The minimalist download page is [index.html](index.html). If GitHub Pages is enabled from the `main` branch root, it provides direct links to the latest DMG and source ZIP release assets.
