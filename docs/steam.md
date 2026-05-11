# Windows Steam Guide

Steam runs in a dedicated prefix named `Steam` by default.

## Install Steam

Place `SteamSetup.exe` somewhere reachable, usually:

```text
$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe
```

Install:

```zsh
gptk-steam --install "$GPTK_EXTERNAL_ROOT/Installers/SteamSetup.exe"
```

## Start Steam

```zsh
gptk-steam --log
```

Keep that terminal open while Steam is running. Use a second terminal for game launches.

## Stop Steam

```zsh
gptk-steam --kill
```

This stops the Wine server for the Steam prefix. Use it when Steam is stuck, when you need to reset state, or when you are done testing.

## Steam Webhelper Compatibility

The wrapper applies per-application Windows 7 compatibility to:

```text
steam.exe
steamwebhelper.exe
steamservice.exe
```

The prefix itself stays on Windows 10 unless you change it. This keeps the workaround local to Steam and avoids forcing games into a Windows 7 environment.

Repair those entries:

```zsh
gptk-steam --repair-compat
```

## AppID 480 / Spacewar

Some Steamworks test paths use Spacewar/AppID 480.

Launch it through Steam:

```zsh
gptk-steam --log -applaunch 480
```

If the app has first-run redistributables, let Steam finish them before launching a game that depends on that Steamworks state.

