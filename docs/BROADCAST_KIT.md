# Storage Clearer broadcast kit

Campaign URL tokens are defined in [BROADCAST_PLAN.md](BROADCAST_PLAN.md). The copy below now contains its final channel-specific URL.

## Core message

**Storage Clearer — see what is using your Mac's space and remove only developer clutter that is safe to rebuild.**

Required disclosure: Apple silicon preview for macOS 13 or later. The current build is unsigned; first launch requires Control-click → Open.

## LinkedIn

I built Storage Clearer after seeing Docker layers, Xcode Simulator runtimes, and developer caches disappear into macOS “System Data.”

It starts with a read-only audit, separates rebuildable clutter from protected data, and shows the exact cleanup plan before anything runs. Cleanup requires a matching approval phrase, revalidates changing Docker and Simulator targets, and records every command locally.

The source is public, and the Apple silicon preview can be downloaded directly—no account or installer.

https://clear.knasoftware.com/?utm_source=linkedin&utm_medium=social&utm_campaign=preview_1

I would especially value feedback about missing storage categories, confusing risk labels, or audit results that do not match what you expected.

## X

I built Storage Clearer for Macs carrying Docker, Xcode Simulator, and rebuildable cache clutter.

Read-only audit. Exact approval. No background deletion. Local processing and logs.

Open source Apple silicon preview: https://clear.knasoftware.com/?utm_source=x&utm_medium=social&utm_campaign=preview_1

## Reddit/community draft

Title: **I built an open-source macOS storage cleaner that audits first and never auto-deletes**

Body:

I made Storage Clearer for developer Macs where Docker objects, Simulator runtimes, and package caches get grouped into “System Data.”

The scan is read-only. It separates low-risk rebuildable items from protected or manual-review categories, shows the exact plan, and requires a matching approval phrase before cleanup. Docker and Simulator targets are checked again immediately before execution, and commands are logged locally.

The current release is an unsigned Apple silicon preview for macOS 13 or later, so the first launch uses Control-click → Open. Source and direct download: https://clear.knasoftware.com/?utm_source=reddit&utm_medium=community&utm_campaign=preview_1

I am looking for technical feedback, especially false positives, missing cache categories, and confusing explanations. I am the developer of the project.

Before posting, rewrite the opening for the specific community and verify its current self-promotion rules.

## DEV/Hashnode article outline

Title: **Why Docker and Xcode Make macOS System Data Grow — and What Is Actually Safe to Rebuild**

1. Why macOS storage categories are not actionable explanations.
2. Docker build cache, unused images, stopped containers, and the special risk of volumes.
3. Simulator devices versus installed runtimes.
4. Rebuildable package/tool caches versus source projects and personal data.
5. Why an audit, explicit plan, exact approval, revalidation, and command log are separate safety gates.
6. A real screenshot and the 12-second accelerated scan.
7. Source and preview link: `https://clear.knasoftware.com/?utm_source=devto&utm_medium=article&utm_campaign=preview_1`.

The canonical owned version is live at <https://clear.knasoftware.com/guides/docker-xcode-system-data.html>. Use that page as the canonical URL when cross-posting to DEV or Hashnode.

The article must teach the storage model even if the reader never downloads the app.

## Show HN maker outline

Suggested title: **Show HN: Storage Clearer – a safety-first macOS cleaner for Docker and Xcode clutter**

Hacker News asks submitters not to post generated or AI-edited promotional text. The maker should write the submission in their own words using only this factual outline:

- The personal storage problem that led to the project.
- Why generic “clean” buttons felt unsafe.
- The Bash 3.2 engine and native SwiftUI surface.
- The four boundaries: audit, exact approval, revalidation, and command logging.
- The trade-off of distributing an unsigned preview.
- A request for technical criticism, not votes.

Link to the working repository or release as the submission target. Put `[URL]` in the maker comment only when it helps readers reach the demo.

## Product Hunt draft for the notarized release

Tagline: **Make room on your Mac without guessing what is safe to remove**

Short description:

Storage Clearer audits Docker, Xcode Simulator, and rebuildable developer caches, then presents a reviewed cleanup plan with exact approval and last-second target revalidation.

First-comment themes:

- The problem with broad “System Data” reporting.
- Why personal data, Docker volumes, source projects, restore points, browser profiles, and session history stay outside reviewed packages.
- What changed between the unsigned preview and notarized release.
- The specific feedback the maker wants from the community.

## Asset map

| Purpose | File |
| --- | --- |
| Social card | `website/assets/og.png` |
| Hero/dashboard | `website/assets/overview.png` |
| Product demo | `website/assets/scan-demo.gif` |
| Cleanup plan | `website/assets/cleanup-plan.png` |
| Exact approval | `website/assets/approval.png` |
| Safety model | `website/assets/safety-center.png` |

## Reply guide

- For safety questions, point to the exact exclusion or revalidation rule.
- For a suspected bug, ask for reproducible audit output with usernames, paths, and personal information removed.
- For Gatekeeper concerns, acknowledge the unsigned preview directly and explain that signing/notarization is the next trust upgrade.
- For feature requests that broaden deletion scope, prioritize explanation and reviewability over the number of bytes reclaimed.
