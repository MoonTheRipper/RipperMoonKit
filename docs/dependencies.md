# Dependency Bootstrap

`install.zsh` performs a dependency bootstrap with a timestamped log and emoji-prefixed progress messages.

Logs are written to:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

## What The Installer Handles

The default install does this:

1. Creates the local toolkit folders.
2. Installs `gptk-launch`, `gptk-steam`, and `gptk-game`.
3. Creates `~/.rippermoon-gptk.env` from `env.example` if it does not exist.
4. Adds `~/bin` and the config source line to `~/.zshrc`.
5. Installs Rosetta on Apple Silicon if needed.
6. Installs Homebrew if it is missing.
7. Installs Homebrew formulae used by the toolkit and common Wine/GPTK troubleshooting.
8. Installs/copies Game Porting Toolkit 3 from the user's mounted Apple GPTK media, or prompts/waits for the user to download and mount it.
9. Downloads `SteamSetup.exe` to the configured installer path.
10. Checks whether Apple Game Porting Toolkit or another `wine64` is available.

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

## Steam Installer Download

By default, the installer downloads `SteamSetup.exe` from Valve's Steam CDN:

```text
https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
```

The file is saved to:

```text
$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe
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

For the randomizer GUI, RipperMoonKit prefers Wine Staging 11.8 when available. This avoids a GPTK/Wine 7.7 WinForms UIAutomation stack overflow seen before the randomizer window appears. Game launches still use GPTK/D3DMetal unless a profile explicitly selects a different runner.

## Installing Windows Steam

The default install downloads `SteamSetup.exe` but does not run the Windows Steam installer, because that creates or modifies the Steam Wine prefix.

To install Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

## Apple Game Porting Toolkit

Apple Game Porting Toolkit is not redistributed by this project. Download **Game Porting Toolkit 3** from Apple Developer, mount the DMG, then run:

```zsh
./install.zsh
```

The installer searches the mounted GPTK media and installs local copies to:

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
