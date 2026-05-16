# ERSC Esync File Descriptor Fix

Date: 2026-05-16

## Summary

Elden Ring ERSC could launch correctly, open the world through the Golden Pot, then hang or close after a few minutes. Activity Monitor could show high Metal and app memory numbers, but the confirmed failure was not a macOS memory-pressure kill.

The working fix was to launch both Steam and ERSC from the same `Steam` prefix with esync disabled.

## Symptoms

- ERSC launched and entered the game.
- Opening the Golden Pot lobby could work briefly, then the game closed.
- Activity Monitor showed large virtual or GPU-related memory numbers.
- No new macOS Jetsam-style memory report was produced.

Relevant log signatures:

```text
gptk: open-file limit 49152
pipe: Too many open files
eventfd: Too many open files
NtCreateFile Too many open files
wine: Unhandled page fault
```

The important detail is that this still happened after the launcher raised the open-file limit to `49152`, which ruled out the earlier low `ulimit -n` problem as the only cause.

## Root Cause

Steam, Spacewar/AppID 480, and ERSC opened many Wine synchronization descriptors while esync was enabled. Under this GPTK/Wine runner, the Steam prefix eventually hit `pipe` / `eventfd` exhaustion and then crashed or closed the game.

This looked like a memory problem in Activity Monitor, but the logs pointed to Wine esync descriptor pressure.

## Fix

The Elden Ring ERSC profile now repairs itself to:

```text
noEsync = true
```

The GUI passes this through to both Steam and ERSC as:

```text
GPTK_WINEESYNC=0
```

Steam and ERSC must use the same esync setting inside the same Wine prefix. Do not launch Steam manually with esync enabled and then launch ERSC with esync disabled.

## Required Restart

The fix only applies to newly launched Wine processes. Stop the existing Steam prefix before testing:

```zsh
gptk-steam --kill
```

Then reopen RipperMoonKit and launch the Elden Ring ERSC profile again.

## Confirmed Result

After disabling esync for the ERSC profile and restarting the Wine prefix, the Golden Pot workflow no longer hung.

## Related Fixes

- [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md): DirectSound capture workaround for the earlier Steam Voice lock.
- [golden-pot-runner-precedence-fix-2026-05-14.md](golden-pot-runner-precedence-fix-2026-05-14.md): ensures profile-specific runners survive updates.
