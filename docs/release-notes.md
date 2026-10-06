# v0.1.5

- Wallpaper Settings checks GitHub for a newer release when it opens. If one exists, an **Update to v…** button appears. Clicking it closes the window and runs the installer in a visible console. The update keeps the install folder and any `-NoSchedule` choice, then reopens Wallpaper Settings. On failure the console shows the error and waits. If the check fails, for example when offline, the window shows nothing.
- The window grows by the button's height only while an update is offered.

Installations of v0.1.4 or earlier have no update check. Rerun the installer once to upgrade; later releases are offered in the window.

# v0.1.4

- Fix the one-command install. `irm ... | iex` stopped before downloading because Windows PowerShell rejected the installer's empty `-QuoteScreening` option when the script ran through `iex`. A test now runs the installer text through `Invoke-Expression`.
- Add Wallpaper Settings, a window that previews the current wallpaper and has switches for Photos or Generated backgrounds and Basic or Jev screening, a credits toggle, **New wallpaper**, **Swap with previous**, and **Open wallpaper folder**. Choices save immediately. Choosing Jev without a key asks for one; cancelling keeps Basic.
- Open Wallpaper Settings from the desktop or the Start menu. A small launcher compiled at install time starts it without a console window. New wallpaper and Swap also run without a console and report errors in the window.
- Add an app icon, a quotation mark over hills, drawn at install time for the launcher, shortcuts, and window.
- The background source is now a saved setting. The scheduled task no longer passes `-BackgroundSource`; the option still overrides a single run.
- Swap with previous records the wallpapers it replaces, so swapping again returns to them. A failed swap puts the current wallpapers back.
- Remove `Change Wallpaper.cmd`. Upgrades delete this app's launcher and leave any other file with that name alone.
- After each successful update, download the next unused Commons photo so the following update can use it without waiting. Downloads use a temporary name until complete, and use the 1920-pixel thumbnail when it covers every monitor.

Rerun the installer to upgrade; it replaces the scheduled task and removes `Change Wallpaper.cmd`.

# v0.1.3

- Add a one-command Windows PowerShell installer using a version-pinned release ZIP and embedded SHA-256 verification. No administrator access is required.
- Basic quote checks are now the default; no TypeSafe key is needed in this mode.
- Wallpaper Settings and command-line options can enable Jev screening. Existing screening thresholds remain unchanged.
- Setup requests a TypeSafe key only for Jev mode. Screening choices preserve source-credit settings.
- Preview details record the screening mode. Basic selections are never labeled Jev approved.

# v0.1.2

- Expand the reviewed Wikimedia Commons CC0 nature catalog from 5 to 37 photos. Catalog changes refresh metadata immediately; normal runs continue using the cache.
- Automatically remove recognized wallpaper runs and unused source images older than 30 days, keeping the newest 30 runs, active wallpapers, restore paths, and recently edited files. Unrelated files, caches, and links are preserved.
- Add a saved setting to show or hide source credits on wallpapers. Credits remain visible by default. Run `ConfigureMotivationWallpaper.ps1` or launch `Change Wallpaper.cmd settings` to change the checkbox; HTML previews retain attribution.
- Add storage and preference regression suites to Windows CI. Verified on three screens that hiding credits changes only the footer, without changing the quote layout or preview attribution.

# v0.1.1

- Fix monitor enumeration stopping when Windows retains an unavailable legacy monitor whose rectangle query returns `E_FAIL`. Continue rendering on the working screens; other COM errors still surface.
- Validated under Windows PowerShell 5.1 in a fresh standard-user profile with three screens: cancelled and empty key entry, installation, live and offline previews, two different manual wallpapers, visual readability, restore, daily scheduling, actual sign-in catch-up, repeated setup, and uninstall retaining data and the key.
- All four offline regression suites pass. The stale-monitor failure was reproduced on the affected desktop, then the fixed offline preview rendered on all three screens without changing wallpaper paths or fit.

The small photo catalog and unpruned storage remain limitations. PowerShell 7 is not supported.

# v0.1.0

First public release of Motivation Wallpaper, a Windows PowerShell 5.1 tool.

- Jev-screened online quotes with persistent assessments and repeat prevention.
- Practical, ambitious, and reflective themes with readable per-monitor typography.
- Reviewed Wikimedia Commons CC0 photos, with original generated backgrounds as fallback.
- Guided API-key setup, desktop launcher, optional daily schedule, restore, and uninstall.
- Windows CI with offline quote, rendering, provider, and installer checks.

Live quotes require the user's own TypeSafe/Jev key. No image API key is needed. Photos and quote collections are fetched at runtime and are not bundled.

Known limits: the photo catalog is small, so generated backgrounds will be common; storage is not automatically pruned; fresh-user credential dialogs and actual schedule registration need broader validation. PowerShell 7 is not supported.
