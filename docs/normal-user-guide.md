# Normal User Guide

This is the short path for people who downloaded the DMG and want to use the app without learning every script first.

## What The DMG Includes

The DMG includes the **RipperMoonKit Launcher** app only.

It does not include:

- Apple Game Porting Toolkit;
- Steam;
- games;
- saves;
- mods.

Apple GPTK must be downloaded from Apple. Steam is installed later only if a game needs Steam.

## Step By Step

1. Download the latest RipperMoonKit DMG.
2. Open the DMG.
3. Drag **RipperMoonKit Launcher.app** into **Applications**.
4. Open **RipperMoonKit Launcher.app**.
5. If macOS blocks the app, open **System Settings > Privacy & Security**, allow the app, then open it again.
6. Follow the first-run setup guide and click **Set Up RipperMoonKit**.
7. The app prepares its own toolkit source clone under `~/Library/Application Support/RipperMoonKit/source`.
8. If GPTK is missing, the app pauses on **Download Game Porting Toolkit 3.0** and opens Apple's download page.
9. Download **Game Porting Toolkit 3.0** from Apple.
10. Open the downloaded GPTK DMG so it appears in Finder under **Locations**.
11. Return to RipperMoonKit. The **Begin GPTK Install** button becomes available after the app detects the downloaded DMG or mounted GPTK media.
12. Click **Begin GPTK Install**.
13. If setup was interrupted, keep the GPTK DMG mounted and click **Begin GPTK Install** again. The app should stay on the setup checklist until GPTK 3.0 is copied and verified.
14. Open **Settings > Paths** and confirm the folders look correct for your Mac.
15. Open the **Steam** profile. If it still shows **Install Steam**, click it and wait until validation finds `steam.exe`.
16. For Elden Ring ERSC or other co-op Steamworks test paths, open the **Steam** profile and click **Install Spacewar** once.
17. Wait for Steam to finish AppID 480 / Spacewar setup, then close Spacewar.
18. Open or add a game profile.
19. Set the game folder and executable.
20. Click **Launch**.

## If GPTK Setup Stops At The Nested Image

Some GPTK downloads contain a nested image named:

```text
Evaluation environment for Windows games 3.0.dmg
```

If setup stops after saying it is attaching that image:

1. Check Finder and confirm the main **Game Porting Toolkit** DMG is mounted.
2. Confirm the nested **Evaluation environment for Windows games 3.0** image is also mounted.
3. Leave both mounted.
4. Return to RipperMoonKit.
5. Click **Begin GPTK Install**.
6. After GPTK finishes, confirm the first-run checklist is green.

This is safe to retry. RipperMoonKit keeps local configuration, saves, Wine prefixes, Steam data, and game folders outside the app bundle.

## Where To Look If Something Fails

Open the newest log in:

```text
$GPTK_HOME/logs/
```

In the app, use:

```text
Settings > Maintenance
```

Use **Begin GPTK Install** for GPTK/runtime setup.
Use **Install Toolkit** for helper scripts, patches, and local command refresh.

## What To Read Next

- [installation.md](installation.md): full install details.
- [gui.md](gui.md): what each app button does.
- [steam.md](steam.md): Steam setup.
- [elden-ring-ersc.md](elden-ring-ersc.md): Elden Ring co-op setup.
- [troubleshooting.md](troubleshooting.md): common problems.
