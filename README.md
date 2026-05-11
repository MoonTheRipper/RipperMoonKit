# RipperMoonToolKit

RipperMoonToolKit is a manual Apple Game Porting Toolkit 3 launcher setup for Apple Silicon Macs. It keeps Wine prefixes on internal storage, keeps large game libraries on external storage, and launches Windows Steam or standalone Windows game folders through reusable zsh commands.

This repository is source and documentation only. It intentionally does not include Wine prefixes, installed games, Steam data, saves, logs, Apple runtime files, or any machine-specific directories.

## Status

The toolkit is intended for technical users who are comfortable with Terminal, mounted volumes, and Wine/GPTK troubleshooting.

Tested workflow:

- Apple Game Porting Toolkit 3.
- Windows Steam running through a dedicated `Steam` prefix.
- Elden Ring ERSC from a copied pre-installed offline/non-Steam Windows `Game` folder.
- Save transfer into the real Wine prefix save directory after confirming the game-created save path.

## What This Provides

- `gptk-launch`: runs Windows executables or Wine tools inside a named prefix.
- `gptk-steam`: installs, launches, repairs, and stops Windows Steam.
- `gptk-game`: creates small per-game launcher scripts.
- Dynamic path configuration through `~/.rippermoon-gptk.env`.
- Configurable Wine drive mappings with any letters except `C:`.
- Installer bootstrap with timestamped emoji logs.
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
- [docs/gptk.md](docs/gptk.md): downloading GPTK 3 from Apple, mounting it, and letting the installer copy it locally.
- [docs/configuration.md](docs/configuration.md): environment variables and path configuration.
- [docs/drives.md](docs/drives.md): custom Wine drive mappings.
- [docs/commands.md](docs/commands.md): command reference.
- [docs/steam.md](docs/steam.md): Windows Steam install and launch flow.
- [docs/game-folder-workflow.md](docs/game-folder-workflow.md): copying pre-installed game folders instead of running fragile installers.
- [docs/elden-ring-ersc.md](docs/elden-ring-ersc.md): ERSC launch sequence.
- [docs/save-transfer.md](docs/save-transfer.md): save discovery and restore workflow.
- [docs/troubleshooting.md](docs/troubleshooting.md): common failure modes.
- [docs/faq.md](docs/faq.md): common questions.
- [docs/release-checklist.md](docs/release-checklist.md): maintainer checklist before publishing.
