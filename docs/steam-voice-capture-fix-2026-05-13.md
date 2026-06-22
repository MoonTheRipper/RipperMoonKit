# Steam Voice Capture Fix: Golden Pot Freeze

Date: 2026-05-13

## Summary

Opening the Elden Ring Seamless Coop Golden Pot lobby could freeze the rendered frame while audio continued. The freeze happened when ERSC opened the world to wanderers and Steam Voice started recording through AppID 480.

The tested workaround is a GPTK runner that disables Wine DirectSound microphone capture. Game playback audio still works. Steam, Spacewar/AppID 480, ERSC, and the Golden Pot lobby continue running.

## Tested Setup

- Apple Game Porting Toolkit 3 on Apple Silicon macOS.
- Windows Steam in the `Steam` Wine prefix.
- ERSC launched from the same `Steam` prefix.
- Elden Ring game folder copied from an installed Windows machine.
- Seamless Coop using AppID 480/Spacewar through Steam.

## Symptoms

The game reached the save and world state correctly. When choosing to open the world to wanderers through the Golden Pot, the screen froze on the selected frame. Audio could continue, and Steam logs continued writing for a short time.

Relevant log signatures:

```text
StartVoiceRecording() (was recording: 0)
Created OPUS PLC voice encoder
DirectSoundCaptureDevice.lock wait timed out
CSteamEngine::BMainLoop appears to have stalled > 15 seconds
fatal stalled cross-thread pipe
```

The repeated Steam network assertion below was noisy, but it was not the final freeze trigger:

```text
src\common\net.cpp (1715) : Assertion Failed: getsockname failed in BGetBoundAddr with error: 10022
```

## Root Cause

Steam Voice starts when ERSC opens the lobby. On the tested GPTK/Wine build, Steam's DirectSound microphone capture code can stall inside Wine's DirectSound capture path. The stalled capture lock then blocks Steam's main loop, which leaves the game visually frozen.

The Steam binary contains the relevant voice path strings:

```text
voice_record_dsound.cpp
StartVoiceRecording()
StopVoiceRecording()
Created OPUS PLC voice encoder
```

## Fix

Disable Wine DirectSound microphone capture so capture device creation fails
cleanly with `DSERR_NODRIVER` — on both the flat API and the COM class-factory
path. Playback is untouched; only microphone capture is disabled.

This ships as a reproducible helper, `gptk-dsound-nocap`, rather than a hand-built
Wine runner (the original 2026-05-13 runner was never committed and was lost on a
`GPTK_HOME` rebuild):

```zsh
gptk-dsound-nocap apply --prefix Steam
```

What `apply` does to the prefix, idempotently:

- Installs a small forwarder `dsound.dll` into `drive_c/windows/system32` (x64)
  and `drive_c/windows/syswow64` (x86), preserving the prefix's existing dsound
  as `dsound_real.dll`.
- Sets the Wine override `dsound=native` so the forwarder is the DLL Wine loads.
  Apple's GPTK materializes its builtin dsound into the prefix's `system32`,
  which otherwise shadows any runner-level (`lib/wine`) replacement — this was
  why earlier runner-only attempts had no effect.

The forwarder sends every export to `dsound_real.dll` except the capture entry
points — `DirectSoundCaptureCreate`, `DirectSoundCaptureCreate8`, and the COM
`DllGetClassObject` factory for `CLSID_DirectSoundCapture` / `CLSID_DirectSoundCapture8`
— which return `DSERR_NODRIVER`. Steam creates its capture device through the COM
factory, so blocking only the flat API is not enough.

Status and revert:

```zsh
gptk-dsound-nocap status --prefix Steam
gptk-dsound-nocap revert --prefix Steam
```

The SwiftUI launcher applies this automatically before launching Elden Ring ERSC
(and before starting its Steam), and exposes Apply / Revert on the profile's
Launch tab. The patch persists in the prefix; if the prefix is recreated, the
next launch reapplies it.

### What is redistributed

Nothing copyrighted. The forwarder is this project's own code — source in
`stubs/dsound-nocap/`, prebuilt binaries in `stubs/dsound-nocap/prebuilt/` — and
it forwards to the prefix's *own* dsound, which is renamed in place and never
copied off the machine. Maintainers can rebuild the prebuilt proxies (needs
`brew install mingw-w64`):

```zsh
gptk-dsound-nocap build
```

Expected tradeoff:

- Steam/Game microphone capture is disabled in this prefix.
- Playback audio remains enabled.
- Use Discord, FaceTime, or another native macOS voice channel if voice chat is needed.

## Commands

The launcher applies the fix for you; these are the manual equivalents. Apply
once, then start Steam and launch ERSC normally (no special runner needed):

```zsh
gptk-dsound-nocap apply --prefix Steam
gptk-steam --no-log
cd "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --no-esync --log-file "$GPTK_HOME/logs/ERSC.log" -- ./ersc_launcher.exe
```

Stop Steam and the game:

```zsh
gptk-steam --kill
```

## Verification

A successful run should show:

- Steam logs `StartVoiceRecording()` without the old DirectSound lock timeout.
- ERSC stays in-game after opening the Golden Pot.
- Separating from the mist does not freeze the game.

Expected remaining noise:

```text
src\common\net.cpp (1715) : Assertion Failed: getsockname failed in BGetBoundAddr with error: 10022
```

That assertion may still appear in Steam logs. The validated fix targets the Steam Voice DirectSound capture stall.

