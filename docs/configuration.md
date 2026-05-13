# Configuration Reference

RipperMoonToolKit reads configuration from:

```text
~/.rippermoon-gptk.env
```

The installer creates this file from `env.example` when it does not already exist.

## Core Paths

```zsh
export GPTK_HOME="$HOME/GPTK"
```

Toolkit state: logs, installed helper library, copied GPTK app, and copied GPTK runtime.

```zsh
export GPTK_PREFIX_ROOT="$HOME/WinePrefixes"
```

Where Wine prefixes are created.

```zsh
export GPTK_GAMES_ROOT="$HOME/Games"
```

Where `gptk-game` writes generated per-game launcher scripts.

```zsh
export GPTK_EXTERNAL_ROOT="/Volumes/GameCoreApp"
```

Default external storage root.

```zsh
export GPTK_STEAM_LIBRARY="$GPTK_EXTERNAL_ROOT/SteamLibrary"
```

Default external Steam library folder.

## GPTK Paths

```zsh
export GPTK_REQUIRED_VERSION="3"
export GPTK_APP_PATH="$GPTK_HOME/apps/Game Porting Toolkit.app"
export GPTK_RUNTIME="$GPTK_HOME/runtime"
export GPTK_WINE_HOME="$GPTK_APP_PATH/Contents/Resources/wine"
```

The installer copies the mounted Apple GPTK app/runtime into these paths.

Patched or experimental runners should live outside git, for example:

```zsh
export GPTK_WINE_HOME="$GPTK_HOME/runners/gptk-dsound-nocap-20260513"
```

Use that form only for launches that need the patched runner. The runner directory can be large and must not be committed.

## Drive Maps

```zsh
export GPTK_DRIVE_MAPS="S=$GPTK_STEAM_LIBRARY;X=$GPTK_EXTERNAL_ROOT/Games;I=$GPTK_EXTERNAL_ROOT/Installers"
```

Format:

```zsh
LETTER=/host/path;LETTER=/another/host/path
```

Use any letter except `C`. Wine owns `C:` inside each prefix.

## Runtime Toggles

```zsh
export GPTK_DEFAULT_WINVER="win10"
export GPTK_LOG_ENABLED="1"
export GPTK_WINEESYNC="1"
export GPTK_DXR="1"
export GPTK_USE_DXVK="0"
export GPTK_MTL_HUD_ENABLED="0"
```

These defaults can be overridden per command:

```zsh
gptk-launch --prefix MyGame --no-dxr -- ./Game.exe
gptk-launch --prefix MyGame --hud -- ./Game.exe
gptk-launch --prefix MyGame --no-esync -- ./Game.exe
```

## Installer Settings

```zsh
export STEAM_SETUP_URL="https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
export STEAM_SETUP_PATH="$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe"
export RIPPERMOON_BREW_FORMULAE="cabextract p7zip samba gnutls molten-vk vulkan-loader vulkan-headers"
export RIPPERMOON_INSTALL_STEAM="0"
```

To install a smaller dependency set:

```zsh
RIPPERMOON_BREW_FORMULAE="samba cabextract p7zip" ./install.zsh
```
