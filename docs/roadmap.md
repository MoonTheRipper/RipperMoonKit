# Roadmap

This repository currently favors transparent shell scripts and documentation. The next major usability step is a native launcher so non-technical users do not need to remember command lines.

## SwiftUI Launcher Plan

Planned app name:

```text
RipperMoonKit Launcher
```

Initial goals:

- Detect `~/.rippermoon-gptk.env` and show the active GPTK, prefix, games, Steam library, and runner paths.
- Let users choose a game folder with a file picker.
- Validate common layouts, including `ersc_launcher.exe`, `eldenring.exe`, `SeamlessCoop/`, and expected DLL overrides.
- Start Steam, launch AppID 480 when needed, launch ERSC, and stop Steam through buttons.
- Write readable logs to `$GPTK_HOME/logs`.
- Show last-run status and links to the current log files.
- Warn when Steam and the game are about to use different Wine prefixes.
- Expose safe toggles for `--no-dxr`, `--hud`, `--set-winver`, and selected compatibility profile.

## Compatibility Profiles

Future game support should be profile-based instead of hard-coded.

Proposed profile fields:

```text
name
prefix
working_directory
executable
required_files
dll_overrides
winver
runner
steam_required
steam_appid
launch_arguments
known_issues
post_launch_checks
```

The Elden Ring ERSC profile would include:

```text
prefix: Steam
executable: ersc_launcher.exe
dll_overrides: winmm=n,b;steam_api64=n,b
winver: win10
runner: gptk-dsound-nocap-20260513
steam_required: true
steam_appid: 480
```

## Safety Rules

- Keep game files, saves, Wine prefixes, Steam data, and Apple GPTK runtime blobs out of git.
- Store only scripts, docs, templates, and profile definitions in the repository.
- Treat patched runners as local artifacts under `$GPTK_HOME/runners`.
- Require explicit user action before deleting prefixes, saves, or installed games.

