# Storage Clearer broadcast plan

Status: Wave 2 active

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
- [x] Add accurate `WebSite`, `Organization`, and `SoftwareApplication` structured data.
- [x] Improve the GitHub README with a direct download and product screenshot.
- [x] Add repository description, homepage, topics, and social preview.
- [x] Verify the domain in Google Search Console and submit `/sitemap.xml`.

### Wave 1 — technical soft launch

Publish one channel at a time. Do not paste the same post everywhere on the same day.

1. [x] GitHub repository and release surfaces.
2. [x] Personal LinkedIn post published by Khiem Nguyen on 27 August 2026 with the 12-second scan GIF, accessibility text, unsigned-preview disclosure, and the LinkedIn UTM URL.
3. [x] One relevant community whose self-promotion rules permit the post: [r/coolgithubprojects](https://www.reddit.com/r/coolgithubprojects/comments/1vzyjd7/macos_storage_audit_storage_clearer_reviews/).
4. [x] Publish the owned technical article [Why Docker and Xcode Make macOS System Data Grow](https://clear.knasoftware.com/guides/docker-xcode-system-data). Cross-post to DEV or Hashnode remains pending account access.
5. [~] Show HN deferred. It is an optional amplifier for a later signed/notarized release, not a Wave 1 requirement.

Wave 1 completed on 27 August 2026 through GitHub, LinkedIn, Reddit, and the owned technical guide. Wave 3 remains intentionally gated on Developer ID signing and Apple notarization.

### Wave 2 — feedback and proof (14 days)

Objective: turn Wave 1 attention into verified product evidence, one feedback-led release, and reusable material for the signed launch.

#### Autonomous operating mode

Wave 2 is designed to run without routine user intervention. The daily operator owns monitoring, factual public replies, feedback triage, issue creation, low-risk fixes, verified preview patch releases, owned-site updates, and the final closeout. The weekly control loop reviews channel quality and may implement one evidence-supported improvement in an isolated worktree.

Autonomous changes are limited to documentation, the website, tests, accessibility, SEO, and presentation-only SwiftUI code. The operators must not modify cleanup commands, target paths, allowlists, exclusions, approval phrases, revalidation, payment addresses, signing credentials, or any other destructive or trust-critical boundary. Feedback in a protected area is diagnosed and tracked as an issue, but not changed or released automatically.

The operators make no post, reply, patch, or release when evidence does not justify one. Missing platform access is recorded and skipped without pausing the rest of the wave or requesting routine user intervention.

#### Days 1–3 — capture the baseline

- [ ] Record landing visits, direct ZIP downloads, GitHub referrers/stars, search impressions, comments, and reported problems.
- [ ] Confirm that the landing page, ZIP asset, checksum, source link, and first-launch instructions still work.
- [ ] Reply to every substantive question within 24 hours.
- [ ] When investigating feedback, ask for macOS version, Mac architecture, Docker/Xcode presence, scan duration, and the unexpected audit result. Never request private file names or personal data.
- [ ] Create one GitHub issue per reproducible problem or meaningful product request and label its origin.

#### Days 4–7 — ship proof of responsiveness

- [ ] Select the highest-impact reproducible issue from real user feedback.
- [ ] Implement and verify one focused preview patch; do not expand cleanup scope merely to create release activity.
- [ ] Publish a versioned GitHub pre-release with checksum and a concise changelog that credits the feedback without exposing the user.
- [ ] Update the landing-page version, size, checksum, and direct-download link if the artifact changes.

#### Days 8–10 — collect credible proof

- [ ] Follow up with users who reported a successful audit or cleanup and ask for an optional public quote.
- [ ] Capture the user's environment and outcome alongside each approved quote so the claim remains attributable and specific.
- [ ] Publish no claim that cannot be verified from a public comment, issue, or explicit permission.
- [ ] Target at least three actionable feedback items and one reusable quote during this wave; absence of a quote is not a blocker.

#### Days 11–14 — redistribute the evidence

- [ ] Publish one LinkedIn follow-up centered on what changed from user feedback, not a repeat of the launch post.
- [ ] Add a concise update comment to the existing Reddit thread only when there is a material release or finding; do not create a duplicate promotional post.
- [ ] Turn the most useful technical finding into one short update for the owned guide or README.
- [ ] Review channel quality and conversion data, then decide whether to continue the preview, prioritize signing/notarization, or pause acquisition to improve the product.

#### Wave 2 exit criteria

- At least one feedback-led preview patch has been released, or the collected evidence clearly shows that no patch is justified.
- All substantive public feedback has a response or a tracked issue.
- Download and referral baselines are recorded for comparison with the signed launch.
- The top three friction points and the next product priority are documented.
- Any testimonial used publicly has explicit permission and an attributable source.

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
| Owned article | `https://clear.knasoftware.com/?utm_source=owned_article&utm_medium=article&utm_campaign=preview_1` |

## Reputation rules

- Lead with the storage problem and technical design, not the tip links.
- Never ask for votes, stars, or positive reviews in exchange for anything.
- Disclose that the publisher is the maker.
- Check each community's self-promotion rules on the day of posting.
- Prefer a useful technical explanation over a promotional cross-post.
- Do not invent ratings, download counts, testimonials, or cleanup savings.

## Active scheduled tasks

1. **Autonomous Storage Clearer Wave 2** — 09:00 Asia/Ho_Chi_Minh, daily for 14 runs. Operates the full evidence-to-feedback loop, performs safe actions, persists state in `docs/campaign/WAVE2_STATE.md`, and produces the Wave 2 closeout on run 14.
2. **Autonomous Wave 2 Growth Review** — 09:00 Asia/Ho_Chi_Minh on the next two Mondays. Runs in an isolated worktree, compares KPIs, and may implement, verify, merge, and deploy one evidence-supported low-risk improvement per run.
