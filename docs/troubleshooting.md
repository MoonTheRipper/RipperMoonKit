# Troubleshooting

## macOS Says The App Is Damaged Or Cannot Be Opened

Download the newest DMG from GitHub releases first. Older packages before `v1.2.3` could contain an app bundle whose internal resources were not sealed correctly, so a fresh macOS user account could reject the app even when the developer account opened it.

If the newest DMG still fails, remove the old copy from Applications, drag the app from the DMG into Applications again, then open **System Settings > Privacy & Security** and allow the app if macOS asks. RipperMoonKit is ad-hoc signed for now, not Apple Developer ID notarized.

## Steam Starts But Webhelper Times Out

Repair Steam compatibility:

```zsh
gptk-steam --repair-compat
```

Optionally reset webhelper cache:

```zsh
gptk-steam --reset-webhelper-cache --log
```

Check logs:

```zsh
tail -n 120 "$GPTK_PREFIX_ROOT/Steam/drive_c/Program Files (x86)/Steam/logs/steamui_html.txt"
tail -n 120 "$GPTK_PREFIX_ROOT/Steam/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
```

## Esync Mismatch

Error:

```text
Server is running with WINEESYNC but this process is not
```

Cause: a process in that prefix is already running with esync enabled, but the new command disabled esync.

Fix: remove `--no-esync`, or stop the prefix:

```zsh
gptk-steam --kill
```

Then relaunch with one consistent esync setting.

## Game Exits Immediately

Check:

```zsh
ls -lt "$GPTK_HOME/logs" | head
tail -n 160 "$GPTK_HOME/logs/latest-log-name.log"
pgrep -af 'game.exe|steam.exe|wineserver'
```

For ERSC, also check:

```zsh
ls -lt "$ER_GAME_DIR/SeamlessCoop/crashdumps/reports" | head
```

## Steam Download Or Web Runtime Fails

If a Steam download ends with `content unavailable`, or Steam tries to install a Web Runtime and fails, confirm the Steam library path is on a mounted writable drive with enough free space. Then repair Steam compatibility files:

```zsh
gptk-steam --repair-compat
```

Restart Steam after repair. If the issue continues, inspect the Steam logs inside the Steam prefix before deleting downloaded data.

## Clair Obscur Shows NVIDIA Driver Prompt

Some Windows games see GPTK's compatibility GPU report and show a NVIDIA driver warning. On Apple Silicon, do not install NVIDIA drivers. Use the profile's GPTK/Metal launch options, then change the game's own graphics settings from inside the game.

## Clair Obscur WineGStreamer Color Assertion

If the popup references `winegstreamer/colorconvert.c`, the tested behavior was that ignoring the popup allowed the cutscene and gameplay to continue. If video playback becomes a hard blocker, capture the newest log and compare it with [tested-games.md#clair-obscur-expedition-33](tested-games.md#clair-obscur-expedition-33).

## God Of War Ragnarok Does Not Start

Run the PlayStation PC runtime installer inside the game's prefix first, then launch again. If it still exits, check the log for missing API/runtime lines such as GameInput, Vulkan fallback attempts, or D3D12 feature queries before changing broad runner settings.

## Game Runs For A Few Minutes Then Closes

Look for file descriptor exhaustion:

```zsh
rg -n "Too many open files|NtCreateFile|eventfd|pipe" "$GPTK_HOME/logs"
```

If the log contains `Too many open files`, restart Steam and the game through the current RipperMoonKit launcher. The launcher raises the inherited open-file limit before Wine starts. You can tune the limit in `~/.rippermoon-gptk.env`:

```zsh
export GPTK_NOFILE_LIMIT="49152"
```

The change only applies to newly launched Wine processes. Already-running Steam sessions must be restarted.

If the same entries continue after the log confirms `gptk: open-file limit 49152`, disable esync for the affected profile and restart the whole Wine prefix. For Elden Ring ERSC, this is now the default because the confirmed 2026-05-16 fix was launching Steam and ERSC together with `WINEESYNC=0`.

Expected fixed behavior:

```text
No Golden Pot hang
No repeated pipe/eventfd exhaustion after opening the lobby
```

See [ersc-esync-file-descriptor-fix-2026-05-16.md](ersc-esync-file-descriptor-fix-2026-05-16.md) for the full report.

## Elden Ring ERSC Golden Pot Freezes The Frame

Symptom:

```text
The frame freezes when opening the world to wanderers with the Golden Pot, but audio may continue.
```

Observed Steam logs:

```text
StartVoiceRecording() (was recording: 0)
Created OPUS PLC voice encoder
DirectSoundCaptureDevice.lock wait timed out
CSteamEngine::BMainLoop appears to have stalled
fatal stalled cross-thread pipe
```

Cause: ERSC opening the lobby triggers Steam Voice. On the tested GPTK/Wine build, Steam's DirectSound microphone capture path can lock the Steam process and stall the game.

Fix: run Steam and ERSC with a GPTK runner where DirectSound capture returns `DSERR_NODRIVER`. Playback remains enabled; microphone capture is disabled for this runner.

```zsh
export GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513"
gptk-steam --no-log
```

Then:

```zsh
cd "$ER_GAME_DIR"
WINEDLLOVERRIDES='winmm=n,b;steam_api64=n,b' \
  gptk-launch --prefix Steam --set-winver win10 --no-dxr --log-file "$GPTK_HOME/logs/ERSC-dsound-nocap.log" -- ./ersc_launcher.exe
```

See [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md) for the full report.

If the freeze returns after updating the toolkit, verify that the explicit runner override survives config loading:

```zsh
env GPTK_WINE_HOME="$HOME/GPTK/runners/gptk-dsound-nocap-20260513" \
  zsh -c 'source "$HOME/GPTK/libexec/gptk-common.zsh"; print -r -- "$GPTK_WINE_HOME"'
```

The output must be the patched runner path, not `/Applications/Game Porting Toolkit.app/...`.

See [golden-pot-runner-precedence-fix-2026-05-14.md](golden-pot-runner-precedence-fix-2026-05-14.md) for the update regression report.

## Missing NTLM Support

Wine may warn:

```text
ntlm_auth was not found or is outdated
```

On macOS with Homebrew, Samba provides `ntlm_auth`:

```zsh
brew install samba
```

Restart the prefix after installing.

## Display Mode Warning

Warning:

```text
No matching mode found WIDTHxHEIGHTx32 @REFRESH
```

This is not always fatal. If the game is running, treat it as a display mode negotiation warning first. Try borderless/windowed settings or a common refresh rate if it blocks startup.
