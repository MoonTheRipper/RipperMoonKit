# God of War: Ragnarök

This page covers the Wine prefix setup, GameInput stub install, and working launch command for God of War: Ragnarök (GoWR) running through GPTK on Apple Silicon.

## Prerequisites

- GPTK 3 installed (see [gptk.md](gptk.md))
- A `GOWR` Wine prefix initialised under `$GPTK_PREFIX_ROOT/GOWR` with VC++ runtimes installed
- Game files at `$GPTK_EXTERNAL_ROOT/Games/GoWR` or another path (adjust `GAME_DIR` in the launch command)
- The patched dsound runner at `$GPTK_HOME/runners/gptk-dsound-nocap-20260513` (same runner used for ERSC; prevents audio-capture hangs)
- `mingw-w64` for building the GameInput stub: `brew install mingw-w64`

## GameInput.dll Stub

GoWR delay-loads `GameInput.dll` (Microsoft GameInput API, ordinal 1 = `GameInputCreate`). Wine has no builtin for this DLL. The missing DLL raises exception `0xc06d007e` before any window appears.

Install the stub into the GOWR prefix:

```zsh
gptk-stubs --prefix GOWR
```

This builds a minimal PE DLL from [`stubs/gameinput.c`](../stubs/gameinput.c), caches it at `$GPTK_HOME/stubs/GameInput.dll`, and copies it to:

```
~/WinePrefixes/GOWR/drive_c/windows/system32/GameInput.dll
```

The stub exports `GameInputCreate` at ordinal 1 and returns `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)` (0x80070032). The game detects GameInput is unavailable and continues without it.

See [stubs.md](stubs.md) for the full background on delay-load DLL crashes.

## Initialise the Prefix

If you haven't set up the prefix yet:

```zsh
gptk-launch --prefix GOWR --init
gptk-launch --prefix GOWR --set-winver win10
gptk-vcrun --prefix GOWR
gptk-stubs --prefix GOWR
```

## Launch Command

```zsh
cd "$GPTK_EXTERNAL_ROOT/Games/GoWR"
env GPTK_WINE_HOME="$GPTK_HOME/runners/gptk-dsound-nocap-20260513" \
    WINEDLLOVERRIDES='GameInput=n' \
  gptk-launch --prefix GOWR --set-winver win10 \
    --no-dxr --avx --metalfx \
    --log-file "$GPTK_HOME/logs/gowr-launch.log" \
    -- ./GoWR.exe \
      -dxSkipDriverVersionCheck \
      -disableNvStreamline \
      -disablePSPCSteam \
      -novalidation
```

`WINEDLLOVERRIDES='GameInput=n'` tells Wine to use the native (stub) DLL rather than looking for a builtin.

A self-contained example script is at [`examples/gowr-launch.zsh.example`](../examples/gowr-launch.zsh.example).

## Known Non-Fatal Log Noise

After the fix these entries appear in the log but do not affect gameplay:

- `EndQuery type 2 not supported` — D3DMetal limitation, non-fatal
- `OMSetDepthBounds not supported` — D3DMetal limitation, non-fatal
- `CoUninitialize Mismatched` flood from thread 0230 — Wine noise

## Known Issues

- PS SDK MSI files (`PsPcSdkRuntimeInstaller.msi`, `PsPcSdkRuntimeManager.msi`) are not present in FitGirl repacks. Despite the filenames appearing in strings inside the executable, `PsPcSdk.dll` is **not** in the static or delay-load import table. It is an error message string only and is not needed for launch.
- 2.6 GB of crash dumps may accumulate in `.crashdata/` from pre-fix runs — safe to delete.
- Do not place a third-party `dxgi.dll` in the game root while using GPTK; it hijacks D3DMetal.
