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
corpus/
  <date>_firmware-<version>/
    capture.json      provenance: when, which firmware, counts, integrity, verifications
    templates.json    the pristine stock manifest, no user entries merged
    stock/            templates reMarkable ships      ("author": "reMarkable")
    user/             the owner's custom templates    ("author": "DAdent")
    other/            anything unexpected (only present if the device had something new)
```

## Two rules

**1. Snapshots are never overwritten.** Each firmware gets its own directory. Keeping old
captures alongside new ones is what makes format drift *visible* — "did reMarkable change
the format?" becomes a question answered by diffing directories rather than by guessing.

**2. Stock and user templates stay separate.** The original ADR-0006 measurements
conflated them, reporting counts higher than the stock corpus warranted. Splitting by the
template's own `author` field makes that error structurally impossible to repeat.

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

If the content turns out identical to an existing snapshot, **do not create a duplicate
directory.** Add a `verifications[]` entry to the existing `capture.json` instead: the
useful information is "this firmware did not change anything," not a second copy of
identical bytes.

## Current snapshots

| Snapshot | Firmware | Stock | User | Manifest | Verified against |
|---|---|---|---|---|---|
| `2026-03-01_firmware-unknown` | unknown — not recorded | 65 | 3 | 79 entries | **3.29.1.0** and the release before it — byte-identical to both |

The stock corpus is byte-identical across **three firmware generations**, so one directory
serves all of them. `capture.json` carries the verification log.

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
