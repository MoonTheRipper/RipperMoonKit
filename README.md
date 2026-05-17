# RipperMoonToolKit

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I2I61WTJ6V)

RipperMoonToolKit is a manual Apple Game Porting Toolkit 3 launcher setup for Apple Silicon Macs. It keeps Wine prefixes on internal storage, keeps large game libraries on external storage, and launches Windows Steam or standalone Windows game folders through reusable zsh commands.

This repository is source and documentation only. It intentionally does not include Wine prefixes, installed games, Steam data, saves, logs, Apple runtime files, or any machine-specific directories.

## Status

The toolkit is intended for technical users who are comfortable with Terminal, mounted volumes, and Wine/GPTK troubleshooting.

Tested workflow:

- Apple Game Porting Toolkit 3.
- Windows Steam running through a dedicated `Steam` prefix.
- Elden Ring ERSC from a copied pre-installed offline/non-Steam Windows `Game` folder.
- Elden Ring ModEngine 2 plus Item and Enemy Randomizer profile preparation.
- Elden Ring randomized output launching through ModEngine 2; launching without ModEngine returns the game to the non-randomized path.
- Save transfer into the real Wine prefix save directory after confirming the game-created save path.
- Elden Ring Seamless Coop Golden Pot lobby opening with a GPTK DirectSound capture workaround.

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
- Installer bootstrap with timestamped emoji logs.
- Update backups and rollback for existing local installs.
- A SwiftUI launcher target with per-app profiles, ERSC defaults, validation, logs, path editing, drive mapping, close-game control, VC++ runtime install actions, and rollback.
- An Elden Ring Mod Manager panel that installs selected mod ZIPs, prepares ModEngine 2 config/launch files, runs the randomizer GUI, and launches the modded profile without copying another PC's drive letters.
- Documentation for GPTK 3, Steam, ERSC, copied game folders, saves, and troubleshooting.

## Quick Start

Read [docs/quickstart.md](docs/quickstart.md) first.

Short version:

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

## Common Commands

Start Steam:

```zsh
gptk-steam --log
```

Stop Steam:

```zsh
gptk-steam --kill
```

Run a Windows executable:

```zsh
gptk-launch --prefix MyGame -- "/path/to/game.exe"
```

Install Windows Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

See [docs/commands.md](docs/commands.md) for the full command reference.

Run the SwiftUI launcher:

```zsh
swift run RipperMoonKitLauncher
```

Install a local `.app` bundle:

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
- Launch ERSC from the same `Steam` prefix.
- Keep esync enabled when Steam is already running with esync.
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

Start here:

- [docs/index.md](docs/index.md): documentation table of contents.
- [docs/quickstart.md](docs/quickstart.md): shortest working install path.
- [docs/setup.md](docs/setup.md): first-time setup and path model.
- [docs/dependencies.md](docs/dependencies.md): dependency download, unpack, install, and logs.
- [docs/update-safety.md](docs/update-safety.md): update backups, protected paths, and rollback.
- [docs/gui.md](docs/gui.md): SwiftUI launcher build/run notes.
- [docs/uninstall.md](docs/uninstall.md): uninstall options that keep or remove configs/saves by choice.
- [docs/gptk.md](docs/gptk.md): downloading GPTK 3 from Apple, mounting it, and letting the installer copy it locally.
- [docs/configuration.md](docs/configuration.md): environment variables and path configuration.
- [docs/drives.md](docs/drives.md): custom Wine drive mappings.
- [docs/commands.md](docs/commands.md): command reference.
- [docs/visual-c-runtime.md](docs/visual-c-runtime.md): Microsoft Visual C++ runtime installation for Wine prefixes.
- [docs/steam.md](docs/steam.md): Windows Steam install and launch flow.
- [docs/game-folder-workflow.md](docs/game-folder-workflow.md): copying pre-installed game folders instead of running fragile installers.
- [docs/elden-ring-ersc.md](docs/elden-ring-ersc.md): ERSC launch sequence.
- [docs/clair-obscur-dlss-metalfx.md](docs/clair-obscur-dlss-metalfx.md): Clair Obscur DLSS through GPTK MetalFX.
- [docs/steam-voice-capture-fix-2026-05-13.md](docs/steam-voice-capture-fix-2026-05-13.md): Golden Pot freeze bug report and workaround.
- [docs/save-transfer.md](docs/save-transfer.md): save discovery and restore workflow.
- [docs/troubleshooting.md](docs/troubleshooting.md): common failure modes.
- [docs/faq.md](docs/faq.md): common questions.
- [docs/release-checklist.md](docs/release-checklist.md): maintainer checklist before publishing.
- [docs/roadmap.md](docs/roadmap.md): planned SwiftUI launcher and compatibility profile work.

## Project Page

The minimalist download page is [index.html](index.html). If GitHub Pages is enabled from the `main` branch root, it provides direct links to the latest DMG and source ZIP release assets.
