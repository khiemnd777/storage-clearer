# Storage Clearer launch plan

## Distribution decision

The current launch will use a **direct download through GitHub Releases** and will not target the Mac App Store. When Apple signing credentials are available, the preferred trust upgrade remains Developer ID signing and notarization. Host the immutable binary and its SHA-256 checksum in GitHub Releases, and link to it from the Firebase landing page.

This is the best fit for the current product because Storage Clearer performs local cleanup outside the boundaries of the Mac App Store sandbox. A future Mac App Store edition should be a deliberately limited, sandbox-compatible audit experience rather than a compromised version of the current cleanup workflow.

### Release gate

- [ ] Active Apple Developer Program membership.
- [ ] `Developer ID Application` certificate installed in Keychain.
- [ ] Notary credentials saved with `xcrun notarytool store-credentials`.
- [ ] Version and build number updated in `App/Info.plist`.
- [ ] Full automated test suite passes.
- [ ] Signed app passes `codesign`, `spctl`, notarization, and stapling checks.
- [ ] ZIP and SHA-256 checksum uploaded to one GitHub Release.
- [ ] Download URL, version, and checksum added to `website/config.js`.
- [ ] Landing page redeployed to Firebase Hosting.

Build the public artifact with:

```bash
SC_DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
SC_NOTARY_PROFILE="storage-clearer-notary" \
./scripts/release_app.sh
```

## Hosting decision

Firebase Hosting serves the small static landing page over its CDN with managed TLS. The site intentionally ships without analytics, advertising scripts, accounts, or a runtime backend. Product screenshots and the 12-second GIF are aggressively optimized and cached.

Production URL: <https://clear.knasoftware.com>

Deploy after editing content or release configuration:

```bash
firebase deploy --only hosting --project storage-clearer-kna
```

## Support payments

Use provider-hosted payment pages. Do not collect payment or wallet information in this static site.

- PayPal: create a PayPal.Me URL or hosted Donate button and assign the HTTPS URL to `paypalUrl` in `website/config.js`.
- Crypto: create a Coinbase Business payment link (preferred for a clear checkout and records) and assign it to `cryptoUrl`.
- Keep both buttons disabled until their destinations have been verified in the owner's signed-in provider accounts.

## Launch sequence

### Phase 1 — trust foundation

1. Publish the product site and public source code.
2. Add a privacy page and plain-language safety model.
3. Publish a signed, notarized release and checksum.
4. Test a clean install on a separate Apple silicon Mac account.

### Phase 2 — launch week

1. Publish the release and a GitHub discussion explaining the four safety gates.
2. Share the accelerated scan clip with one promise: “See what is safe to rebuild before you delete anything.”
3. Post product screenshots and the landing URL to relevant macOS, Docker, Xcode, and indie developer communities while following each community's self-promotion rules.
4. Ask early users for reproducible audit gaps and false-positive reports, not generic testimonials.

### Phase 3 — reputation loop

1. Publish changelogs for every release.
2. Keep older notarized releases and checksums available.
3. Respond to safety reports before adding new cleanup categories.
4. Consider a custom domain after validating demand; keep Firebase as the CDN origin.

## Launch copy

**Short post**

> Your Mac can call Docker layers, Simulator leftovers, developer caches, and snapshots all “System Data.” Storage Clearer separates rebuildable clutter from protected data, shows a reviewed cleanup plan, and requires an exact approval phrase before it acts. See the 12-second scan: https://clear.knasoftware.com

**One-line description**

> A safety-first storage audit and cleanup companion for macOS developer workspaces.

## Broadcast campaign

The active campaign plan, channel order, success metrics, UTM taxonomy, and scheduled follow-up tasks are maintained in [BROADCAST_PLAN.md](BROADCAST_PLAN.md). Ready-to-adapt channel copy is maintained separately in [BROADCAST_KIT.md](BROADCAST_KIT.md).
