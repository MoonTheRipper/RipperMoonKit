# Quickstart

This is the shortest path to a working RipperMoonToolKit install.

If you installed from the DMG and want a simpler app-first guide, read [normal-user-guide.md](normal-user-guide.md).

For a visual example of the app and Elden Ring running on macOS, see [proof-of-concept.md](proof-of-concept.md).

## 1. Download GPTK 3 From Apple

Open Apple's Game Porting Toolkit page:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Download **Game Porting Toolkit 3**.

Open the downloaded `.dmg` so it mounts under `/Volumes`.

Leave it mounted while running the installer. If it contains a nested **Evaluation environment for Windows games 3.0** image, the installer will try to mount that nested image automatically.

## 2. Choose Install Method

For the macOS app first, download the latest DMG, open it, and run **Install to My Applications.command** or copy **RipperMoonKit Launcher.app** into your user Applications folder:

```text
https://github.com/MoonTheRipper/RipperMoonKit/releases/latest/download/RipperMoonKit-Launcher.dmg
```

The app should be installed here:

```text
~/Applications/RipperMoonKit Launcher.app
```

Do not install it into `/Applications` unless you intentionally want every macOS user on the machine to share the same app copy.

Open the app and follow the first-run setup prompts.

After the app is installed:

1. Open **RipperMoonKit Launcher.app**.
2. If macOS blocks it, allow it in **System Settings > Privacy & Security**.
3. Use the first-run setup guide to connect GPTK 3.
4. If GPTK is missing, download **Game Porting Toolkit 3** from Apple, mount the DMG, then return to the app and run setup.
5. Setup starts Windows Steam installation in the background. Steam can take several minutes, but you can move on while it finishes.
6. When the **You're all set** screen appears, open the **Steam** profile when you are ready to sign in. If Steam is still installing, use the time to set paths and cover art.
7. Check **Settings > Paths** so the app knows where GPTK, prefixes, games, external storage, and Steam libraries live.
8. Add or open a game profile. Use a copied, already-installed Windows game folder, not installer files.
9. Add a free TheGamesDB API key in settings if you want cover art.
10. For Elden Ring ERSC or other co-op Steamworks test paths, use the Steam profile's **Install Spacewar** button once, wait for AppID 480 setup, then close Spacewar.
11. Set the game executable and launch.

For the source and command-line helper install, continue below.

## 3. Install From Source

```zsh
cd RipperMoonToolKit
./install.zsh
```

The installer will:

- create the toolkit folders;
- create a rollback backup for any existing toolkit config/scripts;
- install the launcher scripts;
- create `~/.rippermoon-gptk.env` if missing;
- install Rosetta when needed;
- install Homebrew when missing;
- install Homebrew dependencies;
- install the prebuilt `Game Porting Toolkit.app` runner if needed;
- copy the Apple GPTK 3 runtime from the mounted Apple media;
- download `SteamSetup.exe`;
- write a timestamped install log.

Update backups are stored under:

```zsh
ls -lt "$GPTK_HOME/backups"
```

## 4. Reload Shell

```zsh
source ~/.zshrc
```

Confirm commands are available:

```zsh
which gptk-launch
which gptk-steam
which gptk-game
```

## 5. Install Steam

If you did not use guided setup, start Steam installation after bootstrap in the background:

```zsh
./install.zsh --install-steam-background
```

In the GUI, use the Steam tile. It shows **Install Steam** until `steam.exe` validates inside the Steam prefix, then shows **Repair Steam**.

Start Steam:

```zsh
gptk-steam --log
```

Stop Steam:

```zsh
gptk-steam --kill
```

## 6. Run A Game

For a copied/pre-installed game folder:

```zsh
cd "$GPTK_EXTERNAL_ROOT/Games/MyGame"
gptk-launch --prefix MyGame -- ./MyGame.exe
```

For a game that depends on the Steam client, launch it from the same prefix as Steam, usually:

```zsh
gptk-launch --prefix Steam -- ./GameLauncher.exe
```

## 7. Optional SwiftUI Launcher From Source

```zsh
zsh scripts/install-gui-app.zsh
```

The launcher gives each game its own page:

![RipperMoonKit launcher showing the Elden Ring ERSC profile](assets/rippermoonkit-gui.png)

## Logs

Installer logs:

```zsh
ls -lt "$GPTK_HOME/logs"/rippermoon-install-*.log | head
```

Launcher logs:

```zsh
ls -lt "$GPTK_HOME/logs" | head
```
