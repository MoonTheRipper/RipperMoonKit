# Installation

RipperMoonKit can be installed in two ways:

- **DMG install**: best for users who want the macOS app first.
- **Source install**: best for users who want the scripts, docs, command-line tools, and local development workflow.

RipperMoonKit does not include Apple Game Porting Toolkit, games, Steam files, or mods. Each user provides their own GPTK 3.0 download from Apple and their own legally obtained game files.

For the simplest app-first checklist, read [normal-user-guide.md](normal-user-guide.md).

## Option A: Install From DMG

1. Download the latest DMG:

```text
https://github.com/MoonTheRipper/RipperMoonKit/releases/latest/download/RipperMoonKit-Launcher.dmg
```

2. Open the DMG.
3. Run **Install to My Applications.command**, or copy **RipperMoonKit Launcher.app** into your user Applications folder.
4. Open the app.
5. Follow first-run setup prompts and click **Set Up RipperMoonKit**.

If macOS blocks the app because it was downloaded from the internet, open:

```text
System Settings > Privacy & Security
```

Then allow the app to open.

The app can guide the first-run setup, create or update its own source clone in `~/Library/Application Support/RipperMoonKit/source`, open Apple's GPTK page when GPTK is missing, and call the same installer flow used by the source version.

## After Installing The App

RipperMoonKit is designed to be installed per user:

```text
~/Applications/RipperMoonKit Launcher.app
```

Do not put the app in `/Applications` unless you intentionally want a system-wide copy. Per-user installs keep separate macOS test accounts isolated and avoid stale copies during updates.

After installing **RipperMoonKit Launcher.app** into `~/Applications`, the user should:

1. Open **RipperMoonKit Launcher.app**.
2. If macOS blocks it, allow it in **System Settings > Privacy & Security**, then open it again.
3. Follow the first-run setup guide and click **Set Up RipperMoonKit**.
4. When GPTK is missing, the app pauses on the **Download Game Porting Toolkit 3.0** step and opens Apple's download page.
5. Download **Apple Game Porting Toolkit 3.0** from Apple, then open the downloaded DMG so it mounts in Finder.
6. Return to RipperMoonKit. The **Begin GPTK Install** button becomes available after the app detects the downloaded DMG or mounted GPTK media.
7. Click **Begin GPTK Install** so it can install the GPTK app runner if needed, copy the Apple GPTK runtime locally, create folders, install helper scripts, and write `~/.rippermoon-gptk.env`. The setup window should not show the finished state until the runner and GPTK 3.0 runtime have been copied and verified.
8. Setup then starts Windows Steam installation in the background. Steam can take several minutes, but the app can move to the finished screen while Steam continues.
9. When the **You're all set** screen appears, Steam may still be installing. Open the **Steam** profile when you are ready to sign in.
10. Open **Settings > Paths** and confirm the GPTK home, prefix root, games root, external root, and Steam library paths match the machine.
11. Add or open a game profile. Set the game folder to a copied, already-installed Windows game folder. Do not point the app at game installer files.
12. Add a free TheGamesDB API key in settings if you want cover art in the library.
13. For co-op Steamworks test paths such as Elden Ring ERSC, open the **Steam** profile and click **Install Spacewar** once. Wait for AppID 480 setup to finish, then close Spacewar.
14. Launch from the game profile.

Logs are written under:

```text
$GPTK_HOME/logs/
```

If setup fails, open **Settings > Maintenance** and use the available install/update actions after checking the log.

## GPTK Requirement

RipperMoonKit targets **Apple Game Porting Toolkit 3.0**.

Download GPTK 3.0 from Apple:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Mount the downloaded DMG before running full setup. If the Apple media contains a nested **Evaluation environment for Windows games 3.0** image, the installer tries to mount it automatically.

The Apple DMG supplies the official evaluation runtime. The `Game Porting Toolkit.app` runner is installed from the Homebrew/Gcenx cask if a local or `/Applications` copy is not already present.

The installer searches mounted volumes and `~/Downloads` for:

```text
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

Mount GPTK 3.0 from Apple, then run:

```zsh
./install.zsh
```

The installer will:

- create toolkit folders;
- create or update `~/.rippermoon-gptk.env`;
- install helper commands into `~/bin`;
- install or verify host dependencies;
- install the prebuilt `Game Porting Toolkit.app` runner if needed;
- copy the Apple GPTK 3.0 runtime from mounted Apple media;
- download `SteamSetup.exe`;
- optionally start Windows Steam installation in the background without launching Steam after validation;
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
