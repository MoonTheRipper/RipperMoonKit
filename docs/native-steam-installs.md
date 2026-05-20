# Native Steam Installs And SteamCMD Fallback

RipperMoonKit normally treats Windows Steam as a dependency: install Steam in the `Steam` prefix, sign in, and let Steam manage Steam games. That is still the preferred model when the Windows Steam client can finish the download.

The Resident Evil Village test exposed a different class of problem. The Steam GUI download reached the final depot staging/unpack phase and repeatedly ended with `Corrupt download`, even after disabling esync and even after moving the library from an external drive to the local APFS C: drive. That makes the issue look like a Windows Steam under GPTK/Wine install-path problem, not a simple drive-format or esync problem.

## What Steam Is Doing

Valve's SteamPipe system stores game content as depots split into compressed/encrypted chunks. The Steam client downloads those chunks, decrypts/decompresses them, stages them, then commits the installed depot into the library.

SteamCMD is Valve's command-line Steam client. Valve documents `+@sSteamCmdForcePlatformType windows`, `+force_install_dir`, `+login`, and `+app_update APPID validate` for installing SteamPipe content from Terminal.

Sources:

- Valve SteamPipe documentation: <https://partner.steamgames.com/doc/sdk/uploading>
- Valve SteamCMD documentation: <https://developer.valvesoftware.com/wiki/SteamCMD>

## New Probe Command

Use the probe when a Steam GUI install is already running. It does not delete files and does not start a download. It watches the manifest, content log, staged depots, and common networking assertions.

Resident Evil Village example:

```zsh
gptk-steam-probe \
  --appid 1196590 \
  --depot 1196591 \
  --library /Volumes/GAMECORE-1/SteamLibrary
```

One-time state snapshot:

```zsh
gptk-steam-probe --appid 1196590 --snapshot
```

The probe exits:

- `0` when the manifest looks complete.
- `80` when Steam content failures such as `Unpack failed` or `Corrupt download` are detected.
- `124` when it times out without a clear success/failure.

Logs are written to:

```text
$GPTK_HOME/logs/steam-install-probe-APPID-YYYYmmdd-HHMMSS.log
```

## SteamCMD Fallback

Use SteamCMD when the Windows Steam GUI repeatedly fails during unpack/staging. This downloads Windows-platform SteamPipe content from native macOS SteamCMD instead of asking the Windows Steam GUI inside GPTK/Wine to do the download.

Example targeting `GAMECORE-1`:

```zsh
gptk-steamcmd \
  --appid 1196590 \
  --login USERNAME \
  --target-root /Volumes/GAMECORE-1/SteamCMDLibrary \
  --name ResidentEvilVillage
```

Anonymous AppID example:

```zsh
gptk-steamcmd --appid 480 --anonymous
```

SteamCMD may ask for the Steam password and Steam Guard code in Terminal. RipperMoonKit does not store the password.

The fallback writes an install summary into the game folder:

```text
.rippermoon-steamcmd-install.txt
```

## Important Limits

SteamCMD is not a full replacement for the Windows Steam client:

- Some client games may refuse download through SteamCMD even when the account owns them.
- Some games still need Windows Steam running at launch for Steam APIs, ownership checks, or networking.
- The downloaded folder may not automatically appear as installed in the Windows Steam GUI.
- RipperMoonKit should treat this as a copied game folder afterward: add a game profile pointing at the downloaded `.exe`, then launch with Steam running if the game needs it.

## Patch Track

The current patch investigation should focus on the failure area proven by the probe:

1. Winsock behavior visible in Steam logs, especially `getsockname failed in BGetBoundAddr with error: 10022`.
2. Missing or stubbed Winsock IOCTL behavior such as `SIO_IDEAL_SEND_BACKLOG_QUERY` and address sorting.
3. Steam's staged depot file replacement path: file locks, rename/replace behavior, and final manifest commit.
4. Regression tests that run the same AppID install to `GAMECORE-1` and report manifest/depot state before any manual cleanup.

The practical goal is to make the Steam GUI install reliable. Until that is proven, SteamCMD is the safer downloader fallback for games that fail at the final SteamPipe unpack stage.
