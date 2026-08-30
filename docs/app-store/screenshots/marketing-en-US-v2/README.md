# FitKiku App Store marketing pack v2

This is a local-only English iPhone marketing pack for the next editable
FitKiku product page. It contains five opaque 1320x2868 JPEGs in
`iphone-6.9/`, ordered for App Store review. This task does not upload, remove,
or replace App Store Connect media.

## Narrative

1. **Steps + Sleep → your AI** — state the product result in one glance.
2. **No daily retyping** — kill the recurring manual-input pain.
3. **Consent** — make approval before sharing visible.
4. **Narrow scope** — show that only Steps and Sleep are shared read-only.
5. **Freshness** — make the partial-delivery state and missing-date warning
   visible instead of implying that every read is complete.

The deck uses a black/white base with a restrained cyan accent, three dark
slides, two light slides, and varied template layouts. No slide claims an
uptime SLA, medical result, continuous
background process, external-agent compatibility matrix, or proven retention.

## Source mapping

All phone imagery is deterministic synthetic app capture already checked into
the repository:

| Marketing file | Template slide | Raw source |
|---|---|---|
| `01-health-bridge.jpg` | hero | `../en-US/01-first-run.jpg` |
| `02-one-prompt.jpg` | device-bottom | `../en-US/01-first-run.jpg` |
| `03-consent.jpg` | device-top | `../en-US/02-consent.jpg` |
| `04-health-context.jpg` | two-devices | `../en-US/03-current-delivery.jpg` + `01-first-run.jpg` |
| `05-trust.jpg` | device-top trust card | `../en-US/04-partial-delivery.jpg` |

The source captures contain synthetic example values only. No owner Health
payload, credential, Pair Link, device identifier, or private service data was
used.

## Reproduction

The composition was regenerated on 2026-08-30 through the current local
`app-store-screenshots` skill template in a disposable directory. The skill
was not added as a FitKiku dependency. `bun install --frozen-lockfile` and
`bun run build` passed, and the editor reported a successful export of 20 PNGs:
five slides at 1320x2868, 1284x2778, 1206x2622, and 1125x2436.

The project state is `app-store-screenshots.json` with `schemaVersion: 2`,
locale `en`, device `iphone`, and `connectedCanvas: false`. Copy the four raw
captures into the template paths named by that JSON, copy the submitted 1024px
app icon to `/public/app-icon.png`, and add this theme to the template's
`THEMES` map before exporting:

```text
id: fitkiku-mono
bg: #F4F5F3
bgAlt: #05090A
fg: #111415
fgAlt: #F7FAFA
accent: #12BFCD
muted: #5B6164
```

The checked-in files were flattened from the 1320x2868 export to opaque JPEGs.
`file` and `sips` confirm RGB JPEG data, no alpha, and exact 1320x2868
dimensions for all five files. Full-size inspection and 420px storefront-
thumbnail inspection found no clipping, blank regions, private data, or
unreadable headlines.

The English raw capture set was regenerated from the benefit-led source with
an explicit `en_US` launch locale. A separate `ru_RU` capture set records the
complete Russian localization. Both use deterministic synthetic values; no
owner Health data or private capability was present.

## Draft status

This pack is prepared for the next editable App Store product page. Before a
future upload, re-check every claim against the exact binary being submitted.
