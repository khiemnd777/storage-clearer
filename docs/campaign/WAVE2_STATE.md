# Storage Clearer Wave 2 state

Campaign: `preview_1`

Status: first weekly growth review completed; daily Wave 2 operator baseline remains pending

Run: 0 of 14

Weekly growth review: 1 of 2

Started: 27 August 2026

Canonical URL: <https://clear.knasoftware.com>

## Baseline

The first daily run establishes the verified baseline. Metrics that cannot be read from an authenticated or public source must remain `N/A`.

| Signal | Baseline | Latest | Source | Last verified |
| --- | ---: | ---: | --- | --- |
| Landing visits | N/A | N/A | GA4/Search Console unavailable to this run | 31 August 2026 |
| Search impressions | N/A | N/A | Search Console unavailable to this run | 31 August 2026 |
| Direct ZIP downloads | 37 | 37 | [GitHub release asset](https://github.com/khiemnd777/storage-clearer/releases/tag/v1.0.0-preview.1) | 31 August 2026 |
| GitHub stars | 5 | 5 | [GitHub repository](https://github.com/khiemnd777/storage-clearer) public API | 31 August 2026 |
| GitHub issues (open) | 0 | 0 | [GitHub issue tracker](https://github.com/khiemnd777/storage-clearer/issues) public API | 31 August 2026 |
| Reddit score | 7 | 7 | [Public launch discussion](https://www.reddit.com/r/coolgithubprojects/comments/1vwrt97/i_built_a_readonlyfirst_macos_storage_triage_cli/) search-indexed result | 31 August 2026 |
| Actionable feedback | 2 | 2 | [Issues #1–#2](https://github.com/khiemnd777/storage-clearer/issues?q=is%3Aissue%20is%3Aclosed) (both addressed before this review) | 31 August 2026 |
| Approved public quotes | 0 | 0 | No explicit permission found in public sources | 31 August 2026 |

## Autonomous activity log

### 31 August 2026 — weekly growth review 1

- Verified landing-page health: `https://clear.knasoftware.com/` and the owned Docker/Xcode guide each returned HTTP 200.
- Verified direct-download health: the product-site configuration, landing-page checksum, and GitHub release all point to the 2,522,576-byte Apple-silicon ZIP with SHA-256 `fd975d9a8951edfec5269a036fd8e552ed09d7d2ef3e35318aec456c819e2e27`; the direct-download URL resolved successfully to that asset.
- Reconciled GitHub signals: 37 ZIP downloads, 5 stars, 0 open issues, no new public issue comments since the preview release. The two earlier actionable reports were closed with fixes before this review.
- Reconciled public discussion: the indexed Reddit launch discussion shows score 7 and a later technical integration conversation. The Wave 1 Reddit URL named in the broadcast plan could not be retrieved directly, so no current score was substituted for it. LinkedIn feedback was not publicly accessible, and Search Console/GA4 plus GitHub traffic/referrers were unavailable to this run; all remain `N/A`.
- No promotional content, direct messages, or user-feedback claims were published.

## Next measurable hypothesis

The highest-impact evidence-supported next step is to prioritize a Developer ID signed and notarized release: the current 37 verified download attempts all encounter the documented unsigned-preview first-launch friction, while the landing page and direct asset are healthy. Measure whether a signed release reduces first-launch support questions and increases completed ZIP downloads against this 37-download baseline.

## Protected work

Developer ID signing and notarization are protected distribution work and were not changed. No existing signing/notarization issue was found. Creating the required evidence-tracking issue was attempted through the configured GitHub connector, but it returned `403 Resource not accessible by integration`; local `gh` authentication is also expired. The diagnosis is therefore recorded here pending repository write access. Cleanup commands, target paths, allowlists, exclusions, approval phrases, revalidation, payment addresses, credentials, and signing/notarization remain outside automatic modification.
