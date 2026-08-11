# FitKiku

<img src="ios/FitKiku/FitKiku/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="160" alt="FitKiku app icon">

FitKiku is an Apple Health connector for personal AI agents. Its native iPhone
app gives an agent you approve recent, read-only Apple Health context after
explicit user approval.

The current product reads only daily Steps and Sleep. It shows the destination
before connection, keeps unknown or partial coverage visible, reports delivery
freshness, and lets the user revoke future access.

## Current status

FitKiku is in private owner testing and App Store preparation. The public
repository contains the iOS client and its tests. It does **not** imply App Store
availability, public enrollment, guaranteed background delivery, medical
fitness, or a hosted gateway service for third parties.

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
- deterministic simulator tests for pairing, storage, canonical JSON, retries,
  coverage, freshness, and malformed responses.

Still under validation:

- reliable unattended background delivery;
- recovery after reboot and force-quit;
- onboarding and retention with people outside the owner setup;
- production gateway operations and App Store review.

The iPhone companion is intended to remain free. An optional managed hosted
gateway is a later validation candidate, not a currently available service;
this repository contains no checkout or active subscription flow.

## Connect an agent

Send this setup prompt to your AI agent:

```text
Use FitKiku (https://kikuai.dev/fitkiku/) to connect my Apple Health Steps and Sleep to this agent. If you have a compatible FitKiku connection, return a FitKiku Pair Link for this iPhone. If not, say clearly that you cannot connect yet. Do not ask me for server passwords, API tokens, or a manual Apple Health export.
```

FitKiku currently works only through compatible FitKiku connections. It does
not yet support every AI agent or runtime.

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
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "$FITKIKU_DERIVED_DATA" \
  test
```

The latest observer-lifecycle correction has passed build-for-testing and a
signed owner-device foreground recovery. Unattended delivery remains in the
validation list above rather than being presented as guaranteed.

The client also parses a future exact
`https://kikuai.dev/fitkiku/pair` entry point, but Universal Links are not
enabled in Personal Team builds. Public tap-to-app onboarding therefore
remains gated on the paid Apple capability, associated-domain file, and a
final signed archive.

## Product links

- Product: <https://kikuai.dev/fitkiku/>
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
