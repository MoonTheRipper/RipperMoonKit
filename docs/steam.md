# Windows Steam Guide

Steam runs in a dedicated prefix named `Steam` by default.

## Install Steam

The app and installer download `SteamSetup.exe` to:

```text
~/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe
```

Install or repair Steam:

```zsh
gptk-steam --install-only --install "$HOME/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe"
```

The install is considered successful only when `steam.exe` exists inside the Steam prefix. The `--install-only` flag validates that file, applies the Steam compatibility settings, then stops Steam instead of launching the Steam UI. This keeps first-run setup from hanging while Steam updates itself.

The guided app setup starts Steam installation in the background, then moves to the finished screen so the user can set game folders and cover art while Steam finishes. The Steam tile shows **Install Steam** until validation passes, then changes to **Repair Steam**. Open that Steam profile later when you are ready to sign in.

From source, the matching background install command is:

```zsh
./install.zsh --install-steam-background
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

Some Steamworks test paths use Spacewar/AppID 480. In co-op workflows such as Elden Ring Seamless Co-op, the mod may use Steam networking while the game itself is launched from a copied folder. Steam still needs the local AppID 480 state available inside the Steam prefix.

This is a run-once setup step. Launch AppID 480 from the Steam profile, let Steam finish installing Spacewar and any first-run redistributables, then close Spacewar. After that, start Steam normally before launching the co-op game.

From the GUI:

1. Open the **Steam** profile.
2. Click **Install Spacewar**.
3. Wait for Steam to finish AppID 480 setup.
4. Close Spacewar.
5. Launch the co-op game profile.

From Terminal:

```zsh
gptk-steam --log --install-spacewar
```

The raw Steam argument form is equivalent:

```zsh
gptk-steam --log -applaunch 480
```

If the app has first-run redistributables, let Steam finish them before launching a game that depends on that Steamworks state.
