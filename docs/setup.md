# Setup Guide

This toolkit is built around a simple rule: keep generated state outside the repository.

The repository contains scripts, examples, and documentation. Each user provides their own paths through environment variables.

## Recommended Layout

Internal SSD:

```text
$HOME/GPTK/
$HOME/GPTK/libexec/
$HOME/GPTK/logs/
$HOME/WinePrefixes/
$HOME/bin/
```

External storage:

```text
$GPTK_EXTERNAL_ROOT/
    Games/
    Installers/
    SteamLibrary/
```

These are defaults, not requirements. Change them in `~/.rippermoon-gptk.env`.

## Game Folder Workflow

For fragile Windows games and installers, prefer copying an already-installed Windows game folder into:

```text
$GPTK_EXTERNAL_ROOT/Games/<GameName>/
```

Do not copy only the installer files when the documentation says a pre-installed folder is required. Some installers do not behave well under this GPTK/Wine build, while the already-installed game folder can still run correctly.

For Elden Ring ERSC, the tested layout is:

```text
$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game/
    eldenring.exe
    ersc_launcher.exe
    SeamlessCoop/
```

## Configure Paths

Create a config file:

```zsh
cp env.example ~/.rippermoon-gptk.env
```

Edit it:

```zsh
open -e ~/.rippermoon-gptk.env
```

Important settings:

```zsh
export GPTK_EXTERNAL_ROOT="/Volumes/YourGameDrive"
export GPTK_PREFIX_ROOT="$HOME/WinePrefixes"
export GPTK_HOME="$HOME/GPTK"
export GPTK_APP_PATH="$GPTK_HOME/apps/Game Porting Toolkit.app"
export GPTK_WINE_HOME="$GPTK_APP_PATH/Contents/Resources/wine"
```

## Install

Before running the installer, download **Game Porting Toolkit 3** from Apple Developer and mount the DMG:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Leave the mounted GPTK volume available under `/Volumes`. If it contains a nested **Evaluation environment for Windows games 3.0** image, the installer will try to attach it automatically.

```zsh
./install.zsh
```

The installer writes a detailed log:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

It installs host dependencies, copies GPTK 3 from the mounted Apple media, downloads `SteamSetup.exe`, and verifies the GPTK/Wine runtime path. See [dependencies.md](dependencies.md) and [gptk.md](gptk.md) for details.

Open a new terminal, or reload shell config:

```zsh
source ~/.zshrc
```

Confirm the commands are visible:

```zsh
which gptk-launch
which gptk-steam
which gptk-game
```

## Prefix Model

A prefix is a Windows environment. Prefixes are isolated from each other, so games can have different registry settings, DLL overrides, and installed runtimes.

Named prefix:

```zsh
gptk-launch --prefix MyGame --init
```

Full-path prefix:

```zsh
gptk-launch --prefix "$HOME/WinePrefixes/MyGame" --init
```

The scripts create Wine drive mappings from `GPTK_DRIVE_MAPS` when the target folders exist:

```text
S: -> $GPTK_STEAM_LIBRARY
X: -> $GPTK_EXTERNAL_ROOT/Games
I: -> $GPTK_EXTERNAL_ROOT/Installers
```

You can map as many host folders as you want and choose the letters yourself, except for `C:`. Wine owns `C:` inside each prefix.

Example:

```zsh
export GPTK_DRIVE_MAPS="D=/Volumes/FastSSD;E=/Volumes/Archive;S=$GPTK_STEAM_LIBRARY;X=$GPTK_EXTERNAL_ROOT/Games"
```

See [drives.md](drives.md) for the full format.

## Logging

Logs default to:

```text
$GPTK_HOME/logs
```

Use a fixed log path when you are debugging one game repeatedly:

```zsh
gptk-launch --prefix MyGame --log-file "$GPTK_HOME/logs/MyGame-debug.log" -- ./Game.exe
```
