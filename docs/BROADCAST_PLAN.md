# Storage Clearer broadcast plan

Status: active

Campaign: `preview_1`

Canonical URL: <https://clear.knasoftware.com>

Audience: macOS developers using Docker, Xcode, Simulator runtimes, and rebuildable package caches.

## Goal

Build qualified awareness and technical trust, then turn that attention into direct downloads, source reviews, actionable feedback, and repeatable referrals.

Primary conversion: direct ZIP download.

Secondary conversion: GitHub repository visit or star.

Trust conversion: a reproducible issue, useful comment, or attributable user quote.

## Positioning

**Storage Clearer shows what is using your Mac's space and removes only developer clutter that is safe to rebuild.**

Every public message should prove the same four claims:

- The audit is read-only.
- Nothing is deleted automatically.
- Cleanup requires an exact approval phrase.
- Processing and command logs stay local.

The current build must always be described as an unsigned Apple silicon preview for macOS 13 or later. Do not hide the Control-click → Open first-launch step.

## Launch sequence

### Foundation — 27 August 2026

- [x] Confirm HTTPS on `clear.knasoftware.com`.
- [x] Confirm the direct ZIP returns a downloadable release asset.
- [x] Publish canonical, Open Graph, Twitter Card, sitemap, and robots metadata.
- [ ] Add accurate `WebSite`, `Organization`, and `SoftwareApplication` structured data.
- [ ] Improve the GitHub README with a direct download and product screenshot.
- [ ] Add repository description, homepage, topics, and social preview.
- [ ] Verify the domain in Google Search Console and submit `/sitemap.xml`.

### Wave 1 — technical soft launch

Publish one channel at a time. Do not paste the same post everywhere on the same day.

1. GitHub repository and release surfaces.
2. Personal LinkedIn or X post using the 12-second scan GIF.
3. One relevant community whose self-promotion rules permit the post.
4. A technical article explaining why Docker and Xcode inflate macOS System Data.
5. Show HN only from an established personal account and only with text written by the maker in their own voice.

### Wave 2 — feedback and proof

- Reply to every substantive question within 24 hours.
- Ask for the macOS version, Mac architecture, Docker/Xcode presence, and unexpected audit result when investigating feedback.
- Ship a preview patch from real feedback and publish a concise changelog.
- Request a public quote only after a user reports a successful audit or cleanup.

### Wave 3 — broad launch

Prepare a Product Hunt draft now, but schedule the public launch after Developer ID signing and notarization. Reuse verified product screenshots and the short demo; do not relaunch the unsigned preview as if it were a final release.

## Measurement

Thirty-day targets are hypotheses, not promises:

| Metric | Target |
| --- | ---: |
| Qualified landing visits | 1,000–1,500 |
| Landing-to-download rate | 8–12% |
| Release downloads | 100–150 |
| GitHub stars | 40–60 |
| Actionable feedback items | 10 |
| Reusable public quotes | 3 |

Use Search Console for search impressions and clicks, GitHub Insights for repository referrers, and GitHub release asset counts for downloads. Review GitHub traffic at least weekly because the detailed traffic window is limited.

## UTM taxonomy

Use lowercase values and preserve `utm_campaign=preview_1` throughout this launch:

| Channel | Campaign URL |
| --- | --- |
| GitHub | `https://clear.knasoftware.com/?utm_source=github&utm_medium=repository&utm_campaign=preview_1` |
| LinkedIn | `https://clear.knasoftware.com/?utm_source=linkedin&utm_medium=social&utm_campaign=preview_1` |
| X | `https://clear.knasoftware.com/?utm_source=x&utm_medium=social&utm_campaign=preview_1` |
| Reddit | `https://clear.knasoftware.com/?utm_source=reddit&utm_medium=community&utm_campaign=preview_1` |
| Hacker News | `https://clear.knasoftware.com/?utm_source=hackernews&utm_medium=community&utm_campaign=preview_1` |
| DEV | `https://clear.knasoftware.com/?utm_source=devto&utm_medium=article&utm_campaign=preview_1` |
| Product Hunt | `https://clear.knasoftware.com/?utm_source=producthunt&utm_medium=launch&utm_campaign=preview_1` |

## Reputation rules

- Lead with the storage problem and technical design, not the tip links.
- Never ask for votes, stars, or positive reviews in exchange for anything.
- Disclose that the publisher is the maker.
- Check each community's self-promotion rules on the day of posting.
- Prefer a useful technical explanation over a promotional cross-post.
- Do not invent ratings, download counts, testimonials, or cleanup savings.

## Scheduled tasks to create after campaign setup

Do not create these until channel copy, UTM links, and measurement surfaces are confirmed:

1. **Daily Campaign Check** — 09:00 Asia/Ho_Chi_Minh, daily for 14 days. Check landing/download health, summarize campaign signals, draft the next channel action, and flag unanswered feedback. It must not auto-post.
2. **Weekly Growth Review** — 09:00 Asia/Ho_Chi_Minh every Monday. Compare KPIs, identify the highest-quality referrers, diagnose conversion gaps, and recommend the next experiment.
