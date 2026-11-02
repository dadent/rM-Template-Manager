# Template corpus

Firmware-versioned snapshots of `/usr/share/remarkable/templates` harvested from a real
reMarkable Paper Pro.

This corpus is the **evidence base for the Domain design**. The expression grammar
([ADR-0006](../../../docs/architecture/decisions/0006-expression-grammar-scope.md)), the
item-type set, the `RenderPlan` shape
([ADR-0007](../../../docs/architecture/decisions/0007-preview-rendering.md)), and the
validation rules are all derived from what is in here — not from guesswork. It later
becomes the golden-file fixture set for the test suite.

## Layout

```
research/reference_material/
  user_templates/           the owner's custom templates ("author": "DAdent")
                            NOT in any snapshot -- see rule 3
  corpus/
    <date>_firmware-<version>/
      capture.json          provenance: when, which firmware, counts, integrity, format
      templates.json        the stock manifest as the firmware left it
      stock/                templates reMarkable ships ("author": "reMarkable")
      other/                anything unexpected (present only if the device had something new)
```

## Three rules

**1. One directory per firmware, never overwritten.** Including when the content turns out
identical. The directory name is the index — if someone cannot find the corpus for
firmware *X* by looking at directory names, the scheme has failed, and burying the version
inside `capture.json` does exactly that. Git stores identical content once, so a snapshot
whose files match an existing one **costs no repository storage** — only tree entries.
There is therefore no reason to skip it.

**2. Stock and user templates stay separate.** The original ADR-0006 measurements
conflated them and reported counts higher than the stock corpus warranted. Splitting by
the template's own `author` field makes that error structurally impossible to repeat.

**3. User templates live outside the corpus entirely.** They are the owner's authored
files, not firmware artefacts — they do not change when the device updates. Filing them
under a snapshot was a category error that would have forced them to be duplicated into
every future snapshot. They live in `research/reference_material/user_templates/`.

## Which snapshot to use

**Use the canonical one** — the most recent snapshot with a known firmware version and
clean provenance, flagged `"isCanonical": true` in its `capture.json`. It is the
golden-file fixture source for the test suite. Older snapshots are kept as historical
baselines and for drift diffs, not as the working reference.

## Refreshing after a firmware update

```powershell
.\tools\Get-DeviceTemplateCorpus.ps1
```

Read-only with respect to the device: no remount, no writes, no reboot.

Do this after **every** firmware update. The device is the only source of truth for this
format, which is undocumented and reverse-engineered, so an update is the only moment the
format can change under us.

**Capture before re-applying your own templates.** A capture taken straight after the
update is natively pristine — stock templates only, no user entries in the manifest. If
you re-apply first, you have to remove the custom templates and restore a saved-aside
manifest to get back to a comparable state, which makes the capture's provenance weaker.

> **The script has never completed a successful run.** It failed on first use and all
> three captures to date were taken manually with
> `scp "root@10.11.99.1:/usr/share/remarkable/templates/*" .`
> A firmware-detection bug found by inspecting real device output has been fixed, but the
> script is otherwise unexercised. Don't trust it until it has worked once.

**Always record the firmware version.** A snapshot without it cannot support any argument
about drift — which is precisely why the March 2026 capture is labelled
`firmware-unknown`, and why that was logged as a defect rather than quietly tolerated.

**Create the directory even when the content is identical** (rule 1). Record the
comparison result in `capture.json` under `comparisonToPreviousSnapshot` and mark the new
snapshot canonical. An identical snapshot is still evidence — it is how "the format did
not change in release *X*" becomes a checkable fact rather than a memory.

The only case for *not* creating a directory is **weak provenance**: a capture that needed
cleanup to be comparable, or whose firmware version was never recorded, cannot serve as a
reference. Log it as a `verifications[]` entry on the snapshot it was compared against
instead. That is why the release between the March and 3.29.1.0 captures has no directory
of its own.

## Current snapshots

| Snapshot | Firmware | Stock | Manifest | Role |
|---|---|---|---|---|
| `2026-11-01_firmware-3.29.1.0` | **3.29.1.0** | 65 | 79 entries | **Canonical** — known firmware, natively pristine capture |
| `2026-03-01_firmware-unknown` | unknown — not recorded | 65 | 79 entries | Historical baseline; firmware unknown, manifest provenance indirect |

Both are **byte-identical** (aggregate `d23ec580…`), and a third capture — the release
between them — was also identical and is recorded as a verification entry in the March
snapshot rather than as its own directory, because its provenance was indirect.

So: the stock corpus has not changed across **three firmware generations**.

## Finding the firmware version

**Use `IMG_VERSION` from `/etc/os-release`.** On firmware 3.29.1.0:

```
IMG_VERSION="3.29.1.0"                 <- the reMarkable release version. Use this.
VERSION_ID=6.0.112                     <- Codex Linux (OpenEmbedded). NOT the firmware.
/etc/version -> 20261028104944         <- build stamp, usable as a last resort
/usr/share/remarkable/update.conf      <- does not exist on this firmware
```

`VERSION_ID` is the underlying Linux distribution's version and must never be used as the
firmware label — it is plausible-looking and wrong, which is the worst kind of wrong. The
harvest script originally preferred it and would have labelled this snapshot `6.0.112`.

## What the corpus currently establishes

- `formatVersion` is `1` on all 65 stock templates.
- Exactly three item types: `group`, `path`, `text`.
- Path data uses four commands: `M`, `L`, `C` (cubic Bézier), `Z` (close path).
- Paths carry `fillColor`, `strokeColor`, `strokeWidth` and `antialiasing` — so the
  renderer needs fills and colour, not just strokes.
- 16 templates declare `supportedDevices: ["rm2","rmPP"]`.
- One template (`P Lines large`) has `"iconData": "None"` — a literal string, almost
  certainly a bug in reMarkable's own tooling. Validation must tolerate it, because it
  ships on the device.

Full analysis: [`docs/template-format-findings.md`](../../../docs/template-format-findings.md).
