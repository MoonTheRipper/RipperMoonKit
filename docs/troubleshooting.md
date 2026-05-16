# Troubleshooting

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
