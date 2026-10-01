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
