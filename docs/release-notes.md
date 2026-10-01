# v0.1.0

First public release of Motivation Wallpaper, a Windows PowerShell 5.1 tool.

- Jev-screened online quotes with persistent assessments and repeat prevention.
- Practical, ambitious, and reflective themes with readable per-monitor typography.
- Reviewed Wikimedia Commons CC0 photos, with original generated backgrounds as fallback.
- Guided API-key setup, desktop launcher, optional daily schedule, restore, and uninstall.
- Windows CI with offline quote, rendering, provider, and installer checks.

Live quotes require the user's own TypeSafe/Jev key. No image API key is needed. Photos and quote collections are fetched at runtime and are not bundled.

Known limits: the photo catalog is small, so generated backgrounds will be common; storage is not automatically pruned; fresh-user credential dialogs and actual schedule registration need broader validation. PowerShell 7 is not supported.
