# Proof Of Concept: Elden Ring On Mac

RipperMoonKit was built around a real Apple Game Porting Toolkit workflow, not a mock setup. The screenshots below show the launcher and Elden Ring running on macOS with the GPTK HUD visible.

This example uses:

- RipperMoonKit's per-game launcher profile;
- Apple Game Porting Toolkit 3;
- a copied Windows game folder;
- Steam support for the ERSC flow;
- the Elden Ring Seamless Coop / ERSC profile.

RipperMoonKit does not include game files, saves, Steam data, or Apple runtime files. It helps organize the local setup that you already own and provide.

## Launcher Profile

![RipperMoonKit launcher showing the Elden Ring ERSC profile](assets/rippermoonkit-gui.png)

The launcher keeps each game in its own profile. A profile can have its own icon, game folder, Windows prefix, runner, launch options, and Steam requirement.

## Gameplay With GPTK HUD

![Elden Ring running on macOS through Apple Game Porting Toolkit with HUD visible](assets/elden-ring-grace-hud.png)

This capture shows Elden Ring running through Game Porting Toolkit 3 with the HUD visible during gameplay.

![Elden Ring boss fight running on macOS through Apple Game Porting Toolkit with HUD visible](assets/elden-ring-godrick-hud.png)

This second capture shows the same setup in a heavier gameplay scene. Treat these screenshots as proof of concept, not a performance guarantee for every Mac or every game.

## Where To Go Next

- [Quickstart](quickstart.md): install the toolkit.
- [GUI guide](gui.md): use the app instead of typing commands.
- [Elden Ring ERSC guide](elden-ring-ersc.md): follow the tested Elden Ring example.
