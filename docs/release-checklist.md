# v0.1.0 release validation

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

Fresh-user credential dialogs and actual Task Scheduler registration are not covered by the isolated installer tests. Hosted Windows CI results are available on the repository's Actions page after publication. Sign-in catch-up and rollback on a partial real wallpaper-application failure require further interactive testing.

## Release procedure

Publish only the reviewed Commons/generated source snapshot. Keep earlier development history and private correspondence local. Run Windows CI before tagging v0.1.0, then publish a source-only release using GitHub's generated archives.
