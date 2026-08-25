# FitKiku App Store Metadata — English (U.S.)

> Document class: release input. This is the durable source for version 1.0
> metadata. Build `1.0 (3)` was resubmitted after the 2026-08-25 metadata-only
> Guideline 5.2.5 correction; the last verified App Store Connect state is
> **Waiting for Review**. This is not Apple approval or public availability.
> Never commit reviewer credentials or a live Pair Link here.

## App information

- **Name (7/30):** `FitKiku`
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
- delete an anonymous FitKiku connection and its synced server data;
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
- Delete anonymous synced FitKiku data without changing Apple Health.

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

The app uses Apple-provided `URLSession` HTTPS/TLS and CryptoKit HMAC. The exact
1.0 (1) archive declares `ITSAppUsesNonExemptEncryption = NO`; Apple documents
that apps limited to encryption within its operating system do not require App
Store Connect encryption documentation. Confirm the processed build reports
the same answer before submission.

## Submission blockers that metadata cannot close

- App Store Connect app record for the registered production Bundle ID
- Submission-identity decision for Apple's sensitive-data legal-entity guidance
- Frozen physical-iPhone reliability and accessibility evidence
- App Store Connect upload, processing, and validation of the signed archive
- Owner approval to submit

## Apple primary sources

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [App privacy](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
