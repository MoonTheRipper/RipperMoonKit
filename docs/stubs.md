# API Stubs

Some Windows games delay-load system DLLs that Wine/GPTK does not provide. Instead of crashing with a module-not-found exception at startup, the game can be given a minimal stub DLL that exports the expected symbols and returns a safe error code, allowing the game to fall back gracefully.

`gptk-stubs` automates building and installing these stubs.

## Why This Is Needed

Windows PE executables can list DLLs in two ways:

- **Static imports** (Data Directory entry 1): loaded at process start; a missing DLL is a hard failure.
- **Delay-load imports** (Data Directory entry 13): loaded on first call; a missing DLL raises exception `0xc06d007e` (module not found) at that call site.

Wine silently ignores delay-load entries it cannot satisfy until the game actually calls into them. At that point, if the DLL is absent, the exception propagates up and crashes the process — often before any window appears, making it look like the game refuses to start.

The fix is a stub DLL that:
1. Exports the expected function at the expected ordinal.
2. Returns `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)` (0x80070032) so the caller detects the feature is unavailable and skips it rather than crashing.

## Known Stubs

### GameInput.dll

**Affected games:** God of War: Ragnarök, and any title using Microsoft's GameInput API.

**Crash symptom:** process exits immediately with exception `0xc06d007e`; no window appears; Wine log shows `DelayLoadFailureHook` or nothing at all before the crash.

**Exported symbol:** `GameInputCreate` at ordinal 1.

**Source:** [`stubs/gameinput.c`](../stubs/gameinput.c), [`stubs/gameinput.def`](../stubs/gameinput.def)

## Using gptk-stubs

### Prerequisites

Install the mingw-w64 cross-compiler:

```zsh
brew install mingw-w64
```

### Install into one prefix

```zsh
gptk-stubs --prefix GOWR
```

### Install into every existing prefix

```zsh
gptk-stubs --all
```

Archived prefixes ending in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped.

### Build and cache without installing

```zsh
gptk-stubs --build-only
```

The compiled `GameInput.dll` is cached at `$GPTK_HOME/stubs/GameInput.dll` and reused on subsequent runs.

### Force a rebuild

```zsh
gptk-stubs --force-build --prefix GOWR
```

### Override the cache directory

```zsh
RIPPERMOON_STUBS_DIR=/path/to/cache gptk-stubs --prefix GOWR
```

## Manual Installation

If you prefer to install the stub without the script:

```zsh
# Build
x86_64-w64-mingw32-gcc -nostdlib -shared \
  -o GameInput.dll \
  stubs/gameinput.c stubs/gameinput.def \
  -lkernel32

# Install
cp GameInput.dll ~/WinePrefixes/GOWR/drive_c/windows/system32/GameInput.dll
```

Then add `WINEDLLOVERRIDES='GameInput=n'` to the launch command so Wine uses the native (your stub) version rather than looking for a builtin.

## Launch Command

After installing the stub, include `WINEDLLOVERRIDES='GameInput=n'` in the launch environment:

```zsh
cd "/Users/odunga/Desktop/GAMES/God of War - Ragnarok"
env GPTK_WINE_HOME="$GPTK_HOME/runners/gptk-dsound-nocap-20260513" \
    WINEDLLOVERRIDES='GameInput=n' \
  gptk-launch --prefix GOWR --set-winver win10 \
    --no-dxr --avx --metalfx \
    --log-file "$GPTK_HOME/logs/gowr-launch.log" \
    -- ./GoWR.exe \
      -dxSkipDriverVersionCheck -disableNvStreamline \
      -disablePSPCSteam -novalidation
```

See [`examples/gowr-launch.zsh.example`](../examples/gowr-launch.zsh.example) for the full self-contained example.

## Adding a New Stub

1. Create `stubs/NEWDLL.c` with the stub implementation.
2. Create `stubs/NEWDLL.def` listing the exports.
3. Update `bin/gptk-stubs` to build and install it (follow the `gameinput` pattern).
4. Document it in this file under **Known Stubs**.
