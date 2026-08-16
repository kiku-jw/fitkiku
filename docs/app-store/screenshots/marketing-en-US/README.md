# FitKiku App Store marketing screenshots

This directory contains the English 6.9-inch iPhone marketing deck prepared
for App Store Connect. The final upload files are the four opaque
`1320x2868` JPEGs in `iphone-6.9/`, in filename order.

The deck uses only deterministic synthetic app states from the raw source set
in `../en-US/`; it contains no owner health data, credentials, Pair Links, or
device identifiers. The copy deliberately stays within the shipped 1.0
behavior: read-only Steps and Sleep, explicit connection approval, bounded
foreground catch-up, freshness, and missing-data visibility.

## Source mapping

| Marketing file | Raw app screenshot |
|---|---|
| `01-hero.jpg` | `../en-US/01-first-run.jpg` |
| `02-device-bottom.jpg` | `../en-US/02-consent.jpg` |
| `03-device-top.jpg` | `../en-US/03-current-delivery.jpg` |
| `04-two-devices.jpg` | `../en-US/04-partial-delivery.jpg` plus `03-current-delivery.jpg` |

## Reproduction note

The layout was composed on 2026-08-16 in an isolated, patched copy of
`ParthJadhav/app-store-screenshots` at upstream commit
`e58f81961b5fd9e3969c680061f7cfd8f286ae55`. The upstream editor was not added
as a FitKiku dependency. Its temporary runtime was upgraded and audited before
use; `bun audit` reported no vulnerabilities and the production build passed.

To reproduce the composition, copy `app-store-screenshots.json`, the FitKiku
app icon, and the four raw screenshots into the editor paths referenced by the
project file. Export the iOS/iPhone set, then flatten the 1320x2868 output to an
opaque JPEG before upload. Recheck dimensions, alpha, spelling, thumbnail
readability, and that every product claim still matches the submitted binary.
