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

