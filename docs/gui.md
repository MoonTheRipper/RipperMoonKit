# SwiftUI Launcher

RipperMoonKit now includes a native SwiftUI launcher target:

```text
RipperMoonKitLauncher
```

The launcher reads `~/.rippermoon-gptk.env`, shows the active GPTK paths, validates the Elden Ring ERSC folder layout, starts and stops Windows Steam, launches ERSC with the tested DLL overrides, and exposes install, update, uninstall, backup, and rollback actions.

## Build

```zsh
cd RipperMoonToolKit
swift build
```

## Run

```zsh
cd RipperMoonToolKit
swift run RipperMoonKitLauncher
```

## Install Local App

Build and install a local `.app` bundle:

```zsh
cd RipperMoonToolKit
zsh scripts/install-gui-app.zsh
```

Default install path:

```text
~/Applications/RipperMoonKit Launcher.app
```

Install to a custom path:

```zsh
zsh scripts/install-gui-app.zsh "$HOME/Desktop/RipperMoonKit Launcher.app"
```

If a previous app exists, the script backs it up under:

```text
$GPTK_HOME/backups/gui-app-YYYYmmdd-HHMMSS
```

## Default ERSC Profile

The first profile is the tested Elden Ring ERSC path:

```text
prefix: Steam
winver: win10
runner: $HOME/GPTK/runners/gptk-dsound-nocap-20260513
dll overrides: winmm=n,b;steam_api64=n,b
game folder: $GPTK_EXTERNAL_ROOT/Games/EldenRing/Game
```

The launcher emits the same command line that can be run manually:

```zsh
cd "EXE PATH"
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  /Users/USERNAME/bin/gptk-launch \
    --prefix Steam \
    --set-winver win10 \
    --no-dxr \
    --log-file "/Users/USERNAME/GPTK/logs/ERSC-gui.log" \
    -- ./ersc_launcher.exe
```

## Design Direction

The interface follows current Apple platform conventions:

- `NavigationSplitView` for a source list and focused detail pane.
- SF Symbols for actions and state.
- System materials and standard controls instead of custom chrome.
- Compact dashboard panels with validation, command previews, and rollback state.
- A compatibility-profile model so other games can be added without hard-coding one-off launchers.

The logo resource is:

```text
Sources/RipperMoonKitLauncher/Resources/RipperMoonKitLogo.jpg
```

It was copied from the local image:

```text
~/Pictures/Wallpaper Screen/wallpaperflare.com_wallpaper (31).jpg
```

## Next GUI Work

Planned app packaging work:

- Sign and notarize release `.app` builds.
- Add first-run guided setup for GPTK media, external drives, Steam, and game folders.
- Add saved compatibility profiles for other games.
- Add launch status checks for long-running Steam/game processes.
- Add safer restore flows for optional user-selected save snapshots.

## Maintenance Buttons

The Settings view includes:

- **Install Toolkit**: runs `./install.zsh --skip-deps` and creates a rollback backup first.
- **Install GPTK**: runs the full installer with `RIPPERMOON_OPEN_GPTK_PAGE=1`; if GPTK is missing, Apple's GPTK page opens and the installer waits for the DMG.
- **Update From GitHub**: fetches `origin/main`, fast-forwards the repo, reinstalls toolkit scripts, and rebuilds the local `.app`.
- **Install .app**: rebuilds and installs `~/Applications/RipperMoonKit Launcher.app`.
- **Uninstall Toolkit**: removes toolkit scripts and the app. Configs and Wine prefixes/saves are kept unless their checkboxes are enabled.

The uninstall defaults are intentionally conservative:

```text
keep ~/.rippermoon-gptk.env
keep $GPTK_PREFIX_ROOT
keep games, Steam libraries, GPTK runtimes, patched runners, and backups
```
