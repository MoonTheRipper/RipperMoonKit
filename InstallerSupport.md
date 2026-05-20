# Installer Support Checklist

This file tracks the native installer support work for RipperMoonKit. The goal is to let non-technical users install, update, launch, and remove supported Windows games through the macOS app without needing Terminal for the normal path.

## Hard Safety Rules

- [ ] Never install a test build over the normal local app.
- [ ] The normal user app remains `~/Applications/RipperMoonKit Launcher.app`.
- [ ] Test builds use a separate bundle name: `RipperMoonKit Test Launcher.app`.
- [ ] Test builds use a separate bundle identifier: `com.rippermoon.toolkit.launcher.test`.
- [ ] Fresh-install testing uses the real macOS user `moontheripper`.
- [ ] Test app state lives under `/Users/moontheripper`.
- [ ] Production app state lives under the current user's home folder.
- [ ] No test script may target `/Applications`.
- [ ] No test script may target another user's `~/Applications/RipperMoonKit Launcher.app`.

## Test User Flow

Use the test-user scripts instead of installing the app into the normal account.

- [ ] Prepare the real macOS test user:

  ```zsh
  zsh scripts/test-user-prepare.zsh
  ```

- [ ] Build and install the isolated test app:

  ```zsh
  zsh scripts/install-test-gui-app.zsh
  ```

- [ ] Open the test app from the `moontheripper` account:

  ```text
  /Users/moontheripper/Applications/RipperMoonKit Test Launcher.app
  ```

- [ ] Confirm the test app creates config only in `/Users/moontheripper`.
- [ ] Confirm the normal user's `~/Applications/RipperMoonKit Launcher.app` is not modified.
- [ ] Confirm Spotlight does not confuse the production app with the test app.
- [ ] Reset the test app and state when needed:

  ```zsh
  zsh scripts/test-user-reset.zsh --all
  ```

- [ ] Delete the temporary test user only when intentionally ending the test cycle:

  ```zsh
  zsh scripts/test-user-reset.zsh --delete-user
  ```

## Native Steam Installer Goals

RipperMoonKit should support Steam games as first-class library entries, not only as games launched through the Windows Steam GUI.

- [ ] Steam remains available as an individual app profile.
- [ ] Steam can still be used as a dependency for games that need Steam APIs.
- [ ] Users can search for a Steam game by title.
- [ ] Search should show likely matches when the title is not exact.
- [ ] Users can paste a Steam URL or numeric AppID.
- [ ] Users can choose where the game should be installed before downloading.
- [ ] Users can install through a GUI flow instead of seeing Terminal.
- [ ] Users can authenticate through an in-app SteamCMD/auth window.
- [ ] RipperMoonKit does not store Steam passwords.
- [ ] Existing SteamCMD session state should be reused where Steam allows it.
- [ ] Steam Guard code prompts should be handled in the GUI.
- [ ] QR login support is a future target if the selected Steam auth path supports it reliably.

## Game Install State

Each Steam-installed game profile should track enough state for the GUI to explain what is happening.

- [ ] Steam AppID.
- [ ] Install method: copied folder, SteamCMD, or Windows Steam.
- [ ] Install root.
- [ ] Resolved game folder.
- [ ] Resolved executable once detected.
- [ ] Download/install status.
- [ ] Progress percentage when available.
- [ ] Last install or update log.
- [ ] Last known build ID when available.
- [ ] Whether Steam must be running before launch.

## GUI Checkpoints

- [ ] Add an install flow from the Library view.
- [ ] Add a Steam game search step.
- [ ] Add an install location step.
- [ ] Add an authentication step.
- [ ] Add a download/progress step.
- [ ] Add a final profile review step.
- [ ] Show progress on the game profile tile and profile page.
- [ ] Add actions for install, update, validate, launch, close game, uninstall files, and delete profile.
- [ ] Keep "delete profile" separate from "delete game files".
- [ ] Never delete saves or user configs unless the user explicitly chooses that behavior.

## Steam Install Checkpoints

- [ ] Verify native SteamCMD exists or install it into the user's GPTK tools folder.
- [ ] Use Windows platform content for SteamPipe downloads.
- [ ] Install to the chosen library folder, including external drives such as `GAMECORE-1`.
- [ ] Record logs under the active user's `GPTK/logs`.
- [ ] Detect success from manifest/build/depot state.
- [ ] Detect common failure states such as corrupt download, missing file privileges, disk write failures, and ownership problems.
- [ ] Provide retry and validate actions after failure.

## Acceptance Tests

- [ ] `swift build` succeeds.
- [ ] Shell scripts pass `zsh -n`.
- [ ] Test app installs only to `/Users/moontheripper/Applications/RipperMoonKit Test Launcher.app`.
- [ ] Test app has bundle ID `com.rippermoon.toolkit.launcher.test`.
- [ ] Production app bundle ID remains `com.rippermoon.toolkit.launcher`.
- [ ] The production app in the normal user account is not touched by test scripts.
- [ ] AppID `480` can be used as a low-risk SteamCMD smoke install.
- [ ] A larger Steam game can be installed to an external drive.
- [ ] The GUI can recover from a failed or interrupted install.
- [ ] Uninstall removes game files only when requested.
- [ ] Profile deletion does not remove game files unless separately requested.

## Current Script Map

- `scripts/test-user-prepare.zsh`: creates or validates the `moontheripper` test account and folders.
- `scripts/install-test-gui-app.zsh`: builds a separate test app and installs it into the test account.
- `scripts/run-test-gui-app-as-user.zsh`: opens the test app only when the active GUI session belongs to the test user, or runs a binary smoke check.
- `scripts/test-user-reset.zsh`: removes isolated test app/state, and can delete the test account only with explicit confirmation.
- `scripts/steamcmd-windows-install.zsh`: experimental native SteamCMD Windows-platform downloader.
- `scripts/steam-install-probe.zsh`: watches Windows Steam install state and records failure checkpoints.
