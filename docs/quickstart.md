# Quickstart

This is the shortest path to a working RipperMoonToolKit install.

For a visual example of the app and Elden Ring running on macOS, see [proof-of-concept.md](proof-of-concept.md).

## 1. Download GPTK 3 From Apple

Open Apple's Game Porting Toolkit page:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Download **Game Porting Toolkit 3**.

Open the downloaded `.dmg` so it mounts under `/Volumes`.

Leave it mounted while running the installer. If it contains a nested **Evaluation environment for Windows games 3.0** image, the installer will try to mount that nested image automatically.

## 2. Install The Toolkit

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

## 3. Reload Shell

```zsh
source ~/.zshrc
```

Confirm commands are available:

```zsh
which gptk-launch
which gptk-steam
which gptk-game
```

## 4. Install Steam

If you did not use `./install.zsh --install-steam`, install Steam after bootstrap:

```zsh
gptk-steam --install "$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe"
```

Start Steam:

```zsh
gptk-steam --log
```

Stop Steam:

```zsh
gptk-steam --kill
```

## 5. Run A Game

For a copied/pre-installed game folder:

```zsh
cd "$GPTK_EXTERNAL_ROOT/Games/MyGame"
gptk-launch --prefix MyGame -- ./MyGame.exe
```

For a game that depends on the Steam client, launch it from the same prefix as Steam, usually:

```zsh
gptk-launch --prefix Steam -- ./GameLauncher.exe
```

## 6. Optional SwiftUI Launcher

```zsh
swift run RipperMoonKitLauncher
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
