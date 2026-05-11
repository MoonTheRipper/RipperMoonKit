# Game Folder Workflow

Some Windows game installers behave poorly under GPTK/Wine even when the installed game itself can run. For those cases, use a pre-installed folder workflow.

## Recommended Pattern

1. Install the game on a Windows PC.
2. Fully patch/update it on Windows.
3. Copy the installed game folder to external storage.
4. Put that folder under:

```text
$GPTK_EXTERNAL_ROOT/Games/<GameName>/
```

5. Launch the game executable from that copied folder with `gptk-launch`.

## What Not To Copy

Do not copy only installer files when the docs call for an installed folder.

Installer files usually look like:

```text
setup.exe
setup-1.bin
setup-2.bin
redist/
```

Installed game folders usually contain the actual runtime executable and game data:

```text
Game.exe
Game_Data/
engine/config/data folders
runtime DLLs
```

## Elden Ring ERSC Tested Layout

The ERSC flow in this toolkit was tested with an already-installed offline/non-Steam Windows game folder copied into:

```text
$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game/
```

Expected minimum files:

```text
eldenring.exe
ersc_launcher.exe
SeamlessCoop/ersc.dll
SeamlessCoop/ersc_settings.ini
```

The launcher command should run from that `Game` folder, not from the installer folder.

## Create A Launcher For A Copied Folder

Example:

```zsh
gptk-game create "EldenRing-ERSC" "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game/ersc_launcher.exe" --prefix Steam --workdir "$GPTK_EXTERNAL_ROOT/Games/EldenRing/Game"
```

For ERSC specifically, use the documented command in `docs/elden-ring-ersc.md` because it needs Steam running and the correct DLL overrides.

