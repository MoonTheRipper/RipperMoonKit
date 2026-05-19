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
3. Open the downloaded `.dmg` so it mounts under `/Volumes`, or leave the downloaded DMG in `~/Downloads`.
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

If `Game Porting Toolkit.app` is already installed in `/Applications`, the installer uses that as a source. If it is missing, the installer can use Homebrew to install the prebuilt Gcenx GPTK app cask:

```zsh
brew install --cask --no-quarantine gcenx/wine/game-porting-toolkit
```

The app is still copied into the toolkit folder so future macOS app updates or manual changes to `/Applications` do not silently change the runner used by RipperMoonKit.

GPTK 3's evaluation image stores the D3DMetal runtime under:

```text
Evaluation environment for Windows games 3.0/redist/lib
```

The installer installs local copies into:

```text
$GPTK_HOME/apps/Game Porting Toolkit.app
$GPTK_HOME/runtime
```

If GPTK is not mounted during a full install, the installer can open Apple's GPTK page, watch `/Volumes` and `~/Downloads`, attach the downloaded disk image, and continue after the media appears.

The launchers then use:

```zsh
export GPTK_WINE_HOME="$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine"
export GPTK_RUNTIME="$GPTK_HOME/runtime"
```

That local copy is intentional. It avoids compatibility changes caused by a system-wide `/Applications/Game Porting Toolkit.app` update while preserving the patched runners under `$GPTK_HOME/runners`.

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

Open Apple's GPTK page if GPTK media is missing:

```zsh
./install.zsh --open-gptk-page
```

Wait longer for the download/mount:

```zsh
./install.zsh --gptk-wait-seconds 1800
```

Disable GPTK waiting:

```zsh
./install.zsh --no-gptk-wait
```

## Why The User Must Download GPTK

This repository does not redistribute Apple Game Porting Toolkit, D3DMetal, or Apple's evaluation environment. Each user should download GPTK directly from Apple and use their own mounted copy during installation.
