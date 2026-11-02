# Template Format Findings — November 2026 Corpus Refresh

*Status: **Proposed** — awaiting review.*
*2026-11-01 · Evidence: 65 stock `.template` files harvested from a reMarkable Paper Pro
across **two consecutive firmware updates**, the second confirmed as **3.29.1.0**.*

This document records where the observed `.template` format **differs from `PRD.md` §6**,
which was written from a partial reading of the March 2026 corpus. It feeds the PRD v2.0
revision and corrects two ADRs.

---

## 1. Headline result: three firmware generations, zero format drift

Two firmware updates landed in quick succession during this work, giving three captures in
total. **All three are byte-for-byte identical.**

| Capture | Firmware | Result |
|---|---|---|
| 2026-03-01 | not recorded (older) | baseline |
| 2026-11-01 #1 | not recorded — the release preceding 3.29.1.0 | **identical** |
| 2026-11-01 #2 | **3.29.1.0** (post-reboot, version confirmed) | **identical** |

| Check | Result |
|---|---|
| Stock template files | 65 → 65 → 65, no additions, no removals |
| Files with changed content | **0** |
| `templates.json` | identical, 11,949 bytes, 79 entries |
| Aggregate SHA-256 of all 66 files | `d23ec580327e03086bc81448cc93912c` — **identical across all three** |
| `formatVersion` | `1`, unchanged |
| JSON key set | **no differences** |
| Item type counts | unchanged (`path` 118, `group` 115, `text` 60) |
| Path command counts | unchanged (`L` 382, `C` 260, `M` 233, `Z` 54) |

**What this does and does not tell us.** Three captures across three firmware generations
is meaningfully stronger than a single observation, but it is still not proof of
stability — reMarkable can change the format whenever it likes, and `formatVersion`
exists precisely so they can. What it does establish is that the format is **not
volatile**, so the corpus is a sound basis for the Domain design and the refresh is a
cheap, occasional check rather than a constant tax.

Both updates wiped the owner's custom templates while leaving every stock template
untouched. That is exactly the product's reason to exist (`PRD.md` §4.6): **updates
discard user templates while leaving stock templates intact** — now observed twice rather
than assumed.

### Capture #2 was natively pristine

Capture #1 required cleanup: the custom templates had already been re-applied, so they
were removed and the saved-aside stock manifest restored to recover a comparable state.
Capture #2 was taken *before* re-applying, so it is a genuine untouched post-update state
— 65 stock templates, no user entries in the manifest. That makes it the better evidence
of the two, and the sequencing is now recorded in the corpus README as the way to do it.

## 2. A measurement error in ADR-0006, corrected

ADR-0006's evidence table counted some features across **stock plus the owner's three
custom templates**, and others across stock only — without saying which. The corrected
stock-only figures:

| Feature | ADR-0006 as written | Stock-only (correct) | Note |
|---|---|---|---|
| `path` items | 128 | **118** | was stock + user |
| `group` items | 124 | **115** | was stock + user |
| `text` items | 67 | **60** | was stock + user |
| `templateWidth` | 420 | **384** | was stock + user |
| `templateHeight` | 239 | **217** | was stock + user |
| `parentWidth` | 82 | **76** | was stock + user |
| `parentHeight` | 26 | **23** | was stock + user |
| `paperOriginX` | 2 | **2** | unchanged |
| Ternary files | 55 of 65 | **55 of 65** | was already stock-only |
| `<` / `>` / `\|\|` | 131 / 91 / 24 | **131 / 91 / 24** | was already stock-only |
| `&&` `==` `!=` `<=` `>=` | 0 | **0** | unchanged |

**None of ADR-0006's conclusions change.** The grammar is the same shape, ternaries are
still pervasive, and the absent operators are still absent. But the counts were not
measuring what they claimed to, and a corpus-derived decision has to state its scope
precisely. Stock and user templates are now stored in separate directories so this
cannot recur.

## 3. The PRD's item schema is incomplete

This is the substantive finding. `PRD.md` §6.5 documents three item types — correct — but
understates the fields they carry, and §6.1 misses two top-level keys.

### 3.1 Undocumented top-level keys

| Key | Files | Observed values | Why it matters |
|---|---|---|---|
| `supportedDevices` | **16 of 65** | always `["rm2","rmPP"]` | A device-compatibility gate. Feeds `CompatibilityPolicy` and validation: a template may legitimately declare which hardware it supports. All 16 are music or storyboard templates. |
| `iconData` | 1 (`P Lines large`) | the literal string `"None"` | Almost certainly a defect in reMarkable's own tooling — a Python `None` serialized as text. **Validation must tolerate it**: this file ships on the device and must not be reported as invalid. |

### 3.2 Undocumented `path` item fields

| Field | Occurrences | Observed values |
|---|---|---|
| `fillColor` | 13 | `#000000` ×12, `#ffffff` ×1 |
| `strokeWidth` | 10 | *(documented in the PRD)* |
| `antialiasing` | 6 | `false` |
| `strokeColor` | 2 | `#000000`, `#00000000` |

Three consequences:

1. **Paths are filled, not just stroked.** A renderer that only draws lines produces
   visibly wrong output for 13 paths.
2. **Colour is real.** The Paper Pro is a colour e-ink device and stock templates use
   colour. `#00000000` is 8-digit RGBA — **fully transparent** — so alpha must be parsed,
   not just RGB.
3. `antialiasing: false` is a rendering hint that must be carried through to the drawing
   layer, not resolved away.

### 3.3 Path data uses more than `M` and `L`

`PRD.md` §6.5 says path `data` holds "SVG-like path commands (M = moveTo, L = lineTo)."
The corpus contains four commands:

| Command | Occurrences | Meaning | Where |
|---|---|---|---|
| `L` | 382 | lineTo | everywhere |
| `C` | **260** | **cubic Bézier** | the 6 piano-sheet templates (clef glyphs) |
| `M` | 233 | moveTo | everywhere |
| `Z` | **54** | **close path** | **25 of 65 files** |

`Z` appearing in 25 files makes closed subpaths mainstream, not an edge case — it is how
dots, checkboxes, and storyboard corners are drawn. `C` is confined to six files, but
those six are unrenderable without cubic Bézier support.

## 4. Required corrections

### 4.1 ADR-0007 — `RenderPlan` is under-specified

ADR-0007 defines `RenderPlan` as "absolute-positioned line segments with stroke widths,
and text runs with resolved positions and font sizes." That is not sufficient to render
this corpus. It must also carry:

- **cubic Bézier segments** (control points), not only straight segments
- **subpath structure** with an explicit closed flag, so `Z` can be honoured
- **fill** as a distinct concept from stroke, with fill colour
- **stroke colour**, parsed as RGBA including the transparent case
- **the antialiasing hint**

Caught before any code was written, which is the point of reviewing the evidence first.
The split in ADR-0007 — pure Domain layout, dumb UI renderer — is unaffected and holds;
only the display-list shape changes.

### 4.2 ADR-0006 — unblocking

ADR-0006's two blocking concerns are now answered: the corpus is current, and the format
did not drift. Its evidence table needs the §2 corrections, and its "only three item
types" conclusion should be narrowed to say explicitly that it constrains item *types*,
not item *fields* — §3.2 shows the fields are richer than documented.

### 4.3 PRD v2.0

Amend §6.1 (add `supportedDevices`, `iconData`), §6.5 (path fields, path commands), and
§7.2 (preview must render fills, curves, and colour).

## 5. Where the firmware version actually lives — and a script bug it caught

Reading the device metadata by hand produced the single most useful operational finding
of this exercise.

```
IMG_VERSION="3.29.1.0"                      <- the reMarkable release version
VERSION_ID=6.0.112                          <- Codex Linux (OpenEmbedded) -- NOT firmware
PRETTY_NAME="Codex Linux 6.0.112 (wrynose)"
/etc/version          -> 20261028104944     <- build stamp
/usr/share/remarkable/update.conf           -> does not exist on this firmware
uname                 -> Linux imx8mm-ferrari 6.12.49 aarch64
```

Three things follow:

1. **`IMG_VERSION` is the firmware version.** `VERSION_ID` is the underlying Linux
   distribution's version. (The distro is confusingly named "Codex Linux" — reMarkable's
   OpenEmbedded build, entirely unrelated to the Codex CLI used as a reviewer in
   [ADR-0009](architecture/decisions/0009-two-model-ai-review-chain.md).)
2. **`update.conf` does not exist** on 3.29.1.0, so it cannot be the primary source.
3. **`tools/Get-DeviceTemplateCorpus.ps1` had a real bug.** It tried `update.conf` first,
   then **`VERSION_ID`** — so on this device it would have labelled the snapshot
   **`6.0.112`**, the OS version rather than the firmware. Every future snapshot would
   have carried a wrong, plausible-looking label, and the error would have been invisible
   until someone tried to reason about drift. The candidate order is now `IMG_VERSION`
   first, `VERSION_ID` is explicitly excluded with a comment explaining why, and the OS
   version is recorded separately as `hostOsVersion`.

That bug was only exposed by running the commands against a real device and reading the
output. It is a good argument for harvesting evidence early, before anything depends on it.

## 6. Capture provenance and remaining caveats

- **Capture #2 is the strong one:** taken directly off the device before any
  re-application, so 65 stock templates and a manifest with no user entries, exactly as
  the firmware left it.
- **Capture #1's manifest provenance is indirect** — it is the copy the owner's own
  update script saves aside, restored into place. Consistent with everything else, but
  capture #2 supersedes it as evidence.
- **Two firmware versions remain unrecorded** (the March baseline and capture #1). Both
  are unrecoverable; the device has moved on. This is exactly the defect the refresh
  requirement exists to prevent, and it is why `capture.json` records them as explicitly
  `null` with a note rather than quietly omitting the field.
- **The harvest script is still unverified end-to-end.** It failed on first use and the
  files were collected manually with `scp` instead; at the owner's direction that failure
  was not debugged, since the manual path was quick. The firmware-detection bug above is
  fixed, but the script has not been run successfully against a device. **It must not be
  trusted until it has been**, and the next firmware update is the opportunity.
