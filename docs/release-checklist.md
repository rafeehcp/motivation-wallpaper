# Release validation

The public release supports Wikimedia Commons CC0 photos and original generated backgrounds. No other stock-photo API integration is included.

## Verified locally

- Windows PowerShell 5.1 parsing and offline test suites.
- Quote quality thresholds, batched screening, persistent cache, and theme isolation.
- Readable rendering across landscape, portrait, and scaled-display dimensions.
- Desktop failure preservation across three connected monitors: missing credentials, unavailable quote source, and rejected quotes leave wallpapers and history unchanged.
- Mocked quote-refresh recovery and preview generation.
- Isolated installation, repeated setup, uninstall, ownership checks, unrelated-file preservation, and Task Scheduler folder scoping.
- Actual launcher execution with spaces and non-ASCII path characters, closing automatically on success.
- Commons license checks, source restrictions, caching, recent-photo exclusion, and generated fallback on unavailable photos or service failure.
- Live Commons metadata lookup, CC0 download, quote-overlay rendering, and visual review.
- No credentials, personal wallpaper data, downloaded photos, or private correspondence included in the public source snapshot.

## Remaining validation

Rollback on a partial real wallpaper-application failure still requires further interactive testing. The stale-monitor regression depends on affected Windows desktop state and is not reproduced by hosted CI.

## v0.1.1 fresh-profile validation (2026-10-01)

Testing started with the published v0.1.0 archive under Windows PowerShell 5.1 in a separate standard Windows account. It exposed an unavailable legacy monitor returning `E_FAIL` during rectangle enumeration. The monitor fix was applied to that isolated installation and the remaining walkthrough completed successfully.

- Cancelled and empty API-key entry leave no installation; valid entry installs successfully without elevation.
- The task belongs to the test user, runs with limited privileges, and has daily 09:00 and sign-in triggers.
- Offline and live previews complete without changing wallpapers.
- Two actual desktop-launcher runs use different quotes and backgrounds; all three screens pass visual readability checks, and the launcher closes on success.
- Restore returns to the previous wallpapers and fit.
- Actual scheduled execution succeeds; a second automatic run on the same day preserves history.
- Repeated setup retains a single task; actual sign-out and sign-in execute the catch-up update.
- Original wallpapers are restored before uninstall; uninstall removes managed files, launcher, and task while retaining data and the key.
- All four offline suites pass after the monitor fix; the affected desktop also passes a three-screen offline preview without changing wallpaper paths or fit.

Sanitized findings are recorded here; private profile paths, credentials, and raw test reports are not included in the repository.

## Release procedure

Publish only the reviewed Commons/generated source snapshot. Keep earlier development history and private correspondence local. Run Windows CI before tagging a release, then publish a source-only release using GitHub's generated archives.
