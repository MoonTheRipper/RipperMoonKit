# Command Reference

## install.zsh

Install the toolkit and bootstrap dependencies:

```zsh
./install.zsh
```

Install Windows Steam during bootstrap:

```zsh
./install.zsh --install-steam
```

Start Windows Steam installation in the background during app-style setup:

```zsh
./install.zsh --install-steam-background
```

Use a specific mounted GPTK source:

```zsh
./install.zsh --gptk-source "/Volumes/Game Porting Toolkit"
```

Reinstall GPTK from mounted media:

```zsh
./install.zsh --reinstall-gptk
```

Copy scripts only:

```zsh
./install.zsh --skip-deps
```

Create a rollback backup without installing:

```zsh
./install.zsh --skip-deps --backup-only
```

List rollback backups:

```zsh
./install.zsh --list-backups
```

Rollback toolkit scripts/config:

```zsh
./install.zsh --rollback rippermoon-update-YYYYmmdd-HHMMSS
```

Install without a rollback backup:

```zsh
./install.zsh --no-backup
```

Skip GPTK copy:

```zsh
./install.zsh --skip-gptk
```

Skip SteamSetup download:

```zsh
./install.zsh --skip-steam-download
```

Do not edit `~/.zshrc`:

```zsh
./install.zsh --no-zshrc
```

## gptk-launch

General form:

```zsh
gptk-launch --prefix PrefixName -- /path/to/program.exe
```

Initialize a prefix:

```zsh
gptk-launch --prefix MyGame --init
```

Set Windows version:

```zsh
gptk-launch --prefix MyGame --set-winver win10
```

Open Wine config:

```zsh
gptk-launch --prefix MyGame --winecfg
```

Run a Wine tool:

```zsh
gptk-launch --prefix MyGame -- regedit
gptk-launch --prefix MyGame -- cmd
```

Run with a fixed log:

```zsh
gptk-launch --prefix MyGame --log-file "$GPTK_HOME/logs/MyGame.log" -- ./MyGame.exe
```

Useful toggles:

```zsh
gptk-launch --prefix MyGame --hud -- ./MyGame.exe
gptk-launch --prefix MyGame --no-dxr -- ./MyGame.exe
gptk-launch --prefix MyGame --dxvk -- ./MyGame.exe
gptk-launch --prefix MyGame --no-esync -- ./MyGame.exe
```

## gptk-steam

Install Steam:

```zsh
gptk-steam --install-only --install "$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe"
```

Use `--install-only` during setup so Steam is validated and then closed instead of launched.

Start Steam:

```zsh
gptk-steam --log
```

Stop Steam:

```zsh
gptk-steam --kill
```

Repair Steam compatibility settings:

```zsh
gptk-steam --repair-compat
```

Launch Spacewar/AppID 480:

```zsh
gptk-steam --log --install-spacewar
```

Raw Steam argument equivalent:

```zsh
gptk-steam --log -applaunch 480
```

## gptk-vcrun

Download and install the latest Microsoft Visual C++ v14 runtime into one prefix:

```zsh
gptk-vcrun --prefix Dispatch
```

Install into every existing Wine prefix under `GPTK_PREFIX_ROOT`:

```zsh
gptk-vcrun --all
```

Archived prefixes ending in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped.

Download without installing:

```zsh
gptk-vcrun --download-only
```

## gptk-dotnet6

Download and install Microsoft .NET 6 Desktop Runtime into one prefix:

```zsh
gptk-dotnet6 --prefix Steam
```

Install into every existing Wine prefix under `GPTK_PREFIX_ROOT`:

```zsh
gptk-dotnet6 --all
```

Archived prefixes ending in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped.

Download without installing:

```zsh
gptk-dotnet6 --download-only
```

This is mainly for tools such as `EldenRingRandomizer.exe`, not for the base game.

## Elden Ring ERSC With Golden Pot Fix

Apply the DirectSound no-capture fix to the Steam prefix once (the SwiftUI
launcher does this automatically; see `gptk-dsound-nocap` below):

```zsh
gptk-dsound-nocap apply --prefix Steam
```

Then start Steam and launch ERSC from the copied game folder — no special runner:

```zsh
gptk-steam --no-log
cd "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --no-esync --log-file "$GPTK_HOME/logs/ERSC.log" -- ./ersc_launcher.exe
```

See [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md)
for the diagnosis and what the fix does.

## gptk-stubs

Build and install API stub DLLs for missing Wine/GPTK system libraries.

Install GameInput.dll stub into one prefix:

```zsh
gptk-stubs --prefix GOWR
```

Install into every existing Wine prefix under `GPTK_PREFIX_ROOT`:

```zsh
gptk-stubs --all
```

Archived prefixes ending in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped.

Build and cache the stub without installing:

```zsh
gptk-stubs --build-only
```

Force a rebuild even if already cached:

```zsh
gptk-stubs --force-build --prefix GOWR
```

Requires `x86_64-w64-mingw32-gcc` — install with `brew install mingw-w64`.

See [stubs.md](stubs.md) for background on delay-load crashes and the full GoWR launch command.

## gptk-dsound-nocap

Disable Wine DirectSound microphone capture in a prefix so Steam Voice cannot
stall the Elden Ring ERSC Golden Pot lobby. Playback is unaffected; only
microphone capture is disabled (use Discord/FaceTime for voice chat).

Apply to the Steam prefix:

```zsh
gptk-dsound-nocap apply --prefix Steam
```

Apply to every initialized prefix, or check / undo:

```zsh
gptk-dsound-nocap apply --all
gptk-dsound-nocap status --prefix Steam
gptk-dsound-nocap revert --prefix Steam
```

`apply` installs a small forwarder `dsound.dll` into the prefix's `system32`
(x64) and `syswow64` (x86), preserves the prefix's own dsound as
`dsound_real.dll`, and sets the Wine `dsound=native` override. The forwarder
returns `DSERR_NODRIVER` from the capture-create entry points (flat API and the
COM class factory) and forwards everything else to the real dsound.

Nothing copyrighted is redistributed: the forwarder is this project's own code
(`stubs/dsound-nocap/`), and `dsound_real.dll` is the prefix's own dsound, renamed
in place. Maintainers can rebuild the prebuilt proxies (needs `brew install mingw-w64`):

```zsh
gptk-dsound-nocap build
```

See [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md) for the full diagnosis.

## gptk-game

Create a per-game launcher:

```zsh
gptk-game create "Game Name" "$GPTK_EXTERNAL_ROOT/Games/Game/Game.exe" --init
```

Create a launcher using an existing prefix:

```zsh
gptk-game create "Game Name" "$GPTK_EXTERNAL_ROOT/Games/Game/Game.exe" --prefix Steam --workdir "$GPTK_EXTERNAL_ROOT/Games/Game"
```

Run a generated launcher:

```zsh
gptk-game run "Game Name"
```

List generated launchers:

```zsh
gptk-game list
```

## SwiftUI Launcher

Build:

```zsh
swift build
```

Run:

```zsh
swift run RipperMoonKitLauncher
```

Install local `.app` bundle:

```zsh
zsh scripts/install-gui-app.zsh
```

Uninstall toolkit scripts and local app while keeping configs/saves:

```zsh
zsh scripts/uninstall.zsh
```
