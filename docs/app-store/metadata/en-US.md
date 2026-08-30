# FitKiku App Store Metadata — English (U.S.)

> Document class: release input. This records the released version 1.0
> metadata and the separate version 1.1 candidate. Build `1.0 (3)` passed
> review and is publicly available free in the configured non-EU storefronts.
> Apple's public catalog reports a 2026-08-27 release date for App ID
> `6801516904`. EU-27 storefronts remain disabled. Never commit reviewer
> credentials or a live Pair Link here.

## App information

- **Name (7/30):** `FitKiku`
- **App Store:** `https://apps.apple.com/app/id6801516904`
- **Subtitle (27/30):** `Steps and sleep for your AI`
- **Primary category:** Health & Fitness
- **Secondary category:** None for 1.0
- **Bundle ID:** `com.kikuai.fitkiku.health`
- **SKU candidate:** `fitkiku-health-ios`
- **Copyright:** owner-provided year and legal name in App Store Connect
- **Privacy Policy URL:** `https://kikuai.dev/fitkiku/privacy/`
- **Privacy Choices URL:** `https://kikuai.dev/fitkiku/support/`
- **Support URL:** `https://kikuai.dev/fitkiku/support/`
- **Marketing URL:** `https://kikuai.dev/fitkiku/`
- **Public support and App Review email:** `fitkiku@kikuai.dev`

Do not choose a final seller name, copyright owner, territory set, or age
rating on the owner's behalf. Those fields belong to the enrolled App Store
Connect account and its current questionnaires.

## Keywords

`health data,ai agent,privacy,fitness,wellness,activity,tracking,sync,accountability`

This is below the 100-character limit. Recheck punctuation and duplication in
App Store Connect; do not repeat `FitKiku` or words already carrying stronger
weight in the name and subtitle unless search evidence justifies it.

### Next-version ASO candidate — not applied in App Store Connect

Use this candidate only after rechecking the live metadata and byte limits:

`agent,assistant,activity,wellness,sync,export,automation,context,privacy,accountability,tracking`

It avoids repeating the name and the strongest subtitle words while covering
the agent, portability, automation, and trust jobs. Do not add competitor names
or Apple trademarks as keywords.

## Released version 1.0 description

FitKiku connects recent Apple Health context to a personal AI agent you
approve.

Review Steps and Sleep summaries on your iPhone before connecting anything.
When you connect a compatible agent, FitKiku shows the exact destination,
read-only categories, retention statement, and AI-processing disclosure before
you approve the connection.

FitKiku helps you:

- review daily Steps and Sleep from Apple Health;
- keep missing or partial coverage visible instead of treating it as zero;
- see freshness and recent delivery status;
- revoke future device delivery and agent access;
- delete an anonymous FitKiku connection and its synced server data;
- use Apple Watch data after it reaches Apple Health on the paired iPhone.

FitKiku never writes to Apple Health. It contains no advertising or tracking
SDK. Health summaries are sent only after you approve a compatible FitKiku
destination and grant Apple Health read access.

Background delivery is best effort. Opening the app can perform a bounded
foreground catch-up when recent delivery needs attention.

FitKiku is a fitness-data connection and accountability tool. It is not
medical diagnosis, treatment, clearance, or emergency care.

## Version 1.1 description candidate — not applied in App Store Connect

Let the AI you already use take your recent Steps and Sleep into account —
without retyping them every day.

FitKiku is a separate iPhone app. It privately delivers recent read-only Steps
and Sleep to ChatGPT or another AI that can open a normal HTTPS link.

Tap Connect ChatGPT, approve one private read-only link, grant Steps and Sleep
access, and copy one prepared message into your chat. No server address,
password, pairing code, or Health export is needed. Compatible agents can still
use the Advanced Pair Link flow.

FitKiku helps you:

- review daily Steps and Sleep from Apple Health;
- keep missing or partial coverage visible instead of treating it as zero;
- see freshness and recent delivery status;
- revoke future device delivery and agent access;
- delete an anonymous FitKiku connection and its synced server data;
- use Apple Watch data after it reaches Apple Health on the paired iPhone.

FitKiku never writes to Apple Health. It contains no advertising or tracking
SDK. Health summaries are sent only after you approve a compatible FitKiku
destination and grant Apple Health read access.

Background delivery is best effort. Opening the app can perform a bounded
foreground catch-up when recent delivery needs attention.

FitKiku does not include an AI coach, expose everything in Apple Health, or
promise real-time delivery. It is a fitness-data connection and accountability
tool, not medical diagnosis, treatment, clearance, or emergency care.

## Promotional text

Leave empty for 1.0. Do not advertise a hosted plan, broad agent compatibility,
or App Store availability before each claim is true.

Next-version candidate, subject to a final truth and length check:

`Let your AI use recent Steps and Sleep without daily retyping. See freshness, keep missing data honest, and revoke read-only access anytime.`

## Version 1.0 release notes

Initial release of FitKiku, a read-only Apple Health connector for compatible
personal AI agents.

- Review daily Steps and Sleep on iPhone.
- Approve the destination and data categories before sharing.
- See freshness, missing-data, and delivery status.
- Disconnect and revoke future access at any time.
- Delete anonymous synced FitKiku data without changing Apple Health.

## Next-version release-note candidate

- Leads with the result: let your AI use recent Steps and Sleep without daily
  retyping.
- Creates one private read-only link inside FitKiku; no server, password, Pair
  Link, or setup code is needed for the primary flow.
- Distinguishes current server delivery from the agent reading that update.
- Adds one copyable or shareable prompt when the agent still needs to fetch.
- Adds native Share and Rate actions in Settings.
- May show Apple's native rating prompt only after two distinct current agent
  reads, at most once per app version.
- Declares the existing app-only `UserDefaults` use with Apple's `CA92.1`
  required-reason API code in the bundled privacy manifest.

## App Privacy candidate

These answers are deliberately conservative and must be reconciled against the
deployed backend and every SDK immediately before submission.

| Data type | Linked to user | Tracking | Purpose |
|---|---:|---:|---|
| Health | Yes | No | App Functionality |
| Device ID | Yes | No | App Functionality |

The privacy policy describes the exact Steps, Sleep, coverage, source-detail,
installation-identifier, AI-provider, retention, revocation, and deletion
boundaries. No data is used for advertising or tracking.

Public setup creates an anonymous FitKiku guest with no email, password, or
recovery identity. Its connection grants are revocable, and the paired iOS
Settings screen can delete that guest and its synced FitKiku server data.
Deletion does not modify Apple Health.

The next-version review-prompt policy stores only the last counted agent-fetch
timestamp, a bounded success count, and the prompted app version in on-device
`UserDefaults`. It stores no Health measurement and transmits no review-
eligibility state. This local-only state does not add a collected-data category;
reassess immediately if analytics or remote event collection is introduced.

## App Review notes template

FitKiku is an iPhone-only Health & Fitness utility. It requests read access to
Steps and Sleep Analysis and never requests HealthKit write access.

The main connection path begins when a compatible agent creates a single-use
Pair Link. Opening the link shows a metadata-only preview. No health summary is
sent until the reviewer approves the named HTTPS destination and separately
grants Apple Health read access.

For review, open
`https://fitkiku-origin.kikuai.dev/healthkit/connect`. Choose **Create Pair
Link**, then open or copy that link to the review iPhone. This creates a fresh
anonymous grant through the real public endpoint and exercises the real Release
consent flow against the reviewer-accessible backend. The page keeps its
credential only in the open browser tab, displays connection state only, and
does not request or render Health values. The repository's synthetic Debug
screenshot mode is not a reviewer demo.

After connection:

1. Use **Check and sync now** to perform a bounded foreground catch-up.
2. Open delivery details to review freshness and missing-data status.
3. Open Settings and choose **Disconnect and revoke server access** to revoke
   future device delivery and agent reads.
4. For an anonymous public connection, choose **Delete FitKiku account and data**
   and confirm to remove the guest and stored FitKiku summaries. This does not
   delete Apple Health data.

Background delivery is best effort. Apple Watch data appears only after it
reaches Apple Health on the paired iPhone. Empty or unavailable Health data is
shown as Unknown rather than as zero.

The app is free and contains no purchase, subscription, advertising, or
tracking flow. Do not mention the planned hosted-gateway price unless that
service and its review position are finalized.

### Required private App Store Connect inputs

- Reviewer first and last name and phone number
- Reviewer email: `fitkiku@kikuai.dev`
- Exact numbered review steps matching the uploaded build
- Same-origin connection-check URL:
  `https://fitkiku-origin.kikuai.dev/healthkit/connect`
- Any required demo credentials entered only in App Store Connect; the current
  connection-check path requires none
- Backend availability window and support contact during review

## Export compliance worksheet

The app uses Apple-provided `URLSession` HTTPS/TLS and CryptoKit HMAC. Exact
build-3 source and its uploaded archive declare
`ITSAppUsesNonExemptEncryption = NO`; Apple documents that apps limited to
encryption within its operating system can follow the no-documentation path.
Reconfirm that answer for every later processed build.

## External gates that metadata cannot close

- Physical VoiceOver and unattended-background reliability evidence, which
  remain separate from the completed review recording and public release.
- External activation, repeated use, support burden, demand, and payment.

## Apple primary sources

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [App privacy](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
