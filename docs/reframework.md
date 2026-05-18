# REFramework Support Plan

Status: planned investigation, not currently supported.

RipperMoonKit does not yet ship a REFramework compatibility profile. The goal is to support Resident Evil / RE Engine games through normal RipperMoonKit game profiles once the REFramework + Wine/D3DMetal path is repeatable.

## Why This Needs A Separate Track

REFramework hooks D3D12 paths that behave differently under Apple's D3DMetal translation layer than they do on native Windows or Proton/DXVK. A useful upstream reference is praydog/REFramework pull request #1589:

https://github.com/praydog/REFramework/pull/1589

That PR was closed, so it should be treated as research material rather than a drop-in fix. The discussion and commits identify several areas worth testing:

- D3D12 device creation should use a real adapter on Wine/D3DMetal instead of `D3D12CreateDevice(nullptr, ...)`.
- Command queue discovery may need a D3DMetal-safe fallback because wrapped COM objects can break direct pointer comparison.
- QueryInterface can deadlock under D3DMetal, so object identity checks may need AddRef/Release-style probing or arithmetic pointer correction.
- Wine-specific memory protection paths need careful handling because Wine's `NtProtectVirtualMemory` path is not the same as a native Windows syscall stub.

## RipperMoonKit Scope

The first RipperMoonKit implementation should not bundle REFramework builds. It should provide:

- an RE Engine game profile template;
- per-game DLL override fields for REFramework loader placement;
- validation checks for expected REFramework files such as `dinput8.dll` where applicable;
- launcher notes for D3D12 / D3DMetal flags;
- a tester-report template section for REFramework logs, game version, runner, and restart behavior;
- documentation that links to upstream REFramework work and asks users to provide exact game/version reports.

## Test Matrix

The initial compatibility pass should test:

- at least one modern RE Engine D3D12 title;
- stock GPTK 3 runner versus any locally patched runner;
- Steam and non-Steam launch paths where legally owned game files are available;
- cold launch, second launch after restart, and launch after macOS reboot;
- REFramework overlay load, plugin load, input handling, and crash behavior.

## Success Criteria

REFramework support should only be marked usable when a tester can:

1. Install or place REFramework files through a documented profile flow.
2. Launch the target RE Engine game from RipperMoonKit.
3. See REFramework initialize consistently after a full app restart.
4. Relaunch after closing Steam/Wine without manual file edits.
5. Provide logs showing the same behavior across at least two clean sessions.

