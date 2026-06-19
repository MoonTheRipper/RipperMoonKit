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

## Controller Layouts

Steam's in-client controller configurator (the layout/template editor) renders blank under GPTK. The editor is a CEF (Chromium) web view, and GPTK's Wine cannot give CEF's GPU process a working shared-image context (`SharedImageStub: unable to create context`), so that view detaches and shows nothing. Controller detection, sign-in, and the Steam Input runtime all work — only the visual editor fails to paint.

To assign a layout without that editor, RipperMoonKit copies a Steam Input config (`.vdf`) into the prefix's `controller_base/templates` and writes the selection into the controller config sets, which Steam reads at startup. Obtain a `controller_mappings` `.vdf`, then:

From the GUI:

1. Open the **Steam** profile and stop Steam if it is running.
2. Expand **Controller Layout** and turn it on.
3. Set the **App ID** (480 is Spacewar, Valve's free Steamworks sample) and pick the layout **.vdf**.
4. Click **Apply Layout**, then start Steam and launch the app with the controller connected.

From Terminal:

```zsh
gptk-steam --kill
gptk-steam-layout apply --app-id 480 --layout /path/to/layout.vdf
gptk-steam-layout status --app-id 480
```

The selection is written for the layout's controller type plus matching physical pads. Steam loads it as the "Local Selection Path" for that app id. Edited config sets are backed up under the account's `config/.rmk-backup-<timestamp>` folder first. Use `gptk-steam-layout remove --app-id 480` to clear it.

Steam must be stopped when applying or removing: Steam reads these config sets at startup and rewrites them on exit, so an edit made while it is running is lost.

## Adding an installed Steam game as a profile

A game you downloaded inside Steam (for example It Takes Two) needs Steam's own launch environment, so it cannot run from the plain copied-folder path. Instead it runs as a Steam-managed profile that launches through `gptk-steam -applaunch <app-id>` — which starts Steam in the background, so you never open the Steam UI by hand.

From the GUI:

1. Install the game in Steam (open the Steam profile, sign in, install to the internal `S:` library to avoid external-drive download failures).
2. In the library, click **Add Steam Game**. It scans the installed Steam library across mounted drives (games on an unplugged external drive are skipped) and lists what it finds.
3. Pick the game and click **Add**. It appears as a tile; its **Launch** button starts Steam and the game in one click.

You can also set a profile's **Steam App ID** by hand in App Settings to make any profile launch this way. The download path itself prefers the internal `S:` library; a Steam library on an external drive that unmounts mid-download is the usual cause of "Unpack failed" content errors.
