# Motivation Wallpaper

Readable motivational quotes on your Windows desktop, checked locally by default, optionally screened by Jev, and rendered for each monitor. Themes rotate between practical, ambitious, and reflective, each with its own typography. The last 30 quotes and background photos are excluded from successful updates. Backgrounds use a reviewed Commons photo collection with original generated artwork as a fallback.

An MIT-licensed PowerShell tool for Windows 10/11. The code license does not license third-party photos or quotes; the photo collection is restricted to reviewed CC0 images.

## Requirements

- Windows 10 or 11 with an interactive desktop session.
- Windows PowerShell 5.1 (`powershell.exe`). PowerShell 7 is not currently supported or tested.
- Internet access for new online quotes and photos. A [TypeSafe/Jev](https://typesafe.ai/) key is required only if you enable Jev screening. Commons and generated backgrounds need no image API key. Provider quotas, pricing, and terms apply.
- No Python, external editor, or additional PowerShell modules.

## Install

Open **Windows PowerShell** as your normal user and paste this command:

```powershell
irm https://github.com/rafeehcp/motivation-wallpaper/releases/latest/download/Install.ps1 | iex
```

It downloads the installer from the latest published release, verifies that release's ZIP against its embedded SHA-256 checksum, and runs setup. No administrator access or API key is required for the default Basic mode. Review [the installer source](https://github.com/rafeehcp/motivation-wallpaper/blob/main/Install.ps1) before running it if you prefer. The temporary download is removed after setup; existing unmanaged installations are preserved and rejected by setup.

For manual-only installation, use:

```powershell
& ([scriptblock]::Create((irm https://github.com/rafeehcp/motivation-wallpaper/releases/latest/download/Install.ps1))) -NoSchedule
```

The downloaded installer also accepts `-InstallDirectory`, `-BackgroundSource Commons|Generated`, and `-QuoteScreening Basic|Jev`. Selecting Jev requests a missing key. Without a screening option, existing preferences are preserved and new installations use Basic.

Alternatively, download the ZIP from [Releases](https://github.com/rafeehcp/motivation-wallpaper/releases), extract it, and open Windows PowerShell in the extracted folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SetupMotivationWallpaper.ps1
```

Basic mode is the default and setup does not request an API key. With `-QuoteScreening Jev`, setup requests a missing `TYPESAFE_API_KEY` through a masked dialog. It is saved in your Windows user environment; this is **not an encrypted credential vault**. An existing user key is reused. Do not put keys in issues, screenshots, logs, or source files.

Setup installs into `%LOCALAPPDATA%\MotivationWallpaper`, creates a **Wallpaper Settings** shortcut on your desktop, adds **Motivation Wallpaper Settings** to the Start menu, and registers a task for 09:00 local time plus sign-in catch-up. Automatic runs update once per calendar day; manual changes can run any time. Setup does not change your current wallpaper.

Use `-QuoteScreening Basic` or `-QuoteScreening Jev` to choose and save a mode during setup. Without that option, setup preserves the saved selection, defaulting to Basic. Use `-NoSchedule` for manual-only installation. On repeated setup, this option retains any existing managed schedule. Use `-CredentialsOnly` to configure missing keys without installing files. `-InstallDirectory` selects another directory, but only one managed set of settings shortcuts and one scheduled task are supported per user.

Setup accepts `-BackgroundSource Commons` or `Generated` and saves it as the background setting. Without that option, setup keeps the saved setting, which defaults to Commons. Installations from v0.1.3 or earlier pass `-BackgroundSource Commons` in their scheduled task, which overrides the setting; rerun the installer to replace that task.

Setup refuses an existing directory or settings shortcut belonging to another installation. Upgrading from v0.1.3 or earlier removes that release's **Change Wallpaper.cmd** from the desktop; Wallpaper Settings replaces it. Older personal versions are not automatically migrated. Preserve their data and move their install folder before installing this release. If task registration is denied by your Windows policy, use `-NoSchedule` or contact your administrator; do not run the wallpaper task as administrator.

## Use

Open **Wallpaper Settings** and click **New wallpaper**. The update runs in the background; the window shows the new wallpaper when it finishes, or the error message if it fails.

```powershell
$app = Join-Path $env:LOCALAPPDATA 'MotivationWallpaper'
& "$app\SetMotivationWallpaper.ps1"                       # Change wallpaper
& "$app\SetMotivationWallpaper.ps1" -PreviewOnly          # Live preview, uses APIs
& "$app\SetMotivationWallpaper.ps1" -PreviewOnly -Demo    # Offline layout preview
& "$app\SetMotivationWallpaper.ps1" -BackgroundSource Generated # One run with an offline background
& "$app\ConfigureMotivationWallpaper.ps1"                # Open Wallpaper Settings
& "$app\RestoreMotivationWallpaper.ps1"                  # Swap with previous wallpapers
& "$app\UninstallMotivationWallpaper.ps1"                # Remove installation and schedule
```

Previews print the output folder; open its `preview.html`. Demo text is a synthetic layout example, not Jev approved. Uninstall retains downloaded images, history, API keys, and the current wallpaper. Restore before uninstall if desired. For a custom installation, pass the same `-InstallDirectory` to uninstall.

## Wallpaper settings

Open **Wallpaper Settings** from the desktop or the Start menu. It has three saved settings:

- **Show source credits on wallpapers.** On by default.
- **Background.** Wikimedia Commons photos (default) or generated artwork, which needs no network.
- **Quote screening.** Basic checks (default) or Jev screening. Choosing Jev without a saved key asks for one; cancelling leaves every setting unchanged.

Each choice saves as soon as you make it and applies to future wallpapers. The window previews the first monitor's current wallpaper and has **New wallpaper**, **Swap with previous**, and **Open wallpaper folder**. Swapping puts the previous wallpapers back and records the ones it replaced, so swapping again returns to the newer wallpapers.
The same settings can be saved without the window:

```powershell
& "$app\ConfigureMotivationWallpaper.ps1" -HideCredits
& "$app\ConfigureMotivationWallpaper.ps1" -ShowCredits
& "$app\ConfigureMotivationWallpaper.ps1" -BackgroundSource Generated
& "$app\ConfigureMotivationWallpaper.ps1" -QuoteScreening Jev
```

Settings are saved in the wallpaper data folder's `settings.json`. A custom `-DataDirectory` must match the directory used for wallpaper updates. Source and license links remain in HTML previews; the offline demo retains its unscreened-layout label.

## How it works

Quotes come from ZenQuotes, with DummyJSON as an additional collection when needed. **Basic checks** are the default: quote text must be 15 to 230 characters, the author must be 1 to 70 characters, and empty text, control characters, markup, URLs in quote text, and recent repeats are rejected. Theme keywords prioritize candidates; if none match, another valid unused quote is selected. These checks do not judge meaning or verify author attribution.

Choose **Basic checks** or **Jev screening** in Wallpaper Settings. You can also save a choice with `ConfigureMotivationWallpaper.ps1 -QuoteScreening Basic` or `-QuoteScreening Jev`. The main script accepts the same option as a one-run override; manual and scheduled runs otherwise use the saved setting. Changes apply to future wallpapers. Jev keys can be configured later using setup `-CredentialsOnly`.

In Jev mode, Jev scores clarity, constructive motivation, and theme fit. Every dimension requires a score of at least 3 on the API's 0-4 scale and at least 80% combined probability on its two highest levels. This is model judgment; quote accuracy and author attribution are not independently verified.

In Jev mode, quotes are evaluated in batches of ten. Approved unused quotes are reused from the assessment cache before requesting new evaluations. The model is pinned to `jev-1.13.0`; model or rubric changes must also change the assessment cache version.

Commons backgrounds come from 37 manually reviewed CC0 nature photos. Runtime metadata must still identify the image as CC0 and provide its CC0 deed URL; other licenses and unreviewed files are excluded. Metadata is cached for 24 hours, and downloads are sized to support connected screens. Source and license links appear in previews, with photographer credits on the rendered wallpaper. Review records are in [commons-backgrounds.json](commons-backgrounds.json).

The collection avoids the last 30 successful background IDs. If all suitable photos were used recently, metadata is incomplete, or Commons fails, the tool generates a fresh background locally. Each Commons request has one attempt with a 10-second timeout. Generated backgrounds use theme-based gradients, soft light, and subtle landscape shapes, with no image API calls. The Generated background setting, or `-BackgroundSource Generated` for one run, bypasses Commons entirely; Jev is used only when Jev screening is selected.

The same quote and background appear on every monitor, cropped and typeset at each monitor's native resolution. Segoe UI, Bahnschrift, and Georgia are selected by theme with a Segoe UI fallback. Dark overlays, minimum font sizes, and left-side icon space support readability.

Service failures or exhausted quality checks preserve the current wallpaper. Applying wallpapers uses rollback on failure. Concurrent runs are excluded with a file lock.

## Data and privacy

Data lives in `%USERPROFILE%\Pictures\MotivationalWallpapers`: quote and assessment caches, `commons-metadata.json`, the last 30 successful quote/background IDs, original backgrounds, rendered images, previous wallpaper paths, and `wallpaper.log`. `-DataDirectory` overrides the main script's directory; restore currently uses the default directory.

Quote text and the evaluation rubric are sent to TypeSafe. Commons receives file metadata requests and image downloads when selected. Generated backgrounds require no image service. There is no project telemetry. Preview metadata contains local monitor identifiers and paths; share only reviewed output. After a successful update or preview, cleanup removes recognized run folders and unused source images older than 30 days. It always retains the newest 30 runs, current wallpaper files, restore files, and backgrounds needed by retained runs. Unrelated files, caches, settings, and history are preserved; links and unreadable metadata are skipped conservatively.

## Troubleshooting

- **Missing key in Jev mode:** run setup with `-CredentialsOnly`. To replace a saved key, remove that user environment variable in Windows settings, then rerun setup.
- **No quote passed quality checks:** the wallpaper is preserved. Check the log; try later when quote caches refresh. Do not lower the quality threshold to hide a provider failure.
- **Slow update:** first runs may need several evaluation batches. Subsequent runs use cached evaluations, but network speed and provider limits still matter.
- **Already updated today:** automatic runs skip after a successful update. Use **New wallpaper** in Wallpaper Settings for another manual change.
- **Restore unavailable:** a previous state is recorded only when an update is applied. Missing original image files cannot be restored. A failed swap puts the current wallpapers back and keeps the recorded state.
- **Fonts or portrait layout:** render tests cover landscape, portrait, and scaled-display dimensions. Font appearance can vary across Windows versions.

## Development

```powershell
.\TestMotivationWallpaper.ps1
.\TestWallpaperBatch.ps1
.\TestBackgroundProviders.ps1
.\TestInstallation.ps1
.\TestWallpaperStorage.ps1
.\TestWallpaperPreferences.ps1
# Interactive desktop only; mocked APIs, no credentials needed:
.\TestMotivationWallpaper.ps1 -DesktopIntegration
.\TestWallpaperRefresh.ps1
```

CI runs offline tests in Windows PowerShell 5.1. Interactive COM and Task Scheduler behavior requires a local desktop check; hosted CI does not prove those behaviors. See [CONTRIBUTING.md](CONTRIBUTING.md) and [the release checklist](docs/release-checklist.md).

## Credits and license

Inspirational quotes provided by [ZenQuotes API](https://zenquotes.io/), with additional quotes from [DummyJSON](https://dummyjson.com/docs/quotes). Photos come from [Wikimedia Commons](https://commons.wikimedia.org/). Photo credits and source/CC0 links accompany Commons previews. Optional evaluation uses [TypeSafe/Jev](https://typesafe.ai/).

Code: [MIT](LICENSE), copyright 2026 rafeehcp. No third-party photos, downloaded quote collections, API credentials, or fonts are bundled.

Tested locally with Windows PowerShell 5.1 and three monitors, including a fresh standard-user installation, credential dialogs, actual scheduled execution, sign-in catch-up, restore, and uninstall. Broader community validation remains welcome.

Quote screening tests: `./TestQuoteScreening.ps1`; add `-DesktopIntegration` to render previews and verify failure preservation in an interactive Windows session. Basic mode makes no Jev requests. Jev failures preserve the wallpaper and never silently fall back to Basic. Missing or invalid screening preferences default to Basic.

Release bootstrap tests: `./TestReleaseInstaller.ps1` covers verified ZIP extraction, option forwarding, checksum mismatch, download failure, missing setup, and setup failure without network requests or installation changes.
