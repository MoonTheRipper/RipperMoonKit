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

For the macOS app first, download the latest DMG, open it, and drag **RipperMoonKit Launcher.app** into Applications:

```text
https://github.com/MoonTheRipper/RipperMoonKit/releases/latest/download/RipperMoonKit-Launcher.dmg
```

Open the app and follow the first-run setup prompts.

After the app is installed:

1. Open **RipperMoonKit Launcher.app**.
2. If macOS blocks it, allow it in **System Settings > Privacy & Security**.
3. Use the first-run setup guide to connect GPTK 3.
4. If GPTK is missing, download **Game Porting Toolkit 3** from Apple, mount the DMG, then return to the app and run setup.
5. Check **Settings > Paths** so the app knows where GPTK, prefixes, games, external storage, and Steam libraries live.
6. Install Windows Steam from the **Steam** profile when a game needs Steam. Steam is not bundled in the DMG.
7. For Elden Ring ERSC or other co-op Steamworks test paths, use the Steam profile's **Install Spacewar** button once, wait for AppID 480 setup, then close Spacewar.
8. Open or add a game profile, set its folder/executable, and launch.

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
- copy GPTK 3 from the mounted Apple media;
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

If you did not use `./install.zsh --install-steam`, install Steam after bootstrap:

```zsh
gptk-steam --install "$HOME/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe"
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
