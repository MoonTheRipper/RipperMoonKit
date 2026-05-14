# Uninstall

The uninstall script is conservative by default. It removes the toolkit commands and local app bundle, but keeps user configuration, Wine prefixes, game saves, installed games, Steam data, GPTK runtimes, patched runners, logs, and backups.

## Default Uninstall

```zsh
zsh scripts/uninstall.zsh
```

Default behavior:

```text
remove ~/bin/gptk-launch
remove ~/bin/gptk-steam
remove ~/bin/gptk-game
remove $GPTK_HOME/libexec/gptk-common.zsh
remove ~/Applications/RipperMoonKit Launcher.app
keep ~/.rippermoon-gptk.env
keep $GPTK_PREFIX_ROOT
```

Before removing files, the script creates:

```text
$GPTK_HOME/backups/uninstall-YYYYmmdd-HHMMSS
```

## Remove Config

```zsh
zsh scripts/uninstall.zsh --remove-config
```

This removes:

```text
~/.rippermoon-gptk.env
```

## Remove Wine Prefixes And Saves

```zsh
zsh scripts/uninstall.zsh --remove-prefixes
```

This removes:

```text
$GPTK_PREFIX_ROOT
```

Wine prefixes can contain game saves and application data. Only use this option when you have copied out anything you want to keep.

## GUI Uninstall

The SwiftUI launcher exposes the same uninstall flow in Settings. The checkboxes decide whether configuration and Wine prefixes/saves are kept or removed.
