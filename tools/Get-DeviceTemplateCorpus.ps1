<#
.SYNOPSIS
    Harvests the template corpus from a connected reMarkable Paper Pro into a
    firmware-versioned snapshot in this repository.

.DESCRIPTION
    This is the repeatable corpus refresh required by ADR-0006. The expression grammar,
    the item-type set, and the validation rules are all derived from the corpus, so the
    corpus must be current and must record which firmware produced it.

    The script is STRICTLY READ-ONLY with respect to the device. It never remounts the
    filesystem, never writes, never reboots. It runs two commands: one to read metadata,
    one to copy files down.

    Re-run this after every firmware update. Snapshots are stored per firmware version
    rather than overwritten, so format drift between releases stays visible and
    diffable.

.PARAMETER DeviceIP
    Device address. Defaults to the USB address 10.11.99.1.

.PARAMETER Force
    Overwrite an existing snapshot for the same firmware version.

.PARAMETER AcceptNewHostKey
    Use ssh's 'accept-new' policy: unknown host keys are accepted automatically, but a
    CHANGED key is still refused. Useful because a factory reset or firmware update can
    regenerate the device's host key. Deliberately NOT the default -- ADR-0005 requires
    that host keys are never blind-accepted silently.

.EXAMPLE
    .\tools\Get-DeviceTemplateCorpus.ps1

.EXAMPLE
    .\tools\Get-DeviceTemplateCorpus.ps1 -AcceptNewHostKey -Force

.NOTES
    Credentials: this script never collects, stores, or passes your password. ssh and scp
    prompt for it directly, so it never enters PowerShell memory, a variable, a command
    line, or a log. You will be prompted twice -- once per connection. That is the
    intended trade-off (see ADR-0005: OpenSSH on Windows has no non-interactive password
    mechanism, which is precisely why the application itself uses SSH.NET instead).
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string] $DeviceIP = '10.11.99.1',
    [string] $DeviceUser = 'root',
    [switch] $Force,
    [switch] $AcceptNewHostKey
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$DeviceTemplateDir = '/usr/share/remarkable/templates'
$RepoRoot    = Split-Path -Parent $PSScriptRoot
$CorpusRoot  = Join-Path $RepoRoot 'research/reference_material/corpus'
$KnownHosts  = Join-Path $RepoRoot 'known_device_hosts'   # git-ignored

function Write-Step { param([string] $Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Note { param([string] $Message) Write-Host "    $Message" -ForegroundColor DarkGray }
function Write-Good { param([string] $Message) Write-Host "    $Message" -ForegroundColor Green }

# ssh/scp options shared by both connections.
$SshOpts = @(
    '-o', "UserKnownHostsFile=$KnownHosts"
    '-o', 'ConnectTimeout=10'
)
if ($AcceptNewHostKey)
{
    # 'accept-new' trusts an UNKNOWN key but still refuses a CHANGED one.
    $SshOpts += @('-o', 'StrictHostKeyChecking=accept-new')
}

#-----------------------------------------------------------------------------------
# 1. Reachability
#-----------------------------------------------------------------------------------

Write-Step "Checking that $DeviceIP is reachable on port 22"

$probe = New-Object System.Net.Sockets.TcpClient
try
{
    $connected = $probe.ConnectAsync($DeviceIP, 22).Wait(5000)
    if (-not $connected)
    {
        throw "No SSH response from $DeviceIP within 5 seconds."
    }
    Write-Good 'Device is listening on port 22.'
}
catch
{
    Write-Host @"

    Could not reach $DeviceIP on port 22.

    Check that:
      - the device is connected by USB and powered on
      - Developer Mode is enabled (Settings > General > Software > Advanced)
      - the USB network adapter came up on the host
      - the address is right (USB is 10.11.99.1; over Wi-Fi pass -DeviceIP)
"@ -ForegroundColor Yellow
    throw
}
finally
{
    $probe.Dispose()
}

#-----------------------------------------------------------------------------------
# 2. Device metadata (connection 1 of 2)
#-----------------------------------------------------------------------------------

Write-Step 'Reading device metadata'
Write-Note 'You will be prompted for the device password.'
Write-Note 'Find it under Settings > Help > Copyrights & Licenses on the device.'

# Firmware version lives in different places across releases, so read every candidate
# and let the parser below pick. Each is guarded so a missing file is not fatal.
$remoteMetadataScript = @'
echo "### os-release"
cat /etc/os-release 2>/dev/null || echo "(absent)"
echo "### update.conf"
cat /usr/share/remarkable/update.conf 2>/dev/null || echo "(absent)"
echo "### etc-version"
cat /etc/version 2>/dev/null || echo "(absent)"
echo "### uname"
uname -a 2>/dev/null || echo "(absent)"
echo "### model"
cat /sys/devices/soc0/machine 2>/dev/null || echo "(absent)"
echo "### battery"
cat /sys/class/power_supply/*/capacity 2>/dev/null | head -1 || echo "(absent)"
echo "### disk"
df -h / 2>/dev/null || echo "(absent)"
echo "### template-dir-listing"
ls -la "/usr/share/remarkable/templates" 2>/dev/null || echo "(absent)"
echo "### template-file-count"
ls -1 "/usr/share/remarkable/templates"/*.template 2>/dev/null | wc -l
'@

$metadataRaw = $remoteMetadataScript | & ssh @SshOpts "$DeviceUser@$DeviceIP" 'sh -s'
if ($LASTEXITCODE -ne 0)
{
    throw "Metadata read failed (ssh exit $LASTEXITCODE). If ssh reported a changed host key, the device likely regenerated it after the update; remove the stale entry from '$KnownHosts' or re-run with -AcceptNewHostKey."
}

$metadataText = $metadataRaw -join "`n"

function Get-MetadataSection
{
    param([string] $Name)

    # Built by concatenation, not interpolation: a '$(' inside a double-quoted
    # PowerShell string is a subexpression, which would mangle the regex.
    $pattern = '(?sm)^### ' + [regex]::Escape($Name) + '\r?$(.*?)(?=^### |\z)'

    $found = [regex]::Match($metadataText, $pattern)
    if ($found.Success)
    {
        return $found.Groups[1].Value.Trim()
    }
    return ''
}

# Candidate order matters, and is based on what firmware 3.29.1.0 actually reports.
#
# IMPORTANT: do NOT use os-release VERSION_ID as the firmware version. On this device
# that field is the underlying Codex Linux (OpenEmbedded) version -- 6.0.112 on firmware
# 3.29.1.0 -- not the reMarkable release. An earlier version of this script preferred it
# and would have labelled the corpus '6.0.112', which is wrong and permanently
# misleading. IMG_VERSION is the reMarkable release version.
#
# /usr/share/remarkable/update.conf does not exist on 3.29.1.0; it is kept as a fallback
# only because older firmware may still carry it.
$firmwareVersion = $null
$firmwareSource  = $null

foreach ($candidate in @(
        @{ Section = 'os-release' ; Pattern = '(?m)^IMG_VERSION\s*=\s*"?([^"\r\n]+)"?' ; Source = '/etc/os-release IMG_VERSION' }
        @{ Section = 'update.conf'; Pattern = 'REMARKABLE_RELEASE_VERSION\s*=\s*(.+)'  ; Source = '/usr/share/remarkable/update.conf' }
        @{ Section = 'etc-version'; Pattern = '^(\d+)'                                 ; Source = '/etc/version build stamp' }
    ))
{
    $section = Get-MetadataSection -Name $candidate.Section
    if ($section -and $section -ne '(absent)')
    {
        $m = [regex]::Match($section, $candidate.Pattern)
        if ($m.Success)
        {
            $firmwareVersion = $m.Groups[1].Value.Trim()
            $firmwareSource  = $candidate.Source
            break
        }
    }
}

if (-not $firmwareVersion)
{
    Write-Host "`n    Could not determine the firmware version from any known location." -ForegroundColor Yellow
    Write-Host '    Raw metadata follows so the snapshot can still be labelled by hand:' -ForegroundColor Yellow
    Write-Host $metadataText
    $firmwareVersion = Read-Host 'Enter a label for this snapshot (e.g. 3.29.0.1234)'
    $firmwareSource  = 'entered manually'
    if (-not $firmwareVersion) { throw 'No snapshot label given; aborting.' }
}

# Make the version safe for a directory name.
$firmwareLabel = ($firmwareVersion -replace '[^\w\.\-]', '_')

Write-Good "Firmware: $firmwareVersion  (from $firmwareSource)"

# Captured for the record, and explicitly NOT used as the firmware version -- see the
# comment on the candidate list above.
$osRelease = Get-MetadataSection -Name 'os-release'
$osVersion = $null
$osMatch = [regex]::Match($osRelease, '(?m)^PRETTY_NAME\s*=\s*"?([^"\r\n]+)"?')
if ($osMatch.Success)
{
    $osVersion = $osMatch.Groups[1].Value.Trim()
    Write-Note "Host OS: $osVersion (not the firmware version)"
}

$deviceFileCount = (Get-MetadataSection -Name 'template-file-count').Trim()
Write-Good "Device reports $deviceFileCount .template files."

#-----------------------------------------------------------------------------------
# 3. Snapshot destination
#-----------------------------------------------------------------------------------

$captureDir = Join-Path $CorpusRoot $firmwareLabel

if ((Test-Path $captureDir) -and -not $Force)
{
    throw "A snapshot for firmware '$firmwareLabel' already exists at '$captureDir'. Re-run with -Force to replace it."
}

Write-Step "Snapshot destination: research/reference_material/corpus/$firmwareLabel"

if (Test-Path $captureDir) { Remove-Item $captureDir -Recurse -Force }
$null = New-Item -ItemType Directory -Path $captureDir -Force

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "rmcorpus-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $stagingDir -Force

#-----------------------------------------------------------------------------------
# 4. Copy the template directory down (connection 2 of 2)
#-----------------------------------------------------------------------------------

try
{
    Write-Step 'Copying templates from the device'
    Write-Note 'You will be prompted for the password a second time (one prompt per connection).'

    & scp @SshOpts -r "${DeviceUser}@${DeviceIP}:$DeviceTemplateDir/." $stagingDir
    if ($LASTEXITCODE -ne 0)
    {
        throw "scp failed (exit $LASTEXITCODE)."
    }

    $pulled = Get-ChildItem -Path $stagingDir -File -Recurse
    Write-Good "Pulled $($pulled.Count) files."

    #-------------------------------------------------------------------------------
    # 5. Sort into stock / user by the template's own author field
    #-------------------------------------------------------------------------------

    Write-Step 'Sorting templates by author'

    $stockDir = Join-Path $captureDir 'stock'
    $userDir  = Join-Path $captureDir 'user'
    $oddDir   = Join-Path $captureDir 'unclassified'
    $null = New-Item -ItemType Directory -Path $stockDir, $userDir -Force

    $records     = [System.Collections.Generic.List[object]]::new()
    $stockCount  = 0
    $userCount   = 0
    $oddCount    = 0
    $parseErrors = [System.Collections.Generic.List[string]]::new()

    foreach ($file in ($pulled | Where-Object { $_.Extension -eq '.template' } | Sort-Object Name))
    {
        $author       = $null
        $templateName = $null
        $formatVersion = $null

        try
        {
            $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8 | ConvertFrom-Json
            $author        = $json.author
            $templateName  = $json.name
            $formatVersion = $json.formatVersion
        }
        catch
        {
            # A parse failure is itself a finding: it may mean the format changed.
            $parseErrors.Add("$($file.Name): $($_.Exception.Message)")
        }

        if ($author -eq 'reMarkable')
        {
            $classification = 'stock'
            $destination    = $stockDir
            $stockCount++
        }
        elseif ($author)
        {
            $classification = 'user'
            $destination    = $userDir
            $userCount++
        }
        else
        {
            $classification = 'unclassified'
            $destination    = $oddDir
            $oddCount++

            if (-not (Test-Path $oddDir))
            {
                $null = New-Item -ItemType Directory -Path $oddDir -Force
            }
        }

        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) -Force

        $records.Add([ordered]@{
            filename      = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            file          = $file.Name
            name          = $templateName
            author        = $author
            formatVersion = $formatVersion
            bytes         = $file.Length
            sha256        = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            classified    = $classification
        })
    }

    Write-Good "stock: $stockCount    user: $userCount    unclassified: $oddCount"

    if ($parseErrors.Count -gt 0)
    {
        Write-Host "`n    $($parseErrors.Count) template(s) failed to parse as JSON:" -ForegroundColor Yellow
        $parseErrors | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
        Write-Host '    This may indicate a format change in this firmware. Worth investigating.' -ForegroundColor Yellow
    }

    #-------------------------------------------------------------------------------
    # 6. The manifest, kept at the snapshot root
    #-------------------------------------------------------------------------------

    $manifestSource = $pulled | Where-Object { $_.Name -eq 'templates.json' } | Select-Object -First 1
    $manifestEntryCount = $null

    if ($manifestSource)
    {
        Copy-Item -LiteralPath $manifestSource.FullName -Destination (Join-Path $captureDir 'templates.json') -Force
        try
        {
            $manifest = Get-Content -LiteralPath $manifestSource.FullName -Raw -Encoding utf8 | ConvertFrom-Json
            $manifestEntryCount = @($manifest.templates).Count
            Write-Good "templates.json captured: $manifestEntryCount manifest entries."
        }
        catch
        {
            Write-Host '    templates.json did not parse. Captured verbatim anyway.' -ForegroundColor Yellow
        }
    }
    else
    {
        Write-Host '    WARNING: templates.json was not found on the device.' -ForegroundColor Yellow
    }

    # Any other files that came down (icons, fonts, unexpected additions).
    $others = $pulled | Where-Object { $_.Extension -ne '.template' -and $_.Name -ne 'templates.json' }
    if ($others)
    {
        $otherDir = Join-Path $captureDir 'other'
        $null = New-Item -ItemType Directory -Path $otherDir -Force
        $others | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $otherDir $_.Name) -Force }
        Write-Good "Captured $($others.Count) non-template file(s) into other/ -- review these, they may be new."
    }

    #-------------------------------------------------------------------------------
    # 7. capture.json -- the provenance record whose absence was the original defect
    #-------------------------------------------------------------------------------

    Write-Step 'Writing capture.json'

    $capture = [ordered]@{
        capturedAtUtc      = (Get-Date).ToUniversalTime().ToString('o')
        capturedBy         = 'tools/Get-DeviceTemplateCorpus.ps1'
        firmwareVersion    = $firmwareVersion
        firmwareSource     = $firmwareSource
        hostOsVersion      = $osVersion
        deviceModel        = (Get-MetadataSection -Name 'model')
        deviceAddress      = $DeviceIP
        deviceTemplatePath = $DeviceTemplateDir
        counts             = [ordered]@{
            templateFiles      = $records.Count
            stock              = $stockCount
            user               = $userCount
            unclassified       = $oddCount
            manifestEntries    = $manifestEntryCount
            otherFiles         = @($others).Count
            jsonParseFailures  = $parseErrors.Count
        }
        rawDeviceMetadata  = $metadataText -split "`n"
        templates          = $records
    }

    $capture | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $captureDir 'capture.json') -Encoding utf8NoBOM

    Write-Good 'capture.json written.'

    #-------------------------------------------------------------------------------
    # 8. Summary
    #-------------------------------------------------------------------------------

    Write-Host @"

------------------------------------------------------------------
  Corpus snapshot complete.

  Firmware ............ $firmwareVersion
  Location ............ research/reference_material/corpus/$firmwareLabel
  Template files ...... $($records.Count)  (stock $stockCount / user $userCount)
  Manifest entries .... $manifestEntryCount
  Parse failures ...... $($parseErrors.Count)

  The device was not modified.

  Next: tell Claude the harvest is done. The snapshot will be compared
  against the March 2026 capture to re-evaluate ADR-0006.
------------------------------------------------------------------
"@ -ForegroundColor Green
}
finally
{
    if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
}
