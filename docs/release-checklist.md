# Release Checklist

Use this before publishing the repository or creating a GitHub release.

## Safety

Confirm no local state is included:

```zsh
find . -maxdepth 3 \( -iname '*WinePrefixes*' -o -iname '*SteamLibrary*' -o -iname '*saves*' -o -iname '*.dmp' -o -iname '*.log' \) -print
```

Confirm patched runners and Apple runtime copies are not included:

```zsh
find . -maxdepth 3 \( -iname 'runners' -o -iname 'runtime' -o -iname '*.app' -o -iname 'dsound.dll' \) -print
```

Release packaging writes local artifacts under `dist.noindex/` so Spotlight does not surface generated app bundles as installed apps.

Confirm no machine-specific paths:

```zsh
rg --pcre2 -n '/Users/(?!USERNAME)|765611[0-9]+|/Volumes/.*/Games/EldenRing' . -g '!docs/release-checklist.md'
```

Expected result: no project files should contain personal paths or SteamIDs. Examples may contain generic `/Volumes/...` paths and `/Users/USERNAME` placeholders only when clearly illustrative.

## Syntax

Run zsh syntax checks:

```zsh
find . -type f \( -name '*.zsh' -o -name 'gptk-*' -o -name '*.example' \) -exec zsh -n {} \;
```

## Release Package Integrity

Build the release package and verify that signing did not silently fail:

```zsh
zsh scripts/package-release.zsh
codesign --verify --deep --strict --verbose=2 "dist.noindex/work-v$(<VERSION).noindex/RipperMoonKit Launcher.app"
hdiutil verify "dist.noindex/RipperMoonKit-Launcher.dmg"
```

The package script must stop if signing or DMG verification fails. Do not publish a DMG that contains unsealed files in the `.app` bundle root.

## Installer Smoke Test

Copy-only smoke test:

```zsh
HOME=/tmp/rippermoon-smoke \
GPTK_HOME=/tmp/rippermoon-smoke/GPTK \
GPTK_EXTERNAL_ROOT=/tmp/rippermoon-smoke/GameCoreApp \
./install.zsh --skip-deps --no-zshrc
```

Clean up:

```zsh
rm -rf /tmp/rippermoon-smoke
```

## GPTK Copy Smoke Test

Use a fake source to verify copy logic without redistributing Apple files:

```zsh
rm -rf /tmp/rippermoon-smoke /tmp/rippermoon-fake-gptk
mkdir -p "/tmp/rippermoon-fake-gptk/Game Porting Toolkit.app/Contents/Resources/wine/bin"
mkdir -p "/tmp/rippermoon-fake-gptk/Evaluation environment for Windows games 3.0/lib/wine/x86_64-windows"
mkdir -p "/tmp/rippermoon-fake-gptk/Evaluation environment for Windows games 3.0/lib/external"
printf '#!/bin/zsh\nexit 0\n' > "/tmp/rippermoon-fake-gptk/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64"
chmod +x "/tmp/rippermoon-fake-gptk/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64"
touch "/tmp/rippermoon-fake-gptk/Evaluation environment for Windows games 3.0/lib/wine/x86_64-windows/d3d12.dll"
touch "/tmp/rippermoon-fake-gptk/Evaluation environment for Windows games 3.0/lib/external/libd3dshared.dylib"

HOME=/tmp/rippermoon-smoke \
GPTK_HOME=/tmp/rippermoon-smoke/GPTK \
GPTK_EXTERNAL_ROOT=/tmp/rippermoon-smoke/GameCoreApp \
RIPPERMOON_BREW_FORMULAE="" \
./install.zsh --gptk-source /tmp/rippermoon-fake-gptk --skip-steam-download --no-homebrew-bootstrap --no-zshrc
```

Verify:

```zsh
test -x "/tmp/rippermoon-smoke/GPTK/apps/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64"
test -f "/tmp/rippermoon-smoke/GPTK/runtime/lib/wine/x86_64-windows/d3d12.dll"
```

Clean up:

```zsh
rm -rf /tmp/rippermoon-smoke /tmp/rippermoon-fake-gptk
```

## Documentation

Check that the README links work locally:

```zsh
rg -n '\]\(' README.md docs
```

Confirm the documentation map includes every major workflow:

- GPTK 3 download and mount.
- Dependency bootstrap.
- Configuration.
- Drive maps.
- Steam.
- Copied game folders.
- Elden Ring ERSC.
- Save transfer.
- Troubleshooting.
