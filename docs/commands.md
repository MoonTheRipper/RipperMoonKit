# Command Reference

## install.zsh

Install the toolkit and bootstrap dependencies:

```zsh
./install.zsh
```

Install Windows Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

Use a specific mounted GPTK source:

```zsh
./install.zsh --gptk-source "/Volumes/Game Porting Toolkit"
```

Reinstall GPTK from mounted media:

```zsh
./install.zsh --reinstall-gptk
```

Copy scripts only:

```zsh
./install.zsh --skip-deps
```

Create a rollback backup without installing:

```zsh
./install.zsh --skip-deps --backup-only
```

List rollback backups:

```zsh
./install.zsh --list-backups
```

Rollback toolkit scripts/config:

```zsh
./install.zsh --rollback rippermoon-update-YYYYmmdd-HHMMSS
```

Install without a rollback backup:

```zsh
./install.zsh --no-backup
```

Skip GPTK copy:

```zsh
./install.zsh --skip-gptk
```

Skip SteamSetup download:

```zsh
./install.zsh --skip-steam-download
```

Do not edit `~/.zshrc`:

```zsh
./install.zsh --no-zshrc
```

## gptk-launch

General form:

```zsh
gptk-launch --prefix PrefixName -- /path/to/program.exe
```

Initialize a prefix:

```zsh
gptk-launch --prefix MyGame --init
```

Set Windows version:

```zsh
gptk-launch --prefix MyGame --set-winver win10
```

Open Wine config:

```zsh
gptk-launch --prefix MyGame --winecfg
```

Run a Wine tool:

```zsh
gptk-launch --prefix MyGame -- regedit
gptk-launch --prefix MyGame -- cmd
```

Run with a fixed log:

```zsh
gptk-launch --prefix MyGame --log-file "$GPTK_HOME/logs/MyGame.log" -- ./MyGame.exe
```

Useful toggles:

```zsh
gptk-launch --prefix MyGame --hud -- ./MyGame.exe
gptk-launch --prefix MyGame --no-dxr -- ./MyGame.exe
gptk-launch --prefix MyGame --dxvk -- ./MyGame.exe
gptk-launch --prefix MyGame --no-esync -- ./MyGame.exe
```

## gptk-steam

Install Steam:

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

Repair Steam compatibility settings:

```zsh
gptk-steam --repair-compat
```

Launch Spacewar/AppID 480:

```zsh
gptk-steam --log -applaunch 480
```

## gptk-vcrun

Download and install the latest Microsoft Visual C++ v14 runtime into one prefix:

```zsh
gptk-vcrun --prefix Dispatch
```

Install into every existing Wine prefix under `GPTK_PREFIX_ROOT`:

```zsh
gptk-vcrun --all
```

Archived prefixes ending in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped.

Download without installing:

```zsh
gptk-vcrun --download-only
```

## Elden Ring ERSC With Golden Pot Fix

Start Steam with the DirectSound no-capture runner:

```zsh
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  gptk-steam --no-log
```

Launch ERSC from the copied game folder:

```zsh
cd "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --log-file "$GPTK_HOME/logs/ERSC-dsound-nocap.log" -- ./ersc_launcher.exe
```

Fully expanded placeholder form:

```zsh
cd "EXE PATH"
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  /Users/USERNAME/bin/gptk-launch \
    --prefix Steam \
    --set-winver win10 \
    --no-dxr \
    --log-file "/Users/USERNAME/GPTK/logs/ERSC-dsound-nocap.log" \
    -- ./ersc_launcher.exe
```

## gptk-game

Create a per-game launcher:

```zsh
gptk-game create "Game Name" "$GPTK_EXTERNAL_ROOT/Games/Game/Game.exe" --init
```

Create a launcher using an existing prefix:

```zsh
gptk-game create "Game Name" "$GPTK_EXTERNAL_ROOT/Games/Game/Game.exe" --prefix Steam --workdir "$GPTK_EXTERNAL_ROOT/Games/Game"
```

Run a generated launcher:

```zsh
gptk-game run "Game Name"
```

List generated launchers:

```zsh
gptk-game list
```

## SwiftUI Launcher

Build:

```zsh
swift build
```

Run:

```zsh
swift run RipperMoonKitLauncher
```

Install local `.app` bundle:

```zsh
zsh scripts/install-gui-app.zsh
```

Uninstall toolkit scripts and local app while keeping configs/saves:

```zsh
zsh scripts/uninstall.zsh
```
