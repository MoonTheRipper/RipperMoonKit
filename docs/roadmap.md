# Roadmap

This repository keeps transparent shell scripts as the source of truth and now includes an initial native SwiftUI launcher so non-technical users do not need to remember command lines.

## SwiftUI Launcher Plan

Planned app name:

```text
RipperMoonKit Launcher
```

Shipped goals:

- Detect `~/.rippermoon-gptk.env` and show editable paths and drive mappings.
- Let users create individual app/game profiles.
- Let each profile own its game folder, executable, prefix, runner, validation files, launch options, and command previews.
- Validate common layouts, including `ersc_launcher.exe`, `eldenring.exe`, `SeamlessCoop/`, and expected DLL overrides for the default ERSC profile.
- Start Steam when needed, launch ERSC or other configured executables, and stop Steam through buttons.
- Write readable logs to `$GPTK_HOME/logs`.
- Show last-run status and links to the current log files.
- Expose safe toggles for `--no-dxr`, `--hud`, `--set-winver`, and selected compatibility profile.
- Create and apply installer rollback backups.
- Prompt first-run setup when GPTK or the toolkit install is missing.

Next app goals:

- Add launch status checks for long-running Steam/game processes.
- Warn when Steam and the game are about to use different Wine prefixes.
- Add import/export for app profile presets.

## Compatibility Profiles

Game support is now profile-based instead of hard-coded.

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
