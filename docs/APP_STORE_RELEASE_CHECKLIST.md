# FitKiku iOS App Store Release Checklist

> Document class: live release runbook. The Xcode target and app behavior own
> binary truth; `FITKIKU_HEALTH_PRD.md` owns product/privacy scope. Update this
> checklist whenever the release binary, backend data handling, or App Store
> metadata changes. Completing local items does not mean Apple approved or the
> app is publicly available.

- **Current status:** FitKiku 1.0 is publicly available free in the configured
  non-EU App Store storefronts. Apple's public catalog reports version 1.0,
  App ID `6801516904`, and a 2026-08-27 release date. EU-27 storefronts remain
  disabled. This proves Apple distribution, not unattended reliability,
  external activation, retention, demand, or payment.
- **App Store:** `https://apps.apple.com/app/id6801516904`
- **Bundle ID:** `com.kikuai.fitkiku.health`
- **Minimum iOS:** 17.0
- **Released version/build:** 1.0 (3)
- **Current public source build:** 1.0 (3)
- **Required upload SDK:** iOS 26 SDK or later from April 28, 2026
- **Current local toolchain:** Xcode 26.6 / iOS SDK 26.5, verified 2026-08-23

## Hard release gates

- [x] Paid Apple Developer Program access is active.
- [x] Permanent App ID `com.kikuai.fitkiku.health` is registered with HealthKit.
- [x] The submission-identity decision is recorded: attempt the first review
      under the enrolled individual seller while describing FitKiku accurately
      as a non-medical Health & Fitness utility. Apple accepted and released
      version 1.0 under that identity.
- [x] App Store Connect app record exists and its Bundle ID matches the
      Apple-confirmed 1.0 (3) build.
- [x] The allowlisted production HTTPS backend supports the anonymous reviewer
      boundary.
- [x] App Review can create a fresh anonymous grant through the same-origin
      connection check without receiving a reusable credential in review notes.
- [x] Public support and privacy-policy URLs are live and match the deployed
      retention, recovery-copy, infrastructure, and AI-provider boundaries.
- [ ] Physical-iPhone reliability and accessibility passes meet their separate
      protocols; UI polish does not substitute for them.
- [x] Build 3 was uploaded, processed, selected, and submitted without an
      unresolved upload warning.
- [x] Owner explicitly approved submission.
- [x] Apple's public catalog exposes FitKiku 1.0 in configured non-EU
      storefronts through `https://apps.apple.com/app/id6801516904`.

Associated Domains and an Apple App Site Association file are not 1.0 release
gates. The current Pair Link contract intentionally uses the registered
`fitkiku-health://` custom URL scheme. Universal Links remain a post-1.0
hardening option after a paid App ID exists; do not advertise them before they
are implemented and tested in the signed binary.

## Product-page draft

The checked-in source remains the editable release input. The subtitle and
keywords below were saved and read back from App Store Connect on 2026-08-25;
the remaining product-page fields retain their previously verified values.
Promotional text remains intentionally empty.

The paste-ready English metadata and review-note template live in
[`docs/app-store/metadata/en-US.md`](app-store/metadata/en-US.md).

- **Name:** FitKiku
- **App Store:** https://apps.apple.com/app/id6801516904
- **Subtitle:** Steps and sleep for your AI
- **Primary category candidate:** Health & Fitness
- **Promotional text:** optional; omit for 1.0 unless it communicates a real,
  currently available capability.
- **Short promise:** Connect read-only Steps and Sleep to an agent you approve,
  with freshness, missing-data status, and revocation visible on iPhone.
- **Keywords:** health data,ai agent,privacy,fitness,wellness,activity,tracking,sync,accountability

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
content on 2026-08-13. At that checkpoint they described the then-current
private test accurately and did not claim App Store availability. The pages
were updated after release while preserving the separate hosted-service and
privacy boundaries.

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
- [x] Current `PrivacyInfo.xcprivacy` declares no tracking, conservatively
      declares Health and the stable installation Device ID for App
      Functionality, and declares app-only `UserDefaults` use with Apple's
      `CA92.1` reason.
- [x] Retention, deletion, AI-provider sharing, and source-detail handling in
      the public privacy policy match the deployed destination.
- [x] Xcode's aggregate privacy report was generated from the exact 2026-08-15
      archive and visually reviewed. It contains only Health and Device ID,
      both linked for App Functionality with tracking `NO`; it contains no
      required-reason API section. This is historical build `1.0 (3)` evidence,
      not the current source manifest.
- [ ] Before the next submission, generate a fresh aggregate privacy report
      from the exact archive and confirm that the required-reason section
      contains app-only `UserDefaults` with `CA92.1` and no unexplained API.

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
- [x] The current public candidate reports marketing version 1.0 and build 3.
- [x] The submitted distribution archive used monotonically increasing build
      number 3.
- [x] The exact archive declares `ITSAppUsesNonExemptEncryption = NO`; FitKiku
      uses only Apple-provided `URLSession` HTTPS and CryptoKit HMAC.
- [x] App Store Connect processed version 1.0 (3), retained the iPhone device
      family, iOS 17 minimum, and non-exempt encryption **No**, and accepted it
      into the review queue.
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

- [x] On 2026-08-23, the current source passed 68/68 iPhone 17 / iOS 26.5
      Simulator tests with normal Simulator signing, plus Release analysis and
      an unsigned generic-device archive.
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
- [x] KikuAI site commit `1b3b80c` initially published the limited reviewer
      boundary and executable bounded agent protocol without prematurely
      claiming App Store availability. Later release-state updates are tracked
      independently on the public site.
- [x] The source intentionally contains no Associated Domains entitlement;
      the 1.0 Pair Link path uses its registered custom URL scheme instead.
- [x] App Store Connect readback on 2026-08-16 confirmed the app record,
      processed build, published Health and Device ID privacy labels, free
      price, 4+ age rating, and non-medical-device declaration.
- [x] Untested Apple Silicon Mac and Vision Pro availability are disabled.
      Version 1.0 was configured as free in 148 non-EU storefronts; all 27 EU
      storefronts remain unavailable while the DSA trader declaration remains
      unresolved.
- [x] Review Notes, reviewer contact information, the physical-device recording,
      and the final five-card screenshot order were saved and resubmitted.
      Release remains manual after approval.
- [x] On 2026-08-16, the exact release source was installed on the owner iPhone
      without erasing the existing pairing. Install-only produced no receipt;
      one explicit foreground launch recovered three missing local dates,
      restored current server freshness, and enabled one bounded existing-agent
      read. No Health value, source, credential, Pair Link, or device identifier
      was retained.
- [x] Exact native background-hardening source `68ffc5f` passed 50/50 focused
      and 67/67 full iPhone 17 / iOS 26.5 Simulator tests, then produced a
      fresh Release analysis and a verified signed owner-device
      Release build 1.0 (2) with the privacy manifest and HealthKit background-
      delivery entitlement. It was
      installed over the preserved pairing; install-only produced no receipt,
      one explicit foreground activation restored a current bridge, and a
      separate bounded agent read exited 0. Its fixed unattended window was
      later closed without enough elapsed evidence, so it is not a background-
      reliability pass.
- [x] Build 3, which contains the Pair Link timezone fix, replaced the older
      builds in the submitted version.
- [x] A cold agent test discovered the gateway and required paths from the live
      Markdown alone, then passed anonymous issuance, credential-free Pair Link,
      pending-read denial, revocation, and revoked-read denial.
- [x] On 2026-08-28, Apple's public catalog returned FitKiku 1.0 for App ID
      `6801516904`, with a 2026-08-27 release date and zero price. Direct App
      Store URLs return the live product page in supported non-EU storefronts;
      sampled EU storefronts remain unavailable as configured.
- [ ] Unattended regularity remains `INCONCLUSIVE` and `NO-GO` for public
      claims. Physical VoiceOver, offline, reboot, delayed-Watch, force-quit,
      and fresh external-participant flows remain unproved.
- [ ] Release 1.0 uses the canonical `Europe/Kyiv` daily boundary. Do not claim
      locale-dynamic grouping or recruit a broader-timezone validation cohort
      until date attribution, payloads, corrections, status, and DST behavior
      pass one explicit cross-zone contract.

Local export integrity, the live reviewer path, App Store Connect record,
Apple build processing, reviewer-information delivery, review, and public
non-EU distribution pass. Physical foreground transfer passes, but unattended
delivery, physical VoiceOver, and fresh external-user usability remain
unknown.

## Local verification commands

```bash
xcodebuild \
  -project ios/FitKiku/FitKiku.xcodeproj \
  -scheme FitKiku \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
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
