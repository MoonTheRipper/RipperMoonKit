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
6. Follow the first-run setup guide and click **Start Guided Setup**.
7. The app prepares its own toolkit source clone under `~/Library/Application Support/RipperMoonKit/source`.
8. If the app says GPTK is missing, download **Game Porting Toolkit 3.0** from Apple.
9. Open the downloaded GPTK DMG so it appears in Finder under **Locations**.
10. Return to RipperMoonKit and continue **Start Guided Setup**, or click **Install GPTK** if only the GPTK step needs another try.
11. If setup was interrupted, keep the GPTK DMG mounted and click **Start Guided Setup** again. The app should stay on the setup checklist until GPTK 3.0 is copied and verified.
12. Open **Settings > Paths** and confirm the folders look correct for your Mac.
13. Open the **Steam** profile. If it still shows **Install Steam**, click it and wait until validation finds `steam.exe`.
14. For Elden Ring ERSC or other co-op Steamworks test paths, open the **Steam** profile and click **Install Spacewar** once.
15. Wait for Steam to finish AppID 480 / Spacewar setup, then close Spacewar.
16. Open or add a game profile.
17. Set the game folder and executable.
18. Click **Launch**.

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
5. Click **Start Guided Setup** again, or **Install GPTK** if only GPTK is missing.
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

Use **Install GPTK** for GPTK/runtime setup.
Use **Install Toolkit** for helper scripts, patches, and local command refresh.

## What To Read Next

- [installation.md](installation.md): full install details.
- [gui.md](gui.md): what each app button does.
- [steam.md](steam.md): Steam setup.
- [elden-ring-ersc.md](elden-ring-ersc.md): Elden Ring co-op setup.
- [troubleshooting.md](troubleshooting.md): common problems.
