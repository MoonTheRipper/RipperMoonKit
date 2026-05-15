# SwiftUI Launcher

RipperMoonKit now includes a native SwiftUI launcher target:

```text
RipperMoonKitLauncher
```

The launcher reads `~/.rippermoon-gptk.env`, shows a list of configured apps/games, opens each app into its own launch settings, validates that app's folder layout, starts and stops Windows Steam when the profile requires it, closes the selected game without stopping Steam, installs Microsoft Visual C++ runtime packages per prefix, and exposes install, update, uninstall, backup, and rollback actions.

![RipperMoonKit launcher showing an Elden Ring ERSC profile](assets/rippermoonkit-gui.png)

The app is organized around individual games and apps. Pick a profile on the left, then adjust that profile's icon, folder, prefix, runner, and launch options on the right.

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
$GPTK_HOME/backups/gui-app-YYYYmmdd-HHMMSS.noindex
```

The backup copy is stored as `.app.backup` so Spotlight does not show old launcher backups as separate installed apps.

## Apps And Games

The sidebar is centered on user-owned app/game profiles. Each profile stores its own:

```text
name
prefix
game folder
executable
icon path
runner path
Windows version
Steam requirement
DLL overrides
DXR/esync/HUD/MetalFX-DLSS toggles
validation files
launch command preview
```

Use **Add App** to create another app/game profile. The profile command preview lives inside that app's page, not in global Settings.

Each profile can point at its own icon image. The sidebar row, the app settings preview, and the large square icon in the page header use that profile icon when configured. This is intentionally a user-selected image path, because the best icon is not always embedded in the Windows `.exe`.

The MetalFX/DLSS toggle is for games that expose DLSS in their own graphics menu. It adds `--metalfx` and prefers GPTK's built-in `nvapi64` and `nvngx` bridge DLLs for that launch.

The **Close Game** action uses Wine `taskkill` against the selected profile's executable name. For the default ERSC profile, it also targets `eldenring.exe`. It does not stop the Steam prefix or run `wineserver -k`.

The per-profile **Install VC++ Runtime** action runs `gptk-vcrun --prefix PROFILE_PREFIX`. Settings > Maintenance also has a global install action that runs `gptk-vcrun --all`.

## Default ERSC Profile

The first profile is the tested Elden Ring ERSC path:

```text
prefix: Steam
winver: win10
runner: $HOME/GPTK/runners/gptk-dsound-nocap-20260513
dll overrides: winmm=n,b;steam_api64=n,b
game folder: $GPTK_EXTERNAL_ROOT/Games/EldenRing/Game
```

The launcher repairs this profile on load and immediately before starting Steam or ERSC. If the profile is empty, missing its required ERSC options, or points back to stock GPTK while the patched runner exists, the GUI restores the Golden Pot-safe defaults.

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

The Roadmap section is intentionally not part of the app UI. Roadmap details remain in GitHub documentation.

The logo resource is:

```text
Sources/RipperMoonKitLauncher/Resources/RipperMoonKitLogo.jpg
```

When `scripts/install-gui-app.zsh` packages the local app, it also crops this image into a square macOS icon set and writes:

```text
~/Applications/RipperMoonKit Launcher.app/Contents/Resources/RipperMoonKitLogo.icns
```

The app bundle points `CFBundleIconFile` at that icon so Finder, Dock, and app switcher use the same artwork as the in-app logo.

It was copied from the local image:

```text
~/Pictures/Wallpaper Screen/wallpaperflare.com_wallpaper (31).jpg
```

## First Run Setup

The app shows the setup guide only when the toolkit is not ready and the guide has not already been dismissed. A missing path is still shown in the guide when opened, but clicking **Done** suppresses automatic repeats.

The setup guide has actions for:

```text
Install Toolkit
Install GPTK
Open Apple GPTK Page
```

The GPTK action runs the installer with `RIPPERMOON_OPEN_GPTK_PAGE=1`, so if GPTK is not present it opens Apple's page, watches `/Volumes` and `~/Downloads`, and continues when the user mounts or downloads GPTK media.

GPTK detection accepts the configured `GPTK_WINE_HOME`, a copied GPTK app under `$GPTK_HOME/apps`, Apple's `/Applications/Game Porting Toolkit.app`, and patched runners under `$GPTK_HOME/runners`.

## Path And Drive Settings

The Settings page contains editable paths:

```text
GPTK Home
Prefix Root
Games Root
External Root
Steam Library
Toolkit Source
```

It also includes a Drive Mappings editor. Users can add any drive letter except `C`, choose a host folder, and save the result back to `GPTK_DRIVE_MAPS` in `~/.rippermoon-gptk.env`.

## Next GUI Work

Planned app work:

- Sign and notarize release `.app` builds.
- Add launch status checks for long-running Steam/game processes.
- Add safer restore flows for optional user-selected save snapshots.
- Add import/export for app profile presets.

## Maintenance Buttons

The Settings view includes:

- **Install Toolkit**: runs `./install.zsh --skip-deps` and creates a rollback backup first.
- **Install GPTK**: runs the full installer with `RIPPERMOON_OPEN_GPTK_PAGE=1`; if GPTK is missing, Apple's GPTK page opens and the installer waits for the DMG.
- **Update From GitHub**: fetches `origin/main`, fast-forwards the repo, reinstalls toolkit scripts, and rebuilds the local `.app`.
- **Uninstall Toolkit**: removes toolkit scripts and the app. Configs and Wine prefixes/saves are kept unless their checkboxes are enabled.

The uninstall defaults are intentionally conservative:

```text
keep ~/.rippermoon-gptk.env
keep $GPTK_PREFIX_ROOT
keep games, Steam libraries, GPTK runtimes, patched runners, and backups
```
