# FitKiku iOS App Store Release Checklist

> Document class: live release runbook. The Xcode target and app behavior own
> binary truth; `FITKIKU_HEALTH_PRD.md` owns product/privacy scope. Update this
> checklist whenever the release binary, backend data handling, or App Store
> metadata changes. Completing local items does not mean Apple approved or the
> app is publicly available.

- **Current status:** App Store Connect version 1.0 (1) has an Apple-confirmed
  build and otherwise complete release metadata. **Add for Review** is enabled,
  but the reviewer phone and email fields were empty on the latest readback and
  must be saved before the version is added to a review submission.
- **Bundle ID:** `com.kikuai.fitkiku.health`
- **Minimum iOS:** 17.0
- **Current version/build:** 1.0 (1)
- **Required upload SDK:** iOS 26 SDK or later from April 28, 2026
- **Current local toolchain:** Xcode 26.6 / iOS SDK 26.5, verified 2026-08-15

## Hard release gates

- [x] Paid Apple Developer Program access is active.
- [x] Permanent App ID `com.kikuai.fitkiku.health` is registered with HealthKit.
- [x] The submission-identity decision is recorded: attempt the first review
      under the enrolled individual seller while describing FitKiku accurately
      as a non-medical Health & Fitness utility. Apple acceptance under that
      identity remains unproven until review.
- [x] App Store Connect app record exists and its Bundle ID matches the
      Apple-confirmed 1.0 (1) build.
- [x] The allowlisted production HTTPS backend supports the anonymous reviewer
      boundary.
- [x] App Review can create a fresh anonymous grant through the same-origin
      connection check without receiving a reusable credential in review notes.
- [x] Public support and privacy-policy URLs are live and match the deployed
      retention, recovery-copy, infrastructure, and AI-provider boundaries.
- [ ] Physical-iPhone reliability and accessibility passes meet their separate
      protocols; UI polish does not substitute for them.
- [x] The final archive is uploaded and processed without unresolved warnings.
- [ ] Owner explicitly approves submission.

Associated Domains and an Apple App Site Association file are not 1.0 release
gates. The current Pair Link contract intentionally uses the registered
`fitkiku-health://` custom URL scheme. Universal Links remain a post-1.0
hardening option after a paid App ID exists; do not advertise them before they
are implemented and tested in the signed binary.

## Product-page draft

The checked-in source remains the editable release input. On 2026-08-16, the
English metadata, build selection, and synthetic screenshots were read back
from App Store Connect. Promotional text remains intentionally empty.

The paste-ready English metadata and review-note template live in
[`docs/app-store/metadata/en-US.md`](app-store/metadata/en-US.md).

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
- delete an anonymous FitKiku connection and its synced server data without
  changing Apple Health;
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
- [x] Privacy choices/deletion URL — <https://kikuai.dev/fitkiku/support/>;
      it explains in-app anonymous-account deletion and opens a pre-addressed
      support email for process guidance without collecting health data in a
      web form.
- [x] Public support and App Review email — `fitkiku@kikuai.dev`.
- [ ] App Review contact phone and dedicated email — the owner supplied both,
      but the fields were empty on the 2026-08-16 submission-page readback.
      Save and read them back immediately before submission; the private phone
      is never committed here.

Do not publish placeholder or empty pages. Apple requires functional URLs in a
final submission.

Both required URLs returned public HTTPS `200` responses with their canonical
content on 2026-08-13. They describe current private testing accurately and do
not claim App Store availability. The privacy page intentionally keeps public
enrollment closed until the production backup-retention schedule and
destination/provider list are finalized.

Public setup creates an anonymous FitKiku guest with no email, password, or
recovery identity. The paired iOS Settings screen exposes **Delete FitKiku
account and data** only for that guest; server confirmation precedes protected
local cleanup, and the confirmation states that Apple Health is unchanged.
Private-owner connections remain revocation-only. The limited reviewer boundary
is deployed; it is not a claim of broad hosted enrollment.

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
- [x] Retention, deletion, AI-provider sharing, and source-detail handling in
      the public privacy policy match the deployed destination.
- [x] Xcode's aggregate privacy report was generated from the exact 2026-08-15
      archive and visually reviewed. It contains only Health and Device ID,
      both linked for App Functionality with tracking `NO`; it contains no
      required-reason API section.

HealthKit-derived data must never be used for advertising, marketing, or
use-based data mining. The app must disclose the specific Health data it reads
and transfers before transfer.

## Reviewer access and notes

Prepare review notes with only non-secret, reviewer-specific material:

1. FitKiku reads Steps and Sleep from HealthKit and never writes HealthKit.
2. The primary setup path begins in a compatible agent, which creates a
   single-use Pair Link. For review, supply the stable same-origin
   `/healthkit/connect` page; do not paste a reusable Pair Link or bearer into
   review notes.
3. Opening a Pair Link performs a metadata-only preview. Health data transfer
   begins only after explicit in-app approval and Health authorization.
4. State that background delivery is best effort and that foreground catch-up
   is expected.
5. Explain how to disconnect and revoke both device ingest and agent read
   access.
6. Explain anonymous account deletion and that it does not delete Apple Health
   data.
7. If Apple Watch data is needed for review, state the hardware dependency and
   provide an alternative deterministic review path for empty/local states.
8. State that the app is free and has no purchasing flow. Any optional hosted
   account is acquired and managed on the web without an in-app purchase CTA.

Never paste production credentials, owner health values, or a reusable Pair
Link into this repository.

## Screenshots

Apple currently accepts one to ten iPhone screenshots. Capture only synthetic
or empty demo states with no credentials or personal health data.

- [x] First run: clear Connect Agent and Apple Health steps.
- [x] Consent: the synthetic retention disclosure matches the deployed wording
      that revocation stops future access but does not delete stored summaries.
- [x] Delivery: synthetic current and partial/stale states with actionable copy.
- [x] The English set is 1320x2868, opaque JPEG from an iPhone 17 Pro Max
      simulator, an accepted 6.9-inch portrait size in Apple's current
      screenshot specification.
- [x] No screenshot contains Pair Links, tokens, server credentials, real Steps,
      real asleep minutes, source identifiers, or owner-specific timestamps.
- [x] Four English screenshots are uploaded to the 6.9-inch set in storefront
      order: first run, consent, current delivery, partial delivery.
- [x] A four-card marketing replacement was prepared and visually checked at
      storefront-thumbnail size. Its final upload files are opaque 1320x2868
      JPEGs under
      `docs/app-store/screenshots/marketing-en-US/iphone-6.9/`; the reproducible
      layout input and provenance are documented beside them. This preparation
      is not proof that the replacement was uploaded or saved in App Store
      Connect.
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
- [x] Final English source copy is reviewed across the synthetic release states;
      Russian/Ukrainian are optional later releases and must not be machine-
      published without review.
- [x] The local candidate archive reports marketing version 1.0 and build 1.
- [x] The final distribution archive used the still-valid, monotonically
      increasing build number 1 at upload time.
- [x] The exact archive declares `ITSAppUsesNonExemptEncryption = NO`; FitKiku
      uses only Apple-provided `URLSession` HTTPS and CryptoKit HMAC.
- [x] App Store Connect processed the final archive and reports binary state
      **Confirmed**, version 1.0 (1), iPhone device family, iOS 17 minimum, and
      non-exempt encryption **No**.
- [x] The app registers the `fitkiku-health://` Pair Link scheme used by the
      current 1.0 connection contract.
- [x] Settings exposes destructive, confirmed account deletion only after
      authenticated status identifies an anonymous guest.
- [ ] If Universal Links are added later, verify the paid-program archive,
      Associated Domains entitlement, and exact AASA app identifier together.

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

- [x] On 2026-08-15, the exact release source passed 60/60 iPhone 17 / iOS 26.5
      Simulator tests and a Release analysis pass.
- [x] A fresh 1.0 (1) archive exported as an App Store Connect IPA signed by
      Apple Distribution. Its profile has no device list, disables
      `get-task-allow`, carries HealthKit and background-delivery entitlements,
      and expires on 2027-08-13.
- [x] The exported bundle contains both HealthKit purpose strings, the exempt-
      encryption declaration, a no-tracking privacy manifest, and no synthetic-
      demo marker.
- [x] Xcode's aggregate privacy report matches the conservative App Privacy
      worksheet: linked Health and Device ID for App Functionality, no tracking.
- [x] The public reviewer lifecycle and anonymous deletion path have passed one
      external synthetic issue-to-delete check with old-credential denial.
- [x] Public product, Privacy, Support, and agent-readable pages describe the
      limited reviewer boundary without claiming App Store availability.
- [x] The source intentionally contains no Associated Domains entitlement;
      the 1.0 Pair Link path uses its registered custom URL scheme instead.
- [x] App Store Connect readback on 2026-08-16 confirmed the app record,
      processed build, published Health and Device ID privacy labels, free
      price, 4+ age rating, and non-medical-device declaration.
- [x] Untested Apple Silicon Mac and Vision Pro availability are disabled.
      Version 1.0 is public and free in 148 territories; all 27 EU storefronts
      are unavailable while the DSA trader declaration remains unresolved.
- [ ] App Review notes are saved, release is manual after approval, the current
      screenshot order is verified, and **Add for Review** is enabled. The
      reviewer phone and email inputs are empty and remain a submission blocker
      until they are saved and read back.
- [ ] Install and exercise this exact release source on a physical iPhone;
      HealthKit foreground sync, VoiceOver, and background delivery remain
      separate evidence gates.

Local export integrity, the live reviewer path, App Store Connect record, and
Apple build processing pass. The version has deliberately not been added to a
review submission or submitted. Physical-device proof and Apple acceptance
under the individual seller remain unknown.

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
- [Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
- [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [App screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Submitting apps](https://developer.apple.com/app-store/submitting/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Supporting associated domains](https://developer.apple.com/documentation/Xcode/supporting-associated-domains?changes=_2)
- [Supported capabilities for iOS memberships](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
