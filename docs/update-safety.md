# Update Safety And Rollback

RipperMoonToolKit updates are designed to protect local game state. The installer updates small toolkit files, but it does not delete or rewrite Wine prefixes, saves, Steam libraries, installed games, GPTK runtimes, or patched runners.

## What Gets Backed Up

Before an install or update, `install.zsh` creates a timestamped backup under:

```text
$GPTK_HOME/backups/rippermoon-update-YYYYmmdd-HHMMSS
```

The backup includes:

```text
~/.rippermoon-gptk.env
~/.zshrc
~/bin/gptk-launch
~/bin/gptk-steam
~/bin/gptk-game
$GPTK_HOME/libexec/gptk-common.zsh
```

It also records protected state paths in `protected-paths.tsv`:

```text
$GPTK_PREFIX_ROOT
$GPTK_GAMES_ROOT
$GPTK_EXTERNAL_ROOT
$GPTK_EXTERNAL_ROOT/Games
$GPTK_STEAM_LIBRARY
$GPTK_APP_PATH
$GPTK_RUNTIME
```

Those protected paths are recorded for audit. They are not overwritten by rollback.

If one of the small toolkit files did not exist before an update, the backup records it in `absent.tsv`. Rollback removes those newly created toolkit files so the local install can return to its previous shape.

## Commands

Create a backup without installing:

```zsh
./install.zsh --skip-deps --backup-only
```

List available backups:

```zsh
./install.zsh --list-backups
```

Rollback toolkit scripts and config from a backup:

```zsh
./install.zsh --rollback rippermoon-update-YYYYmmdd-HHMMSS
```

Rollback from an absolute backup path:

```zsh
./install.zsh --rollback "$GPTK_HOME/backups/rippermoon-update-YYYYmmdd-HHMMSS"
```

Install without creating a backup:

```zsh
./install.zsh --no-backup
```

## Extra Protected Snapshots

For one-off migrations, add extra files or folders to the backup with a semicolon-separated list:

```zsh
RIPPERMOON_BACKUP_EXTRA_PATHS="$HOME/WinePrefixes/Steam/drive_c/users/$USER/AppData/Roaming/EldenRing;$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  ./install.zsh --skip-deps --backup-only
```

Extra snapshots are stored under `extra/` inside the backup. They are not restored automatically, because saves can change after a rollback point.

## Safe Update Flow

Use this flow before updating an existing install:

```zsh
cd RipperMoonToolKit
./install.zsh --skip-deps --backup-only
./install.zsh --skip-deps
./install.zsh --list-backups
```

If the new version behaves badly:

```zsh
cd RipperMoonToolKit
./install.zsh --rollback rippermoon-update-YYYYmmdd-HHMMSS
```

The rollback command preserves the current file as `*.pre-rollback-YYYYmmdd-HHMMSS` before restoring the backed-up version.
