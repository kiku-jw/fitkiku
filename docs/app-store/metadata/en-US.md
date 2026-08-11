# FitKiku App Store Metadata — English (U.S.)

> Document class: release input. This is a paste-ready draft for version 1.0,
> not proof of an App Store Connect record, uploaded build, or Apple approval.
> Reconcile every claim against the exact reviewer-accessible backend and final
> binary before submission. Never commit reviewer credentials or a live Pair
> Link here.

## App information

- **Name (7/30):** `FitKiku`
- **Subtitle (24/30):** `Apple Health for your AI`
- **Primary category:** Health & Fitness
- **Secondary category:** None for 1.0
- **Bundle ID:** `com.kikuai.fitkiku.health`
- **SKU candidate:** `fitkiku-health-ios`
- **Copyright:** owner-provided year and legal name in App Store Connect
- **Privacy Policy URL:** `https://kikuai.dev/fitkiku/privacy/`
- **Privacy Choices URL:** `https://kikuai.dev/fitkiku/support/`
- **Support URL:** `https://kikuai.dev/fitkiku/support/`
- **Marketing URL:** `https://kikuai.dev/fitkiku/`

Do not choose a final seller name, copyright owner, territory set, or age
rating on the owner's behalf. Those fields belong to the enrolled App Store
Connect account and its current questionnaires.

## Keywords

`apple health,ai agent,steps,sleep,healthkit,privacy,fitness,wellness`

This is below the 100-character limit. Recheck punctuation and duplication in
App Store Connect; do not repeat `FitKiku` or words already carrying stronger
weight in the name and subtitle unless search evidence justifies it.

## Description

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
- use Apple Watch data after it reaches Apple Health on the paired iPhone.

FitKiku never writes to Apple Health. It contains no advertising or tracking
SDK. Health summaries are sent only after you approve a compatible FitKiku
destination and grant Apple Health read access.

Background delivery is best effort. Opening the app can perform a bounded
foreground catch-up when recent delivery needs attention.

FitKiku is a fitness-data connection and accountability tool. It is not
medical diagnosis, treatment, clearance, or emergency care.

## Promotional text

Leave empty for 1.0. Do not advertise a hosted plan, broad agent compatibility,
or App Store availability before each claim is true.

## Version 1.0 release notes

Initial release of FitKiku, a read-only Apple Health connector for compatible
personal AI agents.

- Review daily Steps and Sleep on iPhone.
- Approve the destination and data categories before sharing.
- See freshness, missing-data, and delivery status.
- Disconnect and revoke future access at any time.

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

The iOS app does not create an account. Its connection grants are revocable,
and the Support URL provides the separate stored-data deletion request.

## App Review notes template

FitKiku is an iPhone-only Health & Fitness utility. It requests read access to
Steps and Sleep Analysis and never requests HealthKit write access.

The main connection path begins when a compatible agent creates a single-use
Pair Link. Opening the link shows a metadata-only preview. No health summary is
sent until the reviewer approves the named HTTPS destination and separately
grants Apple Health read access.

For review, use the active sample path supplied in App Store Connect. The
sample must exercise the real Release flow and an active reviewer-accessible
backend; the repository's synthetic Debug screenshot mode is not a reviewer
demo.

After connection:

1. Use **Check and sync now** to perform a bounded foreground catch-up.
2. Open delivery details to review freshness and missing-data status.
3. Open Settings and choose **Disconnect and revoke server access** to revoke
   future device delivery and agent reads.

Background delivery is best effort. Apple Watch data appears only after it
reaches Apple Health on the paired iPhone. Empty or unavailable Health data is
shown as Unknown rather than as zero.

The app is free and contains no purchase, subscription, advertising, or
tracking flow. Do not mention the planned hosted-gateway price unless that
service and its review position are finalized.

### Required private App Store Connect inputs

- Reviewer first and last name, phone number, and email
- Exact numbered review steps matching the uploaded build
- Active reviewer sample Pair Link or fully featured Release demo path
- Any required demo credentials entered only in App Store Connect
- Backend availability window and support contact during review

## Export compliance worksheet

The app uses HTTPS/TLS and CryptoKit HMAC. Complete Apple's current export
compliance questionnaire from the exact archive. Do not set
`ITSAppUsesNonExemptEncryption` or claim an exemption until the owner has
confirmed the answers App Store Connect requests.

## Submission blockers that metadata cannot close

- Paid Apple Developer Program enrollment and an App Store Connect app record
- Submission-identity decision for Apple's sensitive-data legal-entity guidance
- Reviewer-accessible production boundary or a real fully featured Release demo
- Final retention/provider disclosure and deletion handling
- Frozen physical-iPhone reliability and accessibility evidence
- Signed distribution archive, upload, processing, privacy report, and validation
- Owner approval to submit

## Apple primary sources

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [App privacy](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
