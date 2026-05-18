# Documentation Index

Use this page as the navigation map for RipperMoonToolKit.

## First-Time Users

Read in this order:

1. [quickstart.md](quickstart.md)
2. [gptk.md](gptk.md)
3. [setup.md](setup.md)
4. [steam.md](steam.md)
5. [commands.md](commands.md)

## Configuration

- [configuration.md](configuration.md): all supported environment variables.
- [drives.md](drives.md): custom Wine drive mappings.
- [dependencies.md](dependencies.md): installer bootstrap behavior and logs.
- [visual-c-runtime.md](visual-c-runtime.md): Microsoft Visual C++ runtime installation for Wine prefixes.
- [stubs.md](stubs.md): API stub DLLs for games that delay-load missing Wine/GPTK libraries (GameInput, etc.).
- [update-safety.md](update-safety.md): backups, protected paths, and rollback.
- [gui.md](gui.md): SwiftUI launcher build/run workflow.
- [uninstall.md](uninstall.md): conservative uninstall behavior and optional config/save removal.

## Game Workflows

- [proof-of-concept.md](proof-of-concept.md): screenshots of the launcher and Elden Ring running on macOS through GPTK.
- [game-folder-workflow.md](game-folder-workflow.md): copying an already-installed Windows game folder.
- [tested-games.md](tested-games.md): known tested games, why their profiles exist, launch notes, and troubleshooting links.
- [elden-ring-ersc.md](elden-ring-ersc.md): Elden Ring ERSC tested launch path.
- [elden-ring-ersc.md#tool-credits](elden-ring-ersc.md#tool-credits): credits for ModEngine 2, Seamless Co-op/ERSC, and the setup reference repo used by the Mod Manager flow.
- [reframework.md](reframework.md): planned REFramework support track for Resident Evil / RE Engine games.
- [clair-obscur-dlss-metalfx.md](clair-obscur-dlss-metalfx.md): Clair Obscur DLSS through GPTK MetalFX.
- [save-transfer.md](save-transfer.md): finding and restoring save files.

## Support

- [troubleshooting.md](troubleshooting.md): failure modes and checks.
- [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md): Golden Pot freeze bug report and DirectSound capture workaround.
- [golden-pot-runner-precedence-fix-2026-05-14.md](golden-pot-runner-precedence-fix-2026-05-14.md): update regression fix for profile-specific GPTK runners.
- [ersc-esync-file-descriptor-fix-2026-05-16.md](ersc-esync-file-descriptor-fix-2026-05-16.md): Golden Pot hang and close fix for Wine esync file descriptor exhaustion.
- [gowr.md](gowr.md): God of War Ragnarök launch setup, GameInput stub, and working command.
- [faq.md](faq.md): common questions.

## Maintainers

- [release-checklist.md](release-checklist.md): checks before publishing a GitHub release.
- [roadmap.md](roadmap.md): planned SwiftUI launcher and future compatibility profile support.
