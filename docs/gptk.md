# Apple Game Porting Toolkit 3

RipperMoonToolKit targets Apple's Game Porting Toolkit 3, specifically the GPTK 3 evaluation environment for Windows games.

Apple provides GPTK through Apple Developer:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

Apple's current Game Porting Toolkit page identifies **Game Porting Toolkit 3** and links the **evaluation environment for Windows games**. Download it from Apple, then mount the DMG before running this toolkit installer.

## User Install Flow

1. Go to Apple's Game Porting Toolkit page:

```text
https://developer.apple.com/games/game-porting-toolkit/
```

2. Download **Game Porting Toolkit 3**.
3. Open the downloaded `.dmg` so it mounts under `/Volumes`.
4. If the DMG contains a nested **Evaluation environment for Windows games 3.0** image, leave the main DMG mounted; `install.zsh` will try to attach the nested image automatically.
5. Run:

```zsh
./install.zsh
```

The installer searches mounted volumes for:

```text
Game Porting Toolkit.app
Evaluation environment for Windows games 3.0
```

It installs local copies into:

```text
$GPTK_HOME/apps/Game Porting Toolkit.app
$GPTK_HOME/runtime
```

The launchers then use:

```zsh
export GPTK_WINE_HOME="$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine"
export GPTK_RUNTIME="$GPTK_HOME/runtime"
```

## Installer Flags

Force reinstall from mounted media:

```zsh
./install.zsh --reinstall-gptk
```

Search a specific mounted GPTK folder first:

```zsh
./install.zsh --gptk-source "/Volumes/Game Porting Toolkit"
```

Skip GPTK copy/install:

```zsh
./install.zsh --skip-gptk
```

## Why The User Must Download GPTK

This repository does not redistribute Apple Game Porting Toolkit, D3DMetal, or Apple's evaluation environment. Each user should download GPTK directly from Apple and use their own mounted copy during installation.
