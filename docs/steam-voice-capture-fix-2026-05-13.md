# Steam Voice Capture Fix: Golden Pot Freeze

Date: 2026-05-13

## Summary

Opening the Elden Ring Seamless Coop Golden Pot lobby could freeze the rendered frame while audio continued. The freeze happened when ERSC opened the world to wanderers and Steam Voice started recording through AppID 480.

The tested workaround is a GPTK runner that disables Wine DirectSound microphone capture. Game playback audio still works. Steam, Spacewar/AppID 480, ERSC, and the Golden Pot lobby continue running.

## Tested Setup

- Apple Game Porting Toolkit 3 on Apple Silicon macOS.
- Windows Steam in the `Steam` Wine prefix.
- ERSC launched from the same `Steam` prefix.
- Elden Ring game folder copied from an already-installed Windows machine.
- Offline/non-Steam Elden Ring install, also called a repack.
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

Use a runner where DirectSound capture creation returns `DSERR_NODRIVER`.

The tested persistent runner path is:

```text
$HOME/GPTK/runners/gptk-dsound-nocap-20260513
```

Implementation notes:

- `x86_64-windows/dsound.dll`: source-built patch returning `DSERR_NODRIVER` from `DSOUND_CaptureCreate` and `DSOUND_CaptureCreate8`.
- `i386-windows/dsound.dll`: binary patch returning `DSERR_NODRIVER` from `DirectSoundCaptureCreate` and `DirectSoundCaptureCreate8`.
- No Steam files, game files, saves, or Wine prefixes are stored in this repository.

Expected tradeoff:

- Steam/Game microphone capture is disabled under this runner.
- Playback audio remains enabled.
- Use Discord, FaceTime, or another native macOS voice channel if voice chat is needed.

## Commands

Start Steam:

```zsh
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  gptk-steam --no-log
```

Launch ERSC:

```zsh
cd "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --log-file "$GPTK_HOME/logs/ERSC-dsound-nocap.log" -- ./ersc_launcher.exe
```

Stop Steam and the game:

```zsh
gptk-steam --kill
```

## Placeholder Commands

Replace `USERNAME` with the macOS account name and `EXE PATH` with the folder containing `ersc_launcher.exe`.

```zsh
env GPTK_WINE_HOME="/Users/USERNAME/GPTK/runners/gptk-dsound-nocap-20260513" \
  /Users/USERNAME/bin/gptk-steam --no-log
```

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

```zsh
/Users/USERNAME/bin/gptk-steam --kill
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

