# Save Transfer Guide

Use this workflow when moving saves from Windows into a GPTK/Wine prefix.

## Find the Real Save Folder

The safest method is to start the game once, create a new save, quit, then search by modified time:

```zsh
find "$GPTK_PREFIX_ROOT" -type f \( -iname 'ER0000*' -o -iname '*.sl2' -o -iname '*.co2' \) -print -exec ls -lT {} \;
```

For Elden Ring under the Steam prefix, the folder usually looks like:

```text
$GPTK_PREFIX_ROOT/Steam/drive_c/users/crossover/AppData/Roaming/EldenRing/<steam-id>/
```

ERSC commonly uses:

```text
ER0000.co2
ER0000.co2.bak
```

Stock Elden Ring commonly uses:

```text
ER0000.sl2
ER0000.sl2.bak
```

## Back Up Before Replacing

```zsh
srcroot="/path/to/windows-save-backup"
dstroot="$GPTK_PREFIX_ROOT/Steam/drive_c/users/crossover/AppData/Roaming/EldenRing"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$GPTK_EXTERNAL_ROOT/saves_backup/Elden Ring/mac-prefix-before-restore/$stamp"

mkdir -p "$backup"
cp -pR "$dstroot"/* "$backup"/
```

## Restore Saves

Copy the Windows save files into the exact folder the game created:

```zsh
cp -p "$srcroot/<steam-id>/ER0000.co2" "$dstroot/<steam-id>/ER0000.co2"
cp -p "$srcroot/<steam-id>/ER0000.co2.bak" "$dstroot/<steam-id>/ER0000.co2.bak"
```

If your backup has multiple SteamID folders, keep them as separate folders under `EldenRing/`.

## Verify

```zsh
shasum -a 256 "$srcroot/<steam-id>/ER0000.co2" "$dstroot/<steam-id>/ER0000.co2"
```

The hashes should match.

If the game still only shows `New Game`, the path is probably correct but the save is being rejected because of account binding, game version, mod save format, or save header data.

