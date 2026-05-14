# Microsoft Visual C++ Runtime

Some Windows games exit early when the Microsoft Visual C++ runtime is missing from the Wine prefix. In Wine/GPTK there is no single Windows-wide runtime install that every prefix automatically shares; the runtime must be present inside the prefix that starts the game.

RipperMoonKit handles this with `gptk-vcrun`:

- downloads Microsoft's current Visual C++ v14 redistributables once;
- caches them under `$GPTK_HOME/downloads/vcredist`;
- installs x64 and x86 runtimes into one selected prefix or every existing prefix.

Microsoft's current supported download page lists the latest Visual C++ v14 redistributable permalinks:

```text
https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
```

## Install Into One Prefix

```zsh
gptk-vcrun --prefix Dispatch
```

Use the same prefix name that the GUI profile uses.

## Install Into All Existing Prefixes

```zsh
gptk-vcrun --all
```

This scans `$GPTK_PREFIX_ROOT` and installs into each existing Wine prefix. It does not create new game prefixes by itself.

Archived prefixes whose names end in `.broken-*`, `.backup-*`, `.old-*`, or `.disabled-*` are skipped. This keeps rollback folders available without letting a damaged archived prefix stop active game prefixes from receiving the runtime.

## Download Only

```zsh
gptk-vcrun --download-only
```

## GUI

The SwiftUI launcher exposes two actions:

- per-game **Install VC++ Runtime** in the selected profile's Actions panel;
- global **Install VC++ Runtime** in Settings > Maintenance, which runs `gptk-vcrun --all`.

For games like Dispatch, use the per-game action first. Use the global action after creating several prefixes or after adding a new drive with game profiles that use separate prefixes.

## Cached Files

Defaults:

```text
RIPPERMOON_VCREDIST_X64_URL=https://aka.ms/vc14/vc_redist.x64.exe
RIPPERMOON_VCREDIST_X86_URL=https://aka.ms/vc14/vc_redist.x86.exe
RIPPERMOON_VCREDIST_DIR=$GPTK_HOME/downloads/vcredist
```

Override these only when Microsoft changes the official links or when testing a pinned redistributable.
