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

Apple GPTK must be downloaded from Apple. Steam is installed by the guided setup, but it is not bundled in the DMG.

## Step By Step

1. Download the latest RipperMoonKit DMG.
2. Open the DMG.
3. Run **Install to My Applications.command**, or copy **RipperMoonKit Launcher.app** into `~/Applications`.
4. Open **RipperMoonKit Launcher.app**.
5. If macOS blocks the app, open **System Settings > Privacy & Security**, allow the app, then open it again.
6. Follow the first-run setup guide and click **Set Up RipperMoonKit**.
7. The app prepares its own toolkit source clone under `~/Library/Application Support/RipperMoonKit/source`.
8. If GPTK is missing, the app pauses on **Download Game Porting Toolkit 3.0** and opens Apple's download page.
9. Download **Game Porting Toolkit 3.0** from Apple.
10. Open the downloaded GPTK DMG so it appears in Finder under **Locations**.
11. Return to RipperMoonKit. The **Begin GPTK Install** button becomes available after the app detects the downloaded DMG or mounted GPTK media.
12. Click **Begin GPTK Install**. RipperMoonKit can install the GPTK app runner with Homebrew if it is missing, then copy the Apple GPTK runtime locally.
13. The setup then starts Windows Steam installation in the background. Steam can take several minutes, but you do not need to wait on that screen.
14. If setup was interrupted, keep the GPTK DMG mounted and run setup again. The app should stay on the setup checklist until GPTK 3.0 and the runner are verified.
15. When the **You're all set** screen appears, Steam may still be installing in the background. You can set paths and cover art while it finishes.
16. Open the **Steam** profile when you are ready to sign into Steam.
17. Open **Settings > Paths** and confirm the folders look correct for your Mac.
18. Add or open a game profile.
19. Set the game folder to a copied, already-installed Windows game folder. Do not point the app at installer files.
20. Add a free TheGamesDB API key in settings if you want cover art in the game library.
21. For Elden Ring ERSC or other co-op Steamworks test paths, open the **Steam** profile and click **Install Spacewar** once.
22. Wait for Steam to finish AppID 480 / Spacewar setup, then close Spacewar.
23. Click **Launch** on the game profile.

RipperMoonKit should be installed per user at `~/Applications/RipperMoonKit Launcher.app`. Avoid `/Applications` unless you intentionally want a system-wide copy. User-scoped installs keep test users clean and prevent one stale app from affecting another account.

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
