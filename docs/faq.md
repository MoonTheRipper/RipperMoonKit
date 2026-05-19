# FAQ

## Does This Repository Include GPTK?

No. Each user downloads **Game Porting Toolkit 3** directly from Apple Developer and mounts the DMG for the official evaluation runtime. If `Game Porting Toolkit.app` is not already installed, the installer can fetch the prebuilt Homebrew/Gcenx app runner and then copies the app/runtime into the user's local toolkit folder.

## Does This Repository Include Games Or Saves?

No. It includes scripts, examples, and documentation only.

Excluded local state includes:

- installed games;
- Steam libraries;
- Wine prefixes;
- GPTK runtime files;
- logs;
- saves and backups.

## Why Are Prefixes Kept On Internal Storage?

Wine prefixes contain registry state, symlinks, small runtime files, and compatibility configuration. Keeping them on internal storage is usually more reliable than putting them on removable or exFAT game storage.

Large game folders can live on external storage.

## Why Does The Toolkit Copy Installed Game Folders?

Some Windows installers behave poorly under GPTK/Wine. A game can still work if it is already installed and patched on a Windows PC, then copied as a complete runtime folder.

When documentation says to use a copied game folder, copy the installed folder, not the installer files.

## Why Can I Not Map C:?

Wine owns `C:` inside each prefix:

```text
$GPTK_PREFIX_ROOT/<PrefixName>/drive_c
```

The toolkit refuses `C:` mappings so a user cannot accidentally replace the prefix's Windows drive.

## Why Does ERSC Need The Steam Prefix?

Steam API access depends on Steam client IPC. If Steam is running in one prefix and a launcher runs in another, the game may not see the same Steam IPC state.

For the documented ERSC workflow, Steam and ERSC run from the same `Steam` prefix.

## Why Does The Installer Download SteamSetup But Not Always Install Steam?

Downloading `SteamSetup.exe` is safe and repeatable. Installing Windows Steam creates/modifies the `Steam` prefix and may open UI. The installer only does that when requested:

```zsh
./install.zsh --install-steam
```

## Where Are Logs?

Installer logs:

```text
$GPTK_HOME/logs/rippermoon-install-YYYYmmdd-HHMMSS.log
```

Launcher logs:

```text
$GPTK_HOME/logs/
```

Fixed log example:

```zsh
gptk-launch --prefix MyGame --log-file "$GPTK_HOME/logs/MyGame.log" -- ./Game.exe
```

## How Do I Reset Steam?

Stop the Steam prefix:

```zsh
gptk-steam --kill
```

Then start it again:

```zsh
gptk-steam --log
```

## How Do I Update GPTK?

Download the newer GPTK from Apple, mount the DMG, then run:

```zsh
./install.zsh --reinstall-gptk
```
