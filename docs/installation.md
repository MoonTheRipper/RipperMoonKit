# Installation

RipperMoonKit can be installed in two ways:

- **DMG install**: best for users who want the macOS app first.
- **Source install**: best for users who want the scripts, docs, command-line tools, and local development workflow.

RipperMoonKit does not include Apple Game Porting Toolkit, games, Steam files, or mods. Each user provides their own GPTK 3 download from Apple and their own legally obtained game files.

For the simplest app-first checklist, read [normal-user-guide.md](normal-user-guide.md).

## Option A: Install From DMG

1. Download the latest DMG:

```text
https://github.com/MoonTheRipper/RipperMoonKit/releases/latest/download/RipperMoonKit-Launcher.dmg
```

2. Open the DMG.
3. Drag **RipperMoonKit Launcher.app** into **Applications**, or into your user Applications folder.
4. Open the app.
5. Follow first-run setup prompts and click **Start Guided Setup**.

If macOS blocks the app because it was downloaded from the internet, open:

```text
System Settings > Privacy & Security
```

Then allow the app to open.

The app can guide the first-run setup, create or update its own source clone in `~/Library/Application Support/RipperMoonKit/source`, open Apple's GPTK page when GPTK is missing, and call the same installer flow used by the source version.

## After Installing The App

After dragging **RipperMoonKit Launcher.app** into Applications, the user should:

1. Open **RipperMoonKit Launcher.app**.
2. If macOS blocks it, allow it in **System Settings > Privacy & Security**, then open it again.
3. Follow the first-run setup guide and click **Start Guided Setup**.
4. When GPTK is missing, click the GPTK prompt, download **Apple Game Porting Toolkit 3** from Apple, and mount the downloaded DMG.
5. Return to RipperMoonKit and continue **Start Guided Setup** so it can copy GPTK locally, create folders, install helper scripts, and write `~/.rippermoon-gptk.env`.
6. Open **Settings > Paths** and confirm the GPTK home, prefix root, games root, external root, and Steam library paths match the machine.
7. Open the **Steam** profile. If it still shows **Install Steam**, click it and wait until validation finds `steam.exe`. The DMG does not include Steam.
8. For co-op Steamworks test paths such as Elden Ring ERSC, open the **Steam** profile and click **Install Spacewar** once. Wait for AppID 480 setup to finish, then close Spacewar.
9. Add or open a game profile, set the game folder and executable, then launch from that profile.

Logs are written under:

```text
$GPTK_HOME/logs/
```

If setup fails, open **Settings > Maintenance** and use the available install/update actions after checking the log.

## GPTK Requirement

RipperMoonKit targets **Apple Game Porting Toolkit 3**.

Download GPTK 3 from Apple:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Mount the downloaded DMG before running full setup. If the Apple media contains a nested **Evaluation environment for Windows games 3.0** image, the installer tries to mount it automatically.

The installer searches mounted volumes and `~/Downloads` for:

```text
Game Porting Toolkit.app
Evaluation environment for Windows games 3.0
```

Local copies are installed under:

```text
$GPTK_HOME/apps/Game Porting Toolkit.app
$GPTK_HOME/runtime
```

## Option B: Install From Source

Clone the repository:

```zsh
git clone git@github.com:MoonTheRipper/RipperMoonKit.git
cd RipperMoonKit
```

Or download and unpack the latest source ZIP from the release page.

Mount GPTK 3 from Apple, then run:

```zsh
./install.zsh
```

The installer will:

- create toolkit folders;
- create or update `~/.rippermoon-gptk.env`;
- install helper commands into `~/bin`;
- copy GPTK 3 from mounted Apple media;
- install or verify host dependencies;
- download `SteamSetup.exe`;
- create rollback backups before replacing toolkit files;
- write a timestamped log.

Install logs are written to:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

Update backups are written to:

```text
$GPTK_HOME/backups/
```

## Build Or Reinstall The App From Source

From the source folder:

```zsh
zsh scripts/install-gui-app.zsh
```

This builds the SwiftUI launcher and installs it to:

```text
~/Applications/RipperMoonKit Launcher.app
```

## Reload The Shell

After a source install, open a new Terminal window or run:

```zsh
source ~/.zshrc
```

Check that commands are available:

```zsh
which gptk-launch
which gptk-steam
which gptk-game
```

## Default Local Layout

Internal storage:

```text
~/GPTK/
~/WinePrefixes/
~/bin/
```

External storage:

```text
$GPTK_EXTERNAL_ROOT/
    Games/
    Installers/
    SteamLibrary/
```

The paths are configurable in:

```text
~/.rippermoon-gptk.env
```

## Update Safety

Normal updates do not delete:

- saves;
- Wine prefixes;
- Steam data;
- installed games;
- GPTK runtime files;
- patched local runners.

The installer backs up small toolkit files before replacing them. See [update-safety.md](update-safety.md).

## Next Steps

- Read [gui.md](gui.md) for the app workflow.
- Read [games.md](games.html) and [game-folder-workflow.md](game-folder-workflow.md) before copying game folders.
- Read [steam.md](steam.md) before testing Steam-dependent games.
