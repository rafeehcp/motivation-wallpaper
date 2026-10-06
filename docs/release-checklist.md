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

## v0.1.2 update validation

- All 37 catalog entries checked against live Commons metadata for CC0 license, author, revision, dimensions, and restrictions; new thumbnail compositions reviewed. All entries pass runtime eligibility at 1920 by 1920 pixels. Photos are fetched at runtime and are not bundled.
- Metadata cache invalidation verified after a catalog change, without redownloading an existing valid photo.
- Conservative cleanup fixtures cover age/count retention, current and restore files, edited run files, source dependencies, unrelated files, malformed metadata, junctions, and failed removal.
- Preference fixtures cover default visibility, saved Boolean toggles, preserving unrelated settings, invalid metadata, and command-line configuration.
- Actual three-screen fixture previews show that toggling credits changes only the footer; quote layout and HTML attribution remain intact. The configuration dialog's controls and Cancel behavior were checked without requiring credentials or applying wallpapers.
- Installer, launcher settings routing, and uninstall include the new modules; wallpaper data and settings remain after uninstall.

## Release procedure

Publish only the reviewed Commons/generated source snapshot. Keep earlier development history and private correspondence local. Run Windows CI before tagging a release, then publish a source-only release using GitHub's generated archives.


## v0.1.3 validation

- All eight offline Windows PowerShell 5.1 suites passed, including screening-mode and release-bootstrap coverage.
- Basic preview rendered on all three active monitors with Jev credential access and evaluation mocked to fail if called. Saved Jev selection and one-run overrides were verified; desktop paths remained unchanged.
- The personal installation rendered a Basic preview using cached real quotes and a photo without Jev access.
- The complete release ZIP installed all 12 payload files into an isolated standard-user fixture without a key prompt or elevation. Installed file hashes matched the release sources; desktop launcher was scoped to the fixture and scheduling disabled.
- Bootstrap rejects checksum mismatches and missing setup scripts, forwards supported options, propagates failures, and cleans its own temporary extraction.
- The published download and latest-release command must be verified after release publication.

## v0.1.4 validation

- All eight offline Windows PowerShell 5.1 suites passed locally, including new settings-window, launcher, icon, swap, background-setting, and next-photo coverage.
- The `irm | iex` failure was reproduced against the v0.1.3 installer text and passes after the fix.
- The release ZIP passed through the real bootstrap with a local download: checksum verified, all 12 payload files installed with matching hashes into an isolated fixture, the launcher and icon were generated, and both shortcuts were created in fixture folders without a key prompt or schedule.
- Upgrading the personal v0.1.3 installation re-registered the task without `-BackgroundSource`, created both shortcuts, and removed its `Change Wallpaper.cmd`.
- The settings launcher opens no console window; `powershell.exe -WindowStyle Hidden` creates one, which caused the earlier flash.
- The opened settings window was rendered off-screen with real wallpaper data; button and segment label colors were measured for contrast.
- The icon decodes at every size in System.Drawing and WPF, and appears on the launcher, shortcuts, and window.
- Live Commons next-photo download in a temporary folder: 1920 thumbnail for landscape-only coverage, 3840 when a portrait monitor needs the height, no partial files, and the next update used the saved photo without downloading.

Windows CI passed all eight suites on the release branch, whose runner uses an 8.3 short TEMP path. Remaining: clicking New wallpaper and Swap with previous on a real desktop. The published download and latest-release command must be verified after release publication.

## v0.1.5 validation

- All eight offline Windows PowerShell 5.1 suites passed locally, including new update-check coverage: version comparison, the update console command run in a child process with an apostrophe and space in the install path, `-NoSchedule` passed through, Wallpaper Settings reopened afterwards, and the button click starting that console without a network request when the window is built.
- A live GitHub request from an installation recorded as 0.0.1 showed **Update to v0.1.4**. Without `installation.json`, no request was made.
- While the window was open, every installed file could be opened for exclusive write, so setup can replace them during an update.
- The release ZIP, built from the release commit's 12 payload files, passed through the real bootstrap with a local download: checksum verified, files installed with matching hashes into an isolated fixture, launcher and icon generated, both shortcuts created in fixture folders, and `installation.json` recorded 0.1.5 without a schedule.

Remaining: clicking **Update** against a published release newer than the installation, and the offline and rate-limited paths, which leave the button hidden by code review only. The published download and latest-release command must be verified after release publication.
