# Dependency Bootstrap

`install.zsh` performs a dependency bootstrap with a timestamped log and emoji-prefixed progress messages.

Logs are written to:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

## What The Installer Handles

The default install does this:

1. Creates the local toolkit folders.
2. Installs `gptk-launch`, `gptk-steam`, `gptk-game`, `gptk-stubs`, and `gptk-dsound-nocap`.
3. Installs the prebuilt helper binaries (`GameInput.dll` stub and the no-capture `dsound` proxies) so no compiler is needed at runtime.
4. Creates `~/.rippermoon-gptk.env` from `env.example` if it does not exist.
5. Adds `~/bin` and the config source line to `~/.zshrc`.
6. Installs Rosetta on Apple Silicon if needed.
7. Installs the Xcode Command Line Tools if they are missing (required before Homebrew).
8. Installs Homebrew if it is missing.
9. Installs Homebrew formulae used by the toolkit and common Wine/GPTK troubleshooting.
10. Installs the prebuilt `Game Porting Toolkit.app` runner with Homebrew if no local/system copy exists.
11. Installs/copies the Apple GPTK 3 evaluation runtime from the user's mounted Apple GPTK media, or prompts/waits for the user to download and mount it.
12. Downloads `SteamSetup.exe` to the configured installer path.
13. Checks whether Apple Game Porting Toolkit or another `wine64` is available.

The dependency steps are resilient: one failed step (for example a single
Homebrew formula) is logged as a warning and does not abort the rest, so the
critical Apple GPTK runtime copy still runs. The installer prints a
prerequisite summary at the end, and `./install.zsh --check` reports the same
status at any time without changing anything.

Profile-specific helpers can install additional Windows runtimes inside Wine prefixes:

- `gptk-vcrun`: Microsoft Visual C++ runtime.
- `gptk-dotnet6`: Microsoft .NET 6 Desktop Runtime, used by Elden Ring Randomizer.

## Homebrew Formulae

Default formulae:

```text
cabextract p7zip samba gnutls molten-vk vulkan-loader vulkan-headers
```

Why they are included:

- `samba`: provides `ntlm_auth`, which Wine may need for NTLM support.
- `cabextract`: useful for Windows redistributable extraction workflows.
- `p7zip`: handles common archive formats used by portable Windows game folders.
- `gnutls`: supports Wine networking/TLS dependency paths.
- `molten-vk`, `vulkan-loader`, `vulkan-headers`: support Vulkan/DXVK experiments.

Override the list:

```zsh
RIPPERMOON_BREW_FORMULAE="samba cabextract p7zip" ./install.zsh
```

## Game Porting Toolkit App Cask

The Apple GPTK 3 DMG supplies the official evaluation runtime, but current GPTK 3 media does not provide `Game Porting Toolkit.app`. RipperMoonKit can install the prebuilt app runner through Homebrew/Gcenx:

```text
gcenx/wine/game-porting-toolkit
```

The app is then copied into:

```text
$GPTK_HOME/apps/Game Porting Toolkit.app
```

Override or disable the automatic cask step:

```zsh
RIPPERMOON_GPTK_APP_CASK="gcenx/wine/game-porting-toolkit" ./install.zsh
RIPPERMOON_INSTALL_GPTK_APP_CASK=0 ./install.zsh
```

## Steam Installer Download

By default, the installer downloads `SteamSetup.exe` from Valve's Steam CDN:

```text
https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
```

The file is saved to:

```text
~/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe
```

Override the URL or path:

```zsh
STEAM_SETUP_URL="https://example.invalid/SteamSetup.exe" ./install.zsh
STEAM_SETUP_PATH="$HOME/Downloads/SteamSetup.exe" ./install.zsh
```

Skip the download:

```zsh
./install.zsh --skip-steam-download
```

## .NET 6 Desktop Runtime

Elden Ring Item and Enemy Randomizer is a Windows .NET desktop app. It needs the **.NET 6 Desktop Runtime** installed inside the same Wine prefix that launches the randomizer. RipperMoonKit treats that as a tools prefix, separate from the live game/Steam prefix.

RipperMoonKit provides:

```zsh
gptk-dotnet6 --prefix EldenRingToolsStaging
```

The helper downloads and caches the Windows x64 desktop runtime from Microsoft's .NET 6 channel URL:

```text
https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.exe
```

Override the URL or cache folder:

```zsh
RIPPERMOON_DOTNET6_DESKTOP_URL="https://example.invalid/windowsdesktop-runtime.exe" gptk-dotnet6 --prefix Steam
RIPPERMOON_DOTNET6_DIR="$GPTK_HOME/downloads/dotnet6" gptk-dotnet6 --download-only
```

.NET 6 is end-of-life, but the randomizer is built for it. The runtime is installed only into the selected Wine prefix.

### Wine Staging (required for the randomizer GUI)

The randomizer GUI runs under **Wine Staging**, not the Game Porting Toolkit runner. Under GPTK's Wine 7.7 its .NET WinForms window crashes with a UIAutomation stack overflow before it appears, so the launcher refuses to run it there and prompts you to install Wine Staging instead. Game launches still use GPTK/D3DMetal — only the randomizer tool window uses Wine Staging, in its own `EldenRingToolsStaging` prefix.

RipperMoonKit does not bundle Wine Staging (it is a separate, third-party runtime). Install it once with Homebrew:

```zsh
brew install --cask wine@staging
xattr -dr com.apple.quarantine "/Applications/Wine Staging.app"
```

The app's Mod Files panel has an **Install Wine Staging** button that runs this in a Terminal window (it may ask for your Mac password, for Wine Staging's GStreamer runtime). After it installs, click **Run Randomizer** again. `install.zsh --check` reports whether Wine Staging is present.

## Installing Windows Steam

The default source install downloads `SteamSetup.exe` but does not run the Windows Steam installer, because that creates or modifies the Steam Wine prefix.

The guided app setup starts Steam installation in the background. The user can move to the finished screen, set game folders, and add cover art while Steam validates `steam.exe`. After validation, Steam is closed instead of launched.

To install Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

To start Steam installation in the background:

```zsh
./install.zsh --install-steam-background
```

## Apple Game Porting Toolkit

Apple Game Porting Toolkit is not redistributed by this project. Download **Game Porting Toolkit 3** from Apple Developer, mount the DMG, then run:

```zsh
./install.zsh
```

The installer searches the mounted GPTK media for the official runtime and installs local copies to:

```text
$GPTK_HOME/apps/Game Porting Toolkit.app
$GPTK_HOME/runtime
```

Use `./install.zsh --gptk-source "/Volumes/Game Porting Toolkit"` if the mounted volume is not detected automatically.

If GPTK is not mounted, the installer can open Apple's official page, watch `/Volumes` and `~/Downloads`, attach a matching GPTK `.dmg`, and continue when the media appears:

```zsh
./install.zsh --open-gptk-page
```

The default wait is 900 seconds. To wait longer:

```zsh
./install.zsh --gptk-wait-seconds 1800
```

To disable the wait:

```zsh
./install.zsh --no-gptk-wait
```

See [gptk.md](gptk.md).

## Useful Installer Flags

Copy scripts only:

```zsh
./install.zsh --skip-deps
```

Do not install Homebrew automatically:

```zsh
./install.zsh --no-homebrew-bootstrap
```

Do not edit `~/.zshrc`:

```zsh
./install.zsh --no-zshrc
```

Skip GPTK copy/install:

```zsh
./install.zsh --skip-gptk
```
