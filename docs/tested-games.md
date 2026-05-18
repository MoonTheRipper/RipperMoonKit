# Known Tested Games

This page records real RipperMoonKit test notes. It is not a universal compatibility promise; it explains why each profile exists, how it was launched, and what to check when the behavior changes.

## Elden Ring + Seamless Co-op / ERSC

Status: Gold

Tested with an already-installed Windows game folder copied to the Mac games drive. Steam must be running in the same prefix so ERSC can see Steam API state and Spacewar/AppID 480.

- Why this profile exists: ERSC, Steam networking, ModEngine, and Randomizer need repeatable DLL overrides and a stable prefix.
- How it launches: use the Steam profile's **Install Spacewar** action once, close Spacewar after setup finishes, then start Steam and launch ERSC or ModEngine from the Elden Ring profile with native `winmm` and `steam_api64`.
- Known fixes: use the no-capture DirectSound runner and no-esync path for Golden Pot stability.

See [elden-ring.html](elden-ring.html), [ersc-esync-file-descriptor-fix-2026-05-16.md](ersc-esync-file-descriptor-fix-2026-05-16.md), and [steam-voice-capture-fix-2026-05-13.md](steam-voice-capture-fix-2026-05-13.md).

## Clair Obscur: Expedition 33

Status: Playable

Tested through GPTK with AVX and D3D12 flags. A Wine C++ runtime assertion can appear from `winegstreamer/colorconvert.c`; ignoring it allowed the cutscene and game to continue in the tested setup.

- Why this profile exists: the game is graphically heavy and sensitive to renderer and driver checks.
- How it launches: use the profile's AVX/no-DXR launch path and enable the game's own upscaling options from in-game settings.
- Troubleshooting: if a NVIDIA driver prompt appears, it is the Windows game seeing a compatibility-reported GPU. On Apple Silicon, do not install NVIDIA drivers.

See [clair-obscur-dlss-metalfx.md](clair-obscur-dlss-metalfx.md).

## God of War Ragnarok

Status: Partial

Tested with the PlayStation PC runtime installer run inside the game prefix. Launch work focused on the missing runtime path, GameInput/API stubs, and D3D12 behavior under GPTK.

- Why this profile exists: the game has extra PlayStation PC runtime expectations that a basic Wine prefix does not provide.
- How it launches: install the PSPC runtime first, then launch the game executable with the profile-specific compatibility flags.
- Troubleshooting: if it exits early, check logs for missing API/runtime messages before changing graphics flags.

See [gowr.md](gowr.md).

## Steam For Windows

Status: Dependency

Steam is both a standalone app profile and a dependency for games that need Steam APIs. Downloads, Steam Web Runtime updates, Spacewar/AppID 480 setup, and Steam-managed games should stay in the Steam prefix.

- Why this profile exists: many Windows games check Steam state even when their game files are copied locally.
- How it launches: start Steam from the library, let a game profile start it first when required, or use **Install Spacewar** once for co-op workflows that need AppID 480 initialized.
- Troubleshooting: for webhelper or content unavailable issues, repair Steam compatibility and check the Steam logs.

See [steam.md](steam.md) and [troubleshooting.html#steam](troubleshooting.html#steam).

## Planned: REFramework / RE Engine Games

Status: Planned

REFramework support is not currently marked tested. It is on the roadmap as a dedicated compatibility track because REFramework's D3D12 hooks can run into Wine/D3DMetal-specific behavior.

- Why this profile would exist: Resident Evil / RE Engine games need a repeatable way to place REFramework files, preserve per-game DLL overrides, and collect launch logs.
- Current research reference: [praydog/REFramework pull request #1589](https://github.com/praydog/REFramework/pull/1589), which explored Wine/D3DMetal support for D3D12Hook.
- Next step: collect tester reports for exact game version, REFramework build, runner, launch flags, and whether the setup survives restart.

See [reframework.html](reframework.html).
