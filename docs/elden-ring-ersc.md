# Elden Ring Seamless Coop / ERSC

This page documents the working launch shape for ERSC when it needs Steam running and Spacewar/AppID 480 available.

![Elden Ring running on macOS through Apple Game Porting Toolkit with the HUD visible](assets/elden-ring-grace-hud.png)

This is a proof-of-concept capture from the RipperMoonKit Elden Ring profile. It shows the game running through Apple Game Porting Toolkit 3 with the HUD visible.

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

## Example Launcher Profile

![RipperMoonKit launcher showing the Elden Ring ERSC profile](assets/rippermoonkit-gui.png)

The GUI profile keeps the Elden Ring folder, Steam prefix, runner, and launch options in one place so the setup is easier to repeat.

## Gameplay Capture

![Elden Ring boss fight running on macOS through Apple Game Porting Toolkit with the HUD visible](assets/elden-ring-godrick-hud.png)

This second capture is included to show the setup during active gameplay. It is not a promise of exact performance on every Mac.

## Path Variables

Set these for your machine:

```zsh
export ER_GAME_DIR="$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
export ER_LOG="$GPTK_HOME/logs/ERSC-steam-prefix.log"
```

If you use the Golden Pot lobby fix, point `GPTK_WINE_HOME` at the patched GPTK runner:

```zsh
export GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513"
```

That runner is a stock GPTK runner with only Wine DirectSound capture disabled. It prevents Steam Voice from locking the process when ERSC opens the world to wanderers. See [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md).

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

## ModEngine And Randomizer Launch

For the Item and Enemy Randomizer workflow, the final launcher is not `ersc_launcher.exe`. The final launcher is ModEngine 2:

```text
Game/ModEngine2/launchmod_eldenring.bat
```

The randomizer GUI imports a `.randomizeopt` file and generates randomized files under:

```text
Game/ModEngine2/randomizer/
```

ModEngine then launches `eldenring.exe`, loads Seamless Coop as an external DLL, and mounts the randomizer folder:

```toml
external_dlls = [
    "../SeamlessCoop/ersc.dll"
]

mods = [
    { enabled = true, name = "default", path = "mod" },
    { enabled = true, name = "randomizer", path = "randomizer" }
]
```

RipperMoonKit's Mod Manager panel can write the current-machine `config_eldenring.toml` and `launchmod_eldenring.bat`. It intentionally does not copy Windows drive letters from another PC. A copied Windows example such as `G:\Games\ELDEN RING\Game\eldenring.exe` becomes the current GPTK/Wine path, usually through Wine's default `Z:\...` mapping.

The panel can also run **Install ModEngine + Randomizer**. That action installs .NET 6 Desktop Runtime into the Elden Ring randomizer tools prefix, clones or updates the `elden-randomizer-coop` setup reference repo under `$GPTK_HOME/tools`, opens the download pages, scans its `inputs/` folder, installs recognized ZIPs, and writes the local ModEngine config/launch files.

The panel also includes **Backup Mod State** and **Import From Friend**. Backup captures `ModEngine2`, `SeamlessCoop`, and the root helper executables into a rollback ZIP. Import From Friend accepts an exported co-op/randomizer packet, stages its bundled ZIP files, copies the shared `.randomizeopt`, and applies the shared Seamless password without printing it.

RipperMoonKit does this natively instead of running `setup.bat`, because the Windows setup path calls `powershell.exe`. A normal GPTK prefix does not include Windows PowerShell, and native macOS PowerShell is not required for this workflow.

The critical runtime is not PowerShell. It is Windows .NET 6 Desktop Runtime, because `EldenRingRandomizer.exe` is a .NET desktop application. RipperMoonKit installs that with:

```zsh
gptk-dotnet6 --prefix EldenRingToolsStaging
```

The randomizer GUI is not launched through the live Steam/game prefix. If Wine Staging 11.8 is installed, RipperMoonKit uses it for the randomizer tools prefix to avoid the GPTK/Wine 7.7 WinForms UIAutomation crash. The actual Elden Ring and ERSC launches continue to use the configured GPTK game runner.

The ZIP installer recognizes ZIPs by their contents:

```text
modengine2_launcher.exe      ModEngine 2
EldenRingRandomizer.exe      Item and Enemy Randomizer
ersc_launcher.exe            Seamless Coop
toggle_anti_cheat.exe        Anti Cheat Toggler
```

Existing Seamless settings are preserved, and an existing randomizer folder is moved to a timestamped backup before replacement.

Manual launch shape:

```zsh
cd "$ER_GAME_DIR/ModEngine2"
WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr \
    --log-file "$GPTK_HOME/logs/elden-ring-modengine.log" \
    -- ./modengine2_launcher.exe \
       -t er \
       -c ./config_eldenring.toml \
       --game-path "Z:\\path\\to\\Game\\eldenring.exe"
```

Use the ERSC-only launcher first if you still need to create the Seamless save. Use the ModEngine launcher after the randomizer has generated its files.

Confirmed behavior: when the same game folder is launched without ModEngine, the randomized changes are not active. That is expected. Randomizer output is mounted through ModEngine, so the modded and non-modded launch paths stay separate.

## Tool Credits

RipperMoonKit coordinates local launches and setup files, but the Elden Ring mod workflow depends on community tools downloaded by the user:

- [ModEngine 2](https://github.com/soulsmods/ModEngine2) provides `modengine2_launcher.exe` and the TOML-driven mod loading path.
- [Elden Ring Seamless Co-op / ERSC](https://www.nexusmods.com/eldenring/mods/510) provides `ersc_launcher.exe`, `ersc.dll`, and the co-op save/online flow.
- [MoonTheRipper/elden-randomizer-coop](https://github.com/MoonTheRipper/elden-randomizer-coop) provided the Windows setup reference used to design the native macOS helper.
- Elden Ring Item and Enemy Randomizer provides the randomizer GUI and generated randomizer files.

## Full Placeholder Commands

These commands use literal placeholders for GitHub readers. Replace `USERNAME` with your macOS user name and replace `EXE PATH` with the folder that contains `ersc_launcher.exe` and `eldenring.exe`.

Start Windows Steam with the tested DirectSound no-capture runner:

```zsh
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  /Users/USERNAME/bin/gptk-steam --no-log
```

Launch ERSC from the copied game folder:

```zsh
cd "EXE PATH"
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  /Users/USERNAME/bin/gptk-launch \
    --prefix Steam \
    --set-winver win10 \
    --no-dxr \
    --log-file "/Users/USERNAME/GPTK/logs/ERSC-dsound-nocap.log" \
    -- ./ersc_launcher.exe
```

Stop Steam and the Steam-prefix game processes:

```zsh
/Users/USERNAME/bin/gptk-steam --kill
```

Optional Spacewar/AppID 480 launch when a setup needs it initialized explicitly:

```zsh
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  /Users/USERNAME/bin/gptk-steam --no-log -applaunch 480
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

The current ERSC profile starts both Steam and ERSC with esync disabled. This avoids the repeated `pipe: Too many open files` / `eventfd: Too many open files` failure seen when Steam, Spacewar/AppID 480, and ERSC keep opening sockets through Wine esync.

This was confirmed on 2026-05-16: after disabling esync for the ERSC profile, the Golden Pot lobby stopped hanging.

If Steam's Wine server is already running with esync enabled, stop Steam before launching the ERSC profile again:

```zsh
gptk-steam --kill
```

Then launch Steam and ERSC through the same RipperMoonKit profile so both processes use the same esync setting.

An esync mismatch looks like:

```text
Server is running with WINEESYNC but this process is not
```

Do not mix esync settings between Steam and ERSC inside the same Wine prefix.

## Steam Runner Rule

Steam must also be started with the same Wine runner expected by the Elden Ring profile. For the Golden Pot and ModEngine path, that is the DirectSound no-capture runner plus no-esync. If Steam was started from the standalone Steam tile or from a manual terminal command using the stock GPTK runner, the game can freeze when joining or opening a world.

The matching failure usually repeats these lines in the logs:

```text
getsockname failed in BGetBoundAddr with error: 10022
CSteamEngine::BMainLoop appears to have stalled
DirectSoundCaptureDevice.lock wait timed out
```

RipperMoonKit records how it started Steam for a game profile and blocks Steam-dependent launches when an already-running Steam process does not match the profile runner/no-esync state. Close Steam, press the Elden Ring profile's **Start Steam** button, then use **Launch Modded**.

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

No-capture launch example:

```zsh
examples/ersc-launch-dsound-nocap.zsh.example
```
