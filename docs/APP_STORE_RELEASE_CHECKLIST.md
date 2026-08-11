# FitKiku iOS App Store Release Checklist

> Document class: live release runbook. The Xcode target and app behavior own
> binary truth; `FITKIKU_HEALTH_PRD.md` owns product/privacy scope. Update this
> checklist whenever the release binary, backend data handling, or App Store
> metadata changes. Completing local items does not mean Apple approved or the
> app is publicly available.

- **Current status:** local release preparation only
- **Bundle ID:** `com.kikuai.fitkiku.health`
- **Minimum iOS:** 17.0
- **Current version/build:** 1.0 (1)

## Hard release gates

- [ ] Owner explicitly approves Apple Developer Program enrollment/payment.
- [ ] The submission identity is resolved with Apple: FitKiku is a non-medical
      Health & Fitness utility, but Guideline 5.1.1(ix) says apps requiring
      sensitive user information should be submitted by the legal entity
      providing the service. A close competitor is currently listed under an
      individual seller, which lowers but does not remove review risk.
- [ ] App Store Connect app record exists and the Bundle ID matches the build.
- [ ] The paid-program App ID, provisioning profile, and final binary include
      Associated Domains, and
      `https://kikuai.dev/.well-known/apple-app-site-association` serves the
      exact production app identifier over HTTPS without redirects. Personal
      Team cannot prove this capability.
- [ ] A production HTTPS backend supports the intended public user boundary.
- [ ] App Review can exercise the complete flow through an active demo account,
      fully featured demo mode, or reviewer-only sample Pair Link and backend.
- [ ] Public support and privacy-policy URLs are live and owned; complete the
      final production retention/provider disclosures before submission.
- [ ] Physical-iPhone reliability and accessibility passes meet their separate
      protocols; UI polish does not substitute for them.
- [ ] The final archive is uploaded and processed without unresolved warnings.
- [ ] Owner explicitly approves submission.

## Product-page draft

These are working drafts, not published metadata.

- **Name:** FitKiku
- **Subtitle:** Apple Health for your AI
- **Primary category candidate:** Health & Fitness
- **Promotional text:** optional; omit for 1.0 unless it communicates a real,
  currently available capability.
- **Short promise:** Connect read-only Steps and Sleep to an agent you approve,
  with freshness, missing-data status, and revocation visible on iPhone.
- **Keywords draft:** apple health,ai agent,steps,sleep,healthkit,privacy

### Description draft

FitKiku is a focused iPhone companion for bringing recent Apple Health context
to a personal AI agent you approve.

Review Steps and Sleep summaries on your iPhone before connecting anything.
When you choose to connect a compatible agent, FitKiku shows the exact HTTPS
destination, requested read-only categories, retention statement, and AI-
processing disclosure before approval.

FitKiku helps you:

- review daily Steps and Sleep from Apple Health;
- keep missing or partial coverage visible instead of treating it as zero;
- see when the server last confirmed delivery and when an active agent fetched;
- revoke future device and agent access;
- use Apple Watch data after it reaches Apple Health on the paired iPhone.

FitKiku never writes to Apple Health and contains no advertising or tracking
SDK. Background delivery is best effort; opening the app performs a bounded
foreground catch-up. FitKiku is not medical diagnosis, treatment, clearance,
or emergency care.

Public wording must be rechecked against the exact reviewer-accessible backend
and final App Privacy answers before this draft is pasted into App Store
Connect.

The final description must say that background delivery is best effort and
must not claim medical guidance, guaranteed delivery, broad agent
compatibility, or support that has not passed the relevant gates.

## Monetization boundary

- **iOS app:** free; local Steps/Sleep summaries remain usable without pairing
  or payment.
- **Paid service:** optional hosted FitKiku Health Gateway, with a first
  validation hypothesis of USD 19/year for one iPhone and one active agent.
- **Checkout:** web-only through Paddle after the distribution, retention,
  privacy, and provider-activation gates pass.
- **Inside the app:** no price, paywall, checkout, “buy”, “subscribe”, or link
  that calls the user to purchase elsewhere.

This uses the free stand-alone companion shape described in App Review
Guideline 3.1.3(f). It is a planned review position, not an Apple approval. Do
not add StoreKit or a second entitlement model as a speculative fallback. If
App Review determines that the hosted service must use in-app purchase, stop
and reshape the business decision before changing the binary.

## Required URLs and contacts

- [x] Privacy Policy URL — <https://kikuai.dev/fitkiku/privacy/>.
- [x] Support URL — <https://kikuai.dev/fitkiku/support/>.
- [ ] Optional privacy choices/deletion URL — decide from the final hosted data
      control path.
- [ ] App Review contact name, phone, and email — owner-provided in App Store
      Connect, never committed here.

Do not publish placeholder or empty pages. Apple requires functional URLs in a
final submission.

Both required URLs returned public HTTPS `200` responses with their canonical
content on 2026-08-09. They describe current private testing accurately and do
not claim App Store availability. The privacy page intentionally keeps public
enrollment closed until the production backup-retention schedule and
destination/provider list are finalized.

## App Privacy candidate answers

Reconcile these against the exact production backend and every included SDK
immediately before submission. They are deliberately conservative.

| Data type | Linked to user | Tracking | Purpose | Why |
|---|---:|---:|---|---|
| Health | Yes | No | App Functionality | Daily Steps, asleep minutes, coverage, and Health source details are sent to the approved destination. |
| Device ID | Yes | No | App Functionality | A stable app installation identifier scopes credentials, idempotency, and revocation. |

- [x] No advertising or tracking SDK is in the target.
- [x] `PrivacyInfo.xcprivacy` declares no tracking and conservatively declares
      Health and the stable installation Device ID for App Functionality.
- [ ] Verify that retention, deletion, AI-provider sharing, and source-detail
      handling in the public privacy policy match the deployed destination.
- [ ] Confirm no required-reason API category appears in the final privacy
      report; the current first-party target declares none.
- [ ] Generate and review Xcode's privacy report from the final archive.

HealthKit-derived data must never be used for advertising, marketing, or
use-based data mining. The app must disclose the specific Health data it reads
and transfers before transfer.

## Reviewer access and notes

Prepare review notes with only non-secret, reviewer-specific material:

1. FitKiku reads Steps and Sleep from HealthKit and never writes HealthKit.
2. The primary setup path begins in a compatible agent, which creates a
   single-use Pair Link. Supply App Review an active sample Pair Link or a
   fully featured demo path.
3. Opening a Pair Link performs a metadata-only preview. Health data transfer
   begins only after explicit in-app approval and Health authorization.
4. State that background delivery is best effort and that foreground catch-up
   is expected.
5. Explain how to disconnect and revoke both device ingest and agent read
   access.
6. If Apple Watch data is needed for review, state the hardware dependency and
   provide an alternative deterministic review path for empty/local states.
7. State that the app is free and has no purchasing flow. Any optional hosted
   account is acquired and managed on the web without an in-app purchase CTA.

Never paste production credentials, owner health values, or a reusable Pair
Link into this repository.

## Screenshots

Apple currently accepts one to ten iPhone screenshots. Capture only synthetic
or empty demo states with no credentials or personal health data.

- [x] First run: clear Connect Agent and Apple Health steps.
- [ ] Consent: recapture after the synthetic retention disclosure matches the
      deployed wording that revocation stops future access but does not delete
      stored summaries.
- [x] Delivery: synthetic current and partial/stale states with actionable copy.
- [x] The English set is 1206x2622, opaque JPEG from an iPhone 17
      simulator, an accepted 6.3-inch portrait size in Apple's current
      screenshot specification.
- [x] No screenshot contains Pair Links, tokens, server credentials, real Steps,
      real asleep minutes, source identifiers, or owner-specific timestamps.
- [ ] Add localized variants only after localized metadata and UI are final.

The checked-in English set is under `docs/app-store/screenshots/en-US/`. Regenerate
it from deterministic synthetic data with:

```bash
./ios/FitKiku/scripts/capture_app_store_screenshots.sh
```

The capture path exists only in Debug builds. Set `FITKIKU_DEMO_SCENARIO` to one
of `first-run`, `consent`, `current`, `partial`, `unavailable`, `revoked`,
`expired`, or `health-empty` to render a state. Synthetic mode uses isolated
defaults, a no-op credential cleanup, no HealthKit reader or sync coordinator,
and a transport that always fails without I/O. It is screenshot and visual-QA
infrastructure, not a reviewer demo, demo account, or evidence of live state
transitions. The Release archive must be checked for its absence on every
release candidate.

## Binary and metadata preflight

- [x] Asset catalog contains a 1024x1024 opaque App Icon master.
- [x] App icon is configured as `AppIcon` for Debug and Release.
- [x] Bundle contains a valid `PrivacyInfo.xcprivacy`.
- [x] English HealthKit permission copy is localized through
      `en.lproj/InfoPlist.strings`.
- [x] A source-language string catalog is present for user-facing SwiftUI copy.
- [x] The unsigned local Release archive excludes the synthetic demo scenario
      parser, sample agent name, and synthetic token marker.
- [ ] Final English catalog is reviewed; Russian/Ukrainian are optional later
      releases and must not be machine-published without review.
- [ ] Marketing version and monotonically increasing build number are set for
      the exact archive.
- [ ] Encryption/export-compliance answers are completed for TLS and CryptoKit
      HMAC use; do not guess or hide cryptography.
- [ ] Final archive passes Xcode validation after enrollment and app-record
      creation.
- [ ] Final paid-program archive contains the `applinks:kikuai.dev`
      entitlement; the current Personal Team development build intentionally
      does not.

## Accessibility and quality preflight

- [x] Core layout uses Dynamic Type and adapts two-column metrics to a vertical
      fallback.
- [x] Icons do not carry status meaning alone; important status is textual.
- [x] Main action labels have a 44-point minimum height.
- [x] Recovery, revocation, and delivery diagnostics use progressive
      disclosure rather than competing with activation.
- [ ] VoiceOver reading order and action names checked on a physical iPhone.
- [x] All eight synthetic states rendered at the largest simulator accessibility
      text size without non-scrollable clipping; physical-device interaction
      remains a separate gate.
- [x] All eight synthetic states reviewed in light and dark appearance; secondary
      copy now uses an explicit higher-contrast semantic color.
- [ ] Reduce Motion pass completed if state animation is added; the current UI
      has no custom motion.
- [x] Synthetic unavailable, expired Pair Link, revoked credential, and empty
      Health states rendered and reviewed.
- [ ] Real offline/backend failure transitions, credential revocation, and
      Health authorization outcomes manually exercised on a physical iPhone.

## Latest local release receipt

- [x] 54/54 iPhone 17 / iOS 26.5 Simulator tests pass on the current release-
      hardening worktree.
- [x] The public iOS mirror passes the same 54-test suite after an ordinary
      shutdown/boot recovered one initial Simulator `Busy` preflight failure.
- [x] A fresh unsigned generic-device Release archive succeeds, contains a
      valid privacy manifest and App Icon metadata, carries the HealthKit
      entitlement, and excludes DEBUG synthetic markers.
- [x] The Personal Team source intentionally contains no Associated Domains
      entitlement; this is a recorded release blocker, not a passing public-
      onboarding result.
- [ ] Install this exact release-hardening source on a physical iPhone only
      after the active `b99f0fb` reliability window completes or is explicitly
      abandoned; replacement starts a new evidence window.

## Local verification commands

```bash
xcodebuild \
  -project ios/FitKiku/FitKiku.xcodeproj \
  -scheme FitKiku \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test

xcodebuild \
  -project ios/FitKiku/FitKiku.xcodeproj \
  -scheme FitKiku \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/FitKiku.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  archive
```

After the archive, inspect the bundle rather than relying on project settings:

```bash
test -f /tmp/FitKiku.xcarchive/Products/Applications/FitKiku.app/PrivacyInfo.xcprivacy
/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons' \
  /tmp/FitKiku.xcarchive/Products/Applications/FitKiku.app/Info.plist
```

## Apple primary sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Add a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [App screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Supporting associated domains](https://developer.apple.com/documentation/Xcode/supporting-associated-domains?changes=_2)
- [Supported capabilities for iOS memberships](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
