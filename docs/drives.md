# Custom Wine Drive Mappings

RipperMoonToolKit lets each user expose as many host folders as they want inside Wine. The mappings are controlled by `GPTK_DRIVE_MAPS`.

## Format

Use a semicolon-separated list:

```zsh
export GPTK_DRIVE_MAPS="LETTER=/host/path;LETTER=/another/host/path"
```

Examples:

```zsh
export GPTK_DRIVE_MAPS="S=$GPTK_STEAM_LIBRARY;X=$GPTK_EXTERNAL_ROOT/Games;I=$GPTK_EXTERNAL_ROOT/Installers"
export GPTK_DRIVE_MAPS="D=/Volumes/FastSSD;E=/Volumes/Archive;G=/Volumes/GameDrive/Games"
export GPTK_DRIVE_MAPS="S=/Volumes/GameCoreApp/SteamLibrary;X=/Volumes/GameCoreApp/Games;M=$HOME/Mods"
```

Letters are case-insensitive. `d=/Volumes/FastSSD` and `D=/Volumes/FastSSD` both create `D:`.

If the same letter appears more than once, the later mapping wins because the launcher refreshes symlink-based mappings each time it prepares a prefix.

## C: Is Reserved

Do not map `C:`.

Wine owns `C:` inside each prefix:

```text
$GPTK_PREFIX_ROOT/<PrefixName>/drive_c
```

The toolkit refuses `C=` or `C:=` style mappings so users cannot accidentally replace the prefix's own Windows drive.

## Missing Folders

Mappings are applied only when the target folder exists. This allows one config file to work across machines where not every external drive is mounted all the time.

Example:

```zsh
export GPTK_DRIVE_MAPS="D=/Volumes/FastSSD;E=/Volumes/Archive"
```

If `/Volumes/Archive` is not mounted, `E:` is skipped for that launch.

## When Mappings Apply

Mappings are refreshed when a launcher prepares a prefix:

```zsh
gptk-launch --prefix MyGame -- ./Game.exe
gptk-launch --prefix MyGame --init
gptk-steam --log
```

If you change `GPTK_DRIVE_MAPS`, stop running processes in that prefix and launch again.
