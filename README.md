# FitKiku

[![iOS CI](https://github.com/kiku-jw/fitkiku/actions/workflows/ios.yml/badge.svg)](https://github.com/kiku-jw/fitkiku/actions/workflows/ios.yml)

<img src="ios/FitKiku/FitKiku/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="160" alt="FitKiku app icon">

FitKiku is an Apple Health connector for personal AI agents. Its native iPhone
app gives an agent you approve recent, read-only Apple Health context after
explicit user approval.

The current product reads only daily Steps and Sleep. It shows the destination
before connection, keeps unknown or partial coverage visible, reports delivery
freshness, and lets the user revoke future access. The release-candidate source
also supports isolated anonymous guest pairing and authenticated in-app account
deletion without modifying Apple Health.

## Current status

FitKiku 1.0 (3) was uploaded, processed, selected, and submitted to App Review.
The last verified App Store Connect state was **Waiting for Review**; Apple
acceptance and public availability remain unconfirmed. The repository does **not** imply App Store
availability, guaranteed background delivery, medical fitness, broad agent
compatibility, or a generally available paid gateway.

Proved so far:

- native HealthKit authorization and foreground reads on a physical iPhone;
- explicit Pair Link review before device pairing;
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
- 68 deterministic simulator tests for pairing, storage, canonical JSON,
  retries, coverage, freshness, cold launch, and malformed responses;
- a real owner-iPhone foreground catch-up from stale state through current
  server confirmation and a bounded existing-agent read;
- live anonymous grant issuance with a credential-free Pair Link, denied reads
  before approval, agent self-revocation, and denied reads afterward;
- a machine-readable setup protocol that a capable HTTPS agent can follow
  without asking the person for a server URL, password, or API token.

Still unproved for a public reliability claim:

- reliable unattended background delivery;
- recovery after reboot and force-quit;
- locale-dynamic daily grouping; release 1.0 uses the `Europe/Kyiv` day
  boundary for all summaries;
- onboarding and retention with people outside the owner setup;
- an unaided external person's install -> Pair Link -> current answer flow;
- Apple acceptance and public App Store availability.

The iPhone companion is intended to remain free. An optional managed hosted
gateway is a later validation candidate, not a currently available service;
this repository contains no checkout or active subscription flow.

## Connect an agent

Send this setup prompt to your AI agent:

```text
Use FitKiku (https://kikuai.dev/fitkiku/) to connect my Apple Health Steps and Sleep to this agent. If you have a compatible FitKiku connection, return a FitKiku Pair Link for this iPhone. If not, say clearly that you cannot connect yet. Do not ask me for server passwords, API tokens, or a manual Apple Health export.
```

FitKiku currently works only through compatible FitKiku connections. It does
not yet support every AI agent or runtime. Capable agents can follow the exact
bounded protocol at <https://kikuai.dev/fitkiku.md>; agents that cannot make
HTTPS requests and securely store one bearer must fail honestly.

## Data boundary

FitKiku requests read access to:

- Steps;
- Sleep Analysis.

It does not write to Apple Health. The current schema sends daily step count,
daily asleep minutes, coverage, source metadata, and delivery metadata to the
HTTPS destination the user approves. Sleep interval timestamps and categories
stay on the iPhone.

Missing data is never converted to zero. FitKiku is not medical diagnosis,
treatment, clearance, or emergency care.

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
