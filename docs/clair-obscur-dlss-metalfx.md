# Clair Obscur DLSS Through MetalFX

This note documents the tested launch shape for Clair Obscur: Expedition 33 under GPTK/D3DMetal when the in-game graphics menu is set to DLSS.

## What DLSS Means Here

On Apple silicon, there is no NVIDIA Windows driver to install. The useful path is GPTK's D3DMetal MetalFX bridge:

- the game must run through D3DMetal;
- MetalFX must be enabled in the runner;
- the game must have DLSS selected in its own graphics settings;
- Wine should prefer GPTK's built-in `nvapi64` and `nvngx` DLLs for the bridge.

CodeWeavers documents the same shape for CrossOver: DLSS is powered by MetalFX, only takes effect when DLSS is enabled in-game, and only applies with D3DMetal or DXMT.

Reference:

```text
https://support.codeweavers.com/en_US/crossover-mac-user-guide
```

## Tested Command

Replace `USERNAME` with the macOS account name and replace `EXE PATH` with the folder that contains the copied game install.

```zsh
cd "EXE PATH"
WINEDLLOVERRIDES='nvapi64,nvngx=b,n' \
  /Users/USERNAME/bin/gptk-launch \
    --prefix ClairObscur \
    --set-winver win10 \
    --metalfx \
    --no-dxr \
    --hud \
    --log-file "/Users/USERNAME/GPTK/logs/ClairObscur-metalfx.log" \
    -- ./Sandfall/Binaries/Win64/SandFall-Win64-Shipping.exe \
    Sandfall \
    '-ini:Engine:[SystemSettings]:r.WarnOfBadDrivers=0'
```

`--hud` is optional. Keep it enabled while testing because it confirms that Metal is presenting frames and gives a quick FPS check.

## NVIDIA Driver Popup

The popup that says:

```text
The installed version of the NVIDIA graphics driver has known issues in D3D12.
AMD Compatibility Mode
Installed: 512.33
Recommended: 536.40 or latest driver available
```

is an Unreal Engine Windows driver warning. It is not asking for a real macOS NVIDIA driver. GPTK/D3DMetal exposes a compatibility adapter, and Unreal compares that reported driver version against its D3D12 warning list.

The tested suppression is:

```text
'-ini:Engine:[SystemSettings]:r.WarnOfBadDrivers=0'
```

Passing it as a launch argument is safer than relying on `Saved/Config/Windows/Engine.ini`, because the game can regenerate that folder during launch.

## GUI Profile

For a RipperMoonKit GUI profile:

```text
prefix: ClairObscur
game folder: EXE PATH
executable: Sandfall/Binaries/Win64/SandFall-Win64-Shipping.exe
Windows version: win10
No DXR: enabled
MetalFX/DLSS: enabled
HUD: optional
extra arguments: Sandfall '-ini:Engine:[SystemSettings]:r.WarnOfBadDrivers=0'
```

The MetalFX/DLSS toggle adds `--metalfx` and applies:

```text
WINEDLLOVERRIDES='nvapi64=b,n;nvngx=b,n'
```

## Known Remaining Issue

The current GPTK media path still reports GStreamer and Media Foundation color-conversion warnings during videos. If the Wine C++ Runtime color conversion popup appears, the cutscene can usually continue after ignoring it, but the underlying media conversion issue is separate from the DLSS/MetalFX path.
