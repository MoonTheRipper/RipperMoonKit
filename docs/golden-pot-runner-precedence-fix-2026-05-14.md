# Golden Pot Runner Precedence Fix

Date: 2026-05-14

## Summary

The Golden Pot freeze returned after reinstall/update even though the Elden Ring ERSC profile still showed the patched runner:

```text
$HOME/GPTK/runners/gptk-dsound-nocap-20260513
```

The latest Steam logs and live Wine processes showed that Steam was actually running from:

```text
/Applications/Game Porting Toolkit.app/Contents/Resources/wine
```

That meant the profile-specific runner setting was not reaching Wine.

## Symptoms

The game launched, audio continued, and opening the world to wanderers through the Golden Pot froze the rendered frame again.

Relevant process and log evidence:

```text
/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wineserver
/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64-preloader
```

```text
DirectSoundCaptureDevice.lock wait timed out
CSteamEngine::BMainLoop appears to have stalled > 15 seconds without event signalled
```

## Root Cause

The GUI correctly passed a per-profile runner through:

```zsh
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513"
```

But `gptk-launch` and `gptk-steam` both source `gptk-common.zsh`, and that helper sourced `~/.rippermoon-gptk.env` during startup. The config file then exported the default stock GPTK path and overwrote the explicit per-command `GPTK_WINE_HOME`.

The broken order was:

```text
GUI profile runner -> gptk-steam/gptk-launch -> source config -> stock GPTK wins
```

## Fix

`gptk-common.zsh` now snapshots supported environment overrides before loading `~/.rippermoon-gptk.env`, then restores those explicit values after the config is sourced.

The corrected order is:

```text
GUI profile runner -> source config -> restore explicit runner -> patched GPTK wins
```

The SwiftUI launcher also repairs the default Elden Ring ERSC profile on load and before launch:

- `requiresSteam = true`
- `prefix = Steam` when empty
- `winver = win10` when empty
- `noDXR = true`
- `noEsync = false`
- `nativeWinmm = true`
- `nativeSteamAPI = true`
- `runnerPath = $HOME/GPTK/runners/gptk-dsound-nocap-20260513` when the profile is empty, missing, or pointing at stock GPTK

The GUI update action now reloads profiles after update/install so this repair runs after GitHub updates.

## Verification

Check that explicit runner overrides survive config loading:

```zsh
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  zsh -c 'source "$HOME/GPTK/libexec/gptk-common.zsh"; print -r -- "$GPTK_WINE_HOME"'
```

Expected output:

```text
/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513
```

Before testing Golden Pot again, stop stale Wine processes from the old runner:

```zsh
gptk-steam --kill
```

If old stock-GPTK `wine64-preloader` processes remain after a freeze, terminate those stale processes before relaunching.

## Regression Guard

The fix is in the shared helper installed to:

```text
$HOME/GPTK/libexec/gptk-common.zsh
```

and in the SwiftUI launcher source. Updates from GitHub install both pieces. A future update should not revert to stock GPTK for the default ERSC profile unless the user intentionally removes the patched runner or points the profile at another valid custom runner.
