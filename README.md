# Motivation Wallpaper

Readable motivational quotes on your Windows desktop, screened by Jev and rendered for each monitor. Themes rotate between practical, ambitious, and reflective, each with its own typography. The last 30 quotes and background photos are excluded from successful updates. Backgrounds use a reviewed Commons photo collection with original generated artwork as a fallback.

An MIT-licensed PowerShell tool for Windows 10/11. The code license does not license third-party photos or quotes; the photo collection is restricted to reviewed CC0 images.

## Requirements

- Windows 10 or 11 with an interactive desktop session.
- Windows PowerShell 5.1 (`powershell.exe`). PowerShell 7 is not currently supported or tested.
- Internet access and your own [TypeSafe/Jev](https://typesafe.ai/) key for live quote screening. Commons and generated backgrounds need no image API key. Provider quotas, pricing, and terms apply.
- No Python, external editor, or additional PowerShell modules.

## Install

Download the source ZIP from [Releases](https://github.com/rafeehcp/motivation-wallpaper/releases), extract it, and open Windows PowerShell in the extracted folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SetupMotivationWallpaper.ps1
```

Setup requests a missing `TYPESAFE_API_KEY` through a masked dialog. It is saved in your Windows user environment; this is **not an encrypted credential vault**. An existing user key is reused. Do not put keys in issues, screenshots, logs, or source files.

Setup installs into `%LOCALAPPDATA%\MotivationWallpaper`, creates **Change Wallpaper.cmd** on your desktop, and registers a task for 09:00 local time plus sign-in catch-up. Automatic runs update once per calendar day; manual changes can run any time. Setup does not change your current wallpaper.

Use `-NoSchedule` for manual-only installation. On repeated setup, this option retains any existing managed schedule. Use `-CredentialsOnly` to configure missing keys without installing files. `-InstallDirectory` selects another directory, but only one managed desktop launcher and scheduled task are supported per user.

Setup accepts `-BackgroundSource Commons` (default) or `Generated`; it writes this choice into the desktop launcher and scheduled task. Direct main-script runs use Commons unless you pass the option explicitly. With `-NoSchedule`, any existing task keeps its previous source choice.

Setup refuses an existing directory or launcher belonging to another installation. Older personal versions are not automatically migrated. Preserve their data and remove or relocate their launcher before installing this release. If task registration is denied by your Windows policy, use `-NoSchedule` or contact your administrator; do not run the wallpaper task as administrator.

## Use

Double-click **Change Wallpaper.cmd**. The window closes on success and stays open on failure.

```powershell
$app = Join-Path $env:LOCALAPPDATA 'MotivationWallpaper'
& "$app\SetMotivationWallpaper.ps1"                       # Change wallpaper
& "$app\SetMotivationWallpaper.ps1" -PreviewOnly          # Live preview, uses APIs
& "$app\SetMotivationWallpaper.ps1" -PreviewOnly -Demo    # Offline layout preview
& "$app\SetMotivationWallpaper.ps1" -BackgroundSource Generated # Live screened quote, offline background
& "$app\RestoreMotivationWallpaper.ps1"                  # Restore previous wallpapers
& "$app\UninstallMotivationWallpaper.ps1"                # Remove installation and schedule
```

Previews print the output folder; open its `preview.html`. Demo text is a synthetic layout example, not Jev approved. Uninstall retains downloaded images, history, API keys, and the current wallpaper. Restore before uninstall if desired. For a custom installation, pass the same `-InstallDirectory` to uninstall.

## How it works

Quotes come from ZenQuotes, with DummyJSON as an additional collection when needed. Jev scores clarity, constructive motivation, and theme fit. Every dimension requires a score of at least 3 on the API's 0-4 scale and at least 80% combined probability on its two highest levels. This is model judgment; quote accuracy and author attribution are not independently verified.

Quotes are evaluated in batches of ten. Approved unused quotes are reused from the assessment cache before requesting new evaluations. The model is pinned to `jev-1.13.0`; model or rubric changes must also change the assessment cache version.

Commons backgrounds come from five manually reviewed CC0 nature photos. Runtime metadata must still identify the image as CC0 and provide its CC0 deed URL; other licenses and unreviewed files are excluded. Metadata is cached for 24 hours, and downloads are sized to support connected screens. Source and license links appear in previews, with photographer credits on the rendered wallpaper. Review records are in [commons-backgrounds.json](commons-backgrounds.json).

The small collection will exhaust under the last-30 rule. If all suitable photos were used recently, metadata is incomplete, or Commons fails, the tool generates a fresh background locally. Each Commons request has one attempt with a 10-second timeout. Generated backgrounds use theme-based gradients, soft light, and subtle landscape shapes, with no image API calls. `-BackgroundSource Generated` bypasses Commons entirely; live quote screening still uses Jev.

The same quote and background appear on every monitor, cropped and typeset at each monitor's native resolution. Segoe UI, Bahnschrift, and Georgia are selected by theme with a Segoe UI fallback. Dark overlays, minimum font sizes, and left-side icon space support readability.

Service failures or exhausted quality checks preserve the current wallpaper. Applying wallpapers uses rollback on failure. Concurrent runs are excluded with a file lock.

## Data and privacy

Data lives in `%USERPROFILE%\Pictures\MotivationalWallpapers`: quote and assessment caches, `commons-metadata.json`, the last 30 successful quote/background IDs, original backgrounds, rendered images, previous wallpaper paths, and `wallpaper.log`. `-DataDirectory` overrides the main script's directory; restore currently uses the default directory.

Quote text and the evaluation rubric are sent to TypeSafe. Commons receives file metadata requests and image downloads when selected. Generated backgrounds require no image service. There is no project telemetry. Preview metadata contains local monitor identifiers and paths; share only reviewed output. Files are retained to keep active and restore wallpaper paths valid. There is no automatic storage cleanup.

## Troubleshooting

- **Missing key:** run setup with `-CredentialsOnly`. To replace a saved key, remove that user environment variable in Windows settings, then rerun setup.
- **No quote passed quality checks:** the wallpaper is preserved. Check the log; try later when quote caches refresh. Do not lower the quality threshold to hide a provider failure.
- **Slow update:** first runs may need several evaluation batches. Subsequent runs use cached evaluations, but network speed and provider limits still matter.
- **Already updated today:** automatic runs skip after a successful update. Use the desktop launcher for another manual change.
- **Restore unavailable:** a previous state is recorded only when an update is applied. Missing original image files cannot be restored.
- **Fonts or portrait layout:** render tests cover landscape, portrait, and scaled-display dimensions. Font appearance can vary across Windows versions.

## Development

```powershell
.\TestMotivationWallpaper.ps1
.\TestWallpaperBatch.ps1
.\TestBackgroundProviders.ps1
.\TestInstallation.ps1
# Interactive desktop only; mocked APIs, no credentials needed:
.\TestMotivationWallpaper.ps1 -DesktopIntegration
.\TestWallpaperRefresh.ps1
```

CI runs offline tests in Windows PowerShell 5.1. Interactive COM and Task Scheduler behavior requires a local desktop check; hosted CI does not prove those behaviors. See [CONTRIBUTING.md](CONTRIBUTING.md) and [the release checklist](docs/release-checklist.md).

## Credits and license

Inspirational quotes provided by [ZenQuotes API](https://zenquotes.io/), with additional quotes from [DummyJSON](https://dummyjson.com/docs/quotes). Photos come from [Wikimedia Commons](https://commons.wikimedia.org/). Photo credits and source/CC0 links accompany Commons previews. Evaluation uses [TypeSafe/Jev](https://typesafe.ai/).

Code: [MIT](LICENSE), copyright 2026 rafeehcp. No third-party photos, downloaded quote collections, API credentials, or fonts are bundled.

This first release has been tested locally with Windows PowerShell 5.1 and three monitors. Installer behavior is tested in isolated folders with mocked credential and scheduler operations. Fresh-user credential dialogs and actual schedule registration still need broader community validation.
