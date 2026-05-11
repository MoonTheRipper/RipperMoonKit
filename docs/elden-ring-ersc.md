# Elden Ring Seamless Coop / ERSC

This page documents the working launch shape for ERSC when it needs Steam running and Spacewar/AppID 480 available.

## Tested Content Layout

This ERSC workflow was tested with a pre-installed offline/non-Steam Windows game folder copied into the target `Games` directory.

Use the installed game folder from a Windows PC:

```text
$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game/
    eldenring.exe
    ersc_launcher.exe
    SeamlessCoop/
```

Do not use the original installation files as the runtime source for this flow. In this GPTK build, the installer path is fragile; the reliable path was copying the already-installed `Game` folder and launching from there.

This repository does not include game files, saves, Steam data, Wine prefixes, or runtime blobs.

## Path Variables

Set these for your machine:

```zsh
export ER_GAME_DIR="$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
export ER_LOG="$GPTK_HOME/logs/ERSC-steam-prefix.log"
```

## Launch Sequence

Start Steam first:

```zsh
gptk-steam --log
```

In another terminal, make sure AppID 480 is launched or initialized when your ERSC setup depends on it:

```zsh
gptk-steam --log -applaunch 480
```

Then launch ERSC from the game folder using the same `Steam` prefix:

```zsh
cd "$ER_GAME_DIR"
WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --log-file "$ER_LOG" -- ./ersc_launcher.exe
```

## Why Same Prefix Matters

Steam API calls depend on the running Steam client's IPC state. If Steam is running in one prefix and ERSC launches from another prefix, the game may not see the same named pipes and process environment.

The working model is:

```text
Steam prefix:
  steam.exe
  steamwebhelper.exe
  ersc_launcher.exe
  eldenring.exe
```

## Esync Rule

If Steam's Wine server is already running with esync enabled, do not launch ERSC with `--no-esync`.

An esync mismatch looks like:

```text
Server is running with WINEESYNC but this process is not
```

Leave esync enabled for ERSC in that case.

## Useful Checks

Process check:

```zsh
pgrep -af 'steam.exe|steamwebhelper|ersc_launcher|eldenring.exe|wineserver'
```

Latest logs:

```zsh
ls -lt "$GPTK_HOME/logs" | head
tail -n 120 "$ER_LOG"
```

Crash dumps:

```zsh
ls -lt "$ER_GAME_DIR/SeamlessCoop/crashdumps/reports" | head
```

Layout check:

```zsh
examples/check-ersc-layout.zsh.example
```
