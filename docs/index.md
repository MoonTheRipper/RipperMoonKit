# Documentation Index

Use this page as the grouped navigation map for RipperMoonKit. The GitHub Pages version also includes the same documentation tree as collapsible sidebar groups.

<details open>
<summary><strong>First-Time Setup</strong></summary>

1. [quickstart.md](quickstart.md): shortest working install path.
2. [installation.md](installation.md): DMG install and source install paths.
3. [gptk.md](gptk.md): downloading GPTK 3 from Apple, mounting it, and letting the installer copy it locally.
4. [setup.md](setup.md): first-time setup and path model.
5. [dependencies.md](dependencies.md): installer bootstrap behavior and logs.
6. [steam.md](steam.md): Windows Steam install and launch flow.
7. [commands.md](commands.md): command reference.

</details>

<details open>
<summary><strong>Launcher And Configuration</strong></summary>

- [gui.md](gui.md): SwiftUI launcher build/run workflow.
- [configuration.md](configuration.md): all supported environment variables.
- [drives.md](drives.md): custom Wine drive mappings.
- [visual-c-runtime.md](visual-c-runtime.md): Microsoft Visual C++ runtime installation for Wine prefixes.
- [stubs.md](stubs.md): API stub DLLs for games that delay-load missing Wine/GPTK libraries.
- [update-safety.md](update-safety.md): backups, protected paths, and rollback.
- [uninstall.md](uninstall.md): conservative uninstall behavior and optional config/save removal.

</details>

<details open>
<summary><strong>Game Workflows</strong></summary>

- [proof-of-concept.md](proof-of-concept.md): screenshots of the launcher and Elden Ring running on macOS through GPTK.
- [game-folder-workflow.md](game-folder-workflow.md): copying an already-installed Windows game folder.
- [tested-games.md](tested-games.md): known tested games, launch notes, and troubleshooting links.
- [elden-ring-ersc.md](elden-ring-ersc.md): Elden Ring ERSC tested launch path.
- [elden-ring-ersc.md#tool-credits](elden-ring-ersc.md#tool-credits): credits for ModEngine 2, Seamless Co-op/ERSC, and the setup reference repo used by the Mod Manager flow.
- [reframework.md](reframework.md): planned REFramework support track for Resident Evil / RE Engine games.
- [clair-obscur-dlss-metalfx.md](clair-obscur-dlss-metalfx.md): Clair Obscur DLSS through GPTK MetalFX.
- [gowr.md](gowr.md): God of War Ragnarok launch setup, GameInput stub, and working command.
- [save-transfer.md](save-transfer.md): finding and restoring save files.

</details>

<details>
<summary><strong>Repair Notes And Support</strong></summary>

- [troubleshooting.md](troubleshooting.md): failure modes and checks.
- [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md): Golden Pot freeze bug report and DirectSound capture workaround.
- [golden-pot-runner-precedence-fix-2026-05-14.md](golden-pot-runner-precedence-fix-2026-05-14.md): update regression fix for profile-specific GPTK runners.
- [ersc-esync-file-descriptor-fix-2026-05-16.md](ersc-esync-file-descriptor-fix-2026-05-16.md): Golden Pot hang and close fix for Wine esync file descriptor exhaustion.
- [faq.md](faq.md): common questions.

</details>

<details>
<summary><strong>Maintainers</strong></summary>

- [release-checklist.md](release-checklist.md): checks before publishing a GitHub release.
- [roadmap.md](roadmap.md): planned SwiftUI launcher and future compatibility profile support.

</details>
