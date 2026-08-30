# FitKiku

[![iOS CI](https://github.com/kiku-jw/fitkiku/actions/workflows/ios.yml/badge.svg)](https://github.com/kiku-jw/fitkiku/actions/workflows/ios.yml)

<img src="ios/FitKiku/FitKiku/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="160" alt="FitKiku app icon">

[Download FitKiku on the App Store](https://apps.apple.com/app/id6801516904)

FitKiku lets the AI you already use take your recent Steps and Sleep into
account. Its native iPhone app privately delivers those two read-only
categories to ChatGPT or another AI that can open links, after explicit user
approval.

FitKiku remains a separate data product. It is not an AI coach, does not expose
everything in Apple Health, and does not promise real-time delivery.

The current product reads only daily Steps and Sleep. Released version 1.0
supports explicit agent pairing, visible delivery freshness, revocation, and
anonymous in-app account deletion without modifying Apple Health. The next 1.1
source candidate replaces the normal pairing ceremony with one app-created,
private, revocable link and a prepared message for the user's AI.

## Current status

FitKiku 1.0 is available free on the App Store in the configured non-EU
storefronts. Apple's public catalog reports version 1.0 and a 2026-08-27 release
date for App ID `6801516904`. EU-27 storefronts remain intentionally disabled
while their separate legal and tax boundary is unresolved. Publication proves
distribution only; it does not establish reliable background delivery,
external retention, broad agent compatibility, demand, or payment.

Proved so far:

- native HealthKit authorization and foreground reads on a physical iPhone;
- explicit Pair Link review before device pairing, retained as an advanced
  compatibility flow;
- signed daily aggregate delivery and server confirmation;
- bounded read-only agent access and revocation;
- sleep attribution by the Europe/Kyiv wake date, including exclusion of
  previous-day naps from the next daily summary;
- fail-closed disconnect cleanup: a new destination cannot be paired while a
  protected local outbox or revoked credential remains;
- HealthKit observer queries installed during application initialization, before
  asynchronous connection restore;
- ordinary foreground refresh preserves observer registration while explicit
  disconnect still stops it;
- cold HealthKit wakes use launch-time pairing state without starting the
  foreground UI catch-up, skip reads while protected data is unavailable, and
  leave failed updates in the existing protected retry queue;
- background work requests HealthKit's earliest supported opportunity but is
  bounded to two local days, one upload attempt per day, and an exactly-once
  completion deadline;
- 74 deterministic simulator tests in both English and Russian for pairing,
  private-link rotation and revocation, storage, canonical JSON, retries,
  coverage, freshness, cold launch, and malformed responses;
- a real owner-iPhone foreground catch-up from stale state through current
  server confirmation and a bounded existing-agent read;
- live anonymous grant issuance with a credential-free Pair Link, denied reads
  before approval, agent self-revocation, and denied reads afterward;
- an app-led ChatGPT flow that asks for no server URL, password, Pair Link, or
  setup code, plus a machine-readable protocol for compatible advanced agents.

Still unproved for a public reliability claim:

- reliable unattended background delivery;
- recovery after reboot and force-quit;
- locale-dynamic daily grouping; release 1.0 uses the `Europe/Kyiv` day
  boundary for all summaries;
- onboarding and retention with people outside the owner setup;
- an unaided external person's install -> private link -> current answer flow;
- demand or payment for an optional hosted gateway.

The iPhone companion is intended to remain free. An optional managed hosted
gateway is a later validation candidate, not a currently available service;
this repository contains no checkout or active subscription flow.

## Connect ChatGPT

In the 1.1 source candidate, the normal flow happens inside the iPhone app:

1. Tap **Connect ChatGPT**.
2. Review the read-only Steps and Sleep scope and create the connection.
3. Allow Steps and Sleep in Apple Health.
4. Tap **Copy for ChatGPT** and paste the complete prepared message into a
   private ChatGPT chat.

The prepared message already contains the user's actual private URL. It tells
the AI to open that normal HTTPS JSON URL again before relevant answers about
activity, sleep, recovery, or routine, report freshness, preserve missing
values as unknown, and never repeat the URL. No native FitKiku connector or
Pair Link is required for this path; the AI only needs the ability to open
HTTPS links.

The URL is a bearer credential. Anyone who receives it can read the bounded
recent summary until the user replaces or revokes the link in FitKiku Settings.
This is pull-on-request over the latest server-confirmed snapshot after iOS has
synced, not continuous real-time delivery. Advanced agents can still follow the
bounded protocol at <https://kikuai.dev/fitkiku.md>.

## Data boundary

FitKiku requests read access to:

- Steps;
- Sleep Analysis.

It does not write to Apple Health. The current schema sends daily step count,
daily asleep minutes, coverage, source metadata, and delivery metadata to the
HTTPS destination the user approves. Sleep interval timestamps and categories
stay on the iPhone.

Missing data is never converted to zero. FitKiku is not medical diagnosis,
treatment, clearance, emergency care, or a built-in AI coach.

Release 1.0 assigns each daily summary to the `Europe/Kyiv` calendar. Users
whose ordinary day boundary differs should treat multi-timezone grouping as an
unproved later capability, not as part of this release.

## Build the iOS app

Requirements:

- macOS with Xcode;
- iOS 17 or later;
- an iPhone for real HealthKit permission and data checks.

1. Open `ios/FitKiku/FitKiku.xcodeproj`.
2. Select the `FitKiku` target.
3. Choose your own Personal Team and a unique bundle identifier.
4. Keep both HealthKit entitlements enabled.
5. Build for the simulator or your connected iPhone.

Simulator tests do not prove real HealthKit authorization or background
delivery. To run the deterministic test suite without writing DerivedData into
the repository:

```bash
FITKIKU_DERIVED_DATA="$(mktemp -d /tmp/fitkiku-public-tests.XXXXXX)"
xcodebuild \
  -project ios/FitKiku/FitKiku.xcodeproj \
  -scheme FitKiku \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath "$FITKIKU_DERIVED_DATA" \
  -parallel-testing-enabled NO \
  test
```

Keep normal Simulator ad-hoc signing enabled. Disabling code signing removes
the Keychain entitlement and invalidates protected-store tests.

The submitted build-3 source has passed 68/68 full Simulator tests, Release
analysis, archive inspection, and the physical reviewer flow. The earlier
fixed server-first window was closed without enough elapsed evidence;
unattended regularity remains inconclusive and stays in the validation list
above rather than being presented as guaranteed.

The next 1.1 (4) source candidate passes 74/74 Simulator tests in English and
74/74 in Russian. Its exact production deployment, physical ordinary-ChatGPT
fetch/revoke sequence, signed archive, upload, Apple review, and release remain
separate gates.

The 1.0 connection flow uses the registered `fitkiku-health://` custom URL
scheme. The client also parses a future exact
`https://kikuai.dev/fitkiku/pair` entry point, but Universal Links and the
Associated Domains entitlement remain deliberately deferred.

## Product links

- Product: <https://kikuai.dev/fitkiku/>
- Agent setup protocol: <https://kikuai.dev/fitkiku.md>
- Privacy: <https://kikuai.dev/fitkiku/privacy/>
- Support: <https://kikuai.dev/fitkiku/support/>
- Development notes: <https://t.me/kiku_ai>
- Author: <https://github.com/kiku-jw>

## Security and privacy reports

Read [SECURITY.md](SECURITY.md). Never include health values, Health source
identifiers, Pair Links, credentials, private server addresses, or raw logs in
a public issue.

## Source boundary

This is a clean public history for the product-facing iOS client. The private
owner bot, operational credentials, physical reliability ledger, and historical
research workspace are intentionally not published here.

## License

FitKiku uses a narrow mixed-license boundary:

- the iOS client and its tests use [MPL-2.0](LICENSES/MPL-2.0.txt), so
  distributed changes to those source files remain open while they can still
  be combined with separately licensed software;
- public schemas and synthetic fixtures use
  [Apache-2.0](LICENSES/Apache-2.0.txt) for straightforward reuse by agent and
  gateway implementers; and
- the FitKiku name and official app icon are not included in those software
  license grants.

Read [LICENSE](LICENSE) for the exact path boundary and
[TRADEMARKS.md](TRADEMARKS.md) for the brand policy. Earlier Git revisions
published under AGPL-3.0 remain available under the grants already made for
those revisions.
