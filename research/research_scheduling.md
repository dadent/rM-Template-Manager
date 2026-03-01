# rM Template Manager -- Comprehensive Research, Architecture & Planning Document

*Last Updated: 2026-03-01 07:36:58 UTC*

------------------------------------------------------------------------

# 1. Purpose of This Document

This document captures ALL research, architectural decisions,
constraints, device behaviors, template format discoveries, PowerShell
learnings, safety considerations, CI strategy, and open decisions for
the rM Template Manager project.

It is intended to:

• Preserve complete context for future ChatGPT sessions\
• Provide GitHub Copilot with architectural understanding\
• Support PRD generation\
• Support phased planning\
• Guide AI code agents\
• Serve as long-term architectural record

This document is the authoritative research baseline.

------------------------------------------------------------------------

# 2. Product Vision

## 2.1 Name

rM Template Manager

## 2.2 Product Intent

A polished Windows desktop utility for managing custom templates on the
reMarkable Paper Pro.

• Public-shareable\
• Architected for safety\
• Built for extensibility\
• Single-device focus\
• Strong test discipline\
• PR-driven AI development model

Templates are the initial feature, but architecture must allow future
expansion.

------------------------------------------------------------------------

# 3. Development Environment

• Visual Studio 2022\
• .NET 8 (LTS)\
• WPF (Windows-only desktop app)\
• GitHub repository\
• GitHub Actions CI\
• PR-based workflow only

------------------------------------------------------------------------

# 4. Architecture Overview

Layered Modular Monolith:

Domain → Application → Infrastructure → UI (WPF)

## 4.1 Domain Layer (Pure)

Contains: • Template models\
• Merge engine\
• Expression engine\
• Layout resolution logic\
• Validation rules\
• Conflict detection\
• No IO\
• No SSH\
• No filesystem

Must be 100% testable in isolation.

------------------------------------------------------------------------

## 4.2 Application Layer

Coordinates workflows: • Plan merge\
• Apply merge\
• Backup\
• Restore\
• Firmware detection\
• Deployment orchestration\
• Safety pre-checks

Depends on interfaces only.

------------------------------------------------------------------------

## 4.3 Infrastructure Layer

Sub-components:

### SSH Transport

Abstracted via interface: • Execute command\
• Upload file\
• Download file

Mocked in tests.

### Device Adapter

Knows: • Device file paths\
• Remount commands\
• templates.json location\
• Restart behavior\
• Firmware detection commands\
• Battery check command\
• Disk space check command

### Persistence

• Backup folder management\
• Local catalog storage

### Logging

• Structured logging (Serilog recommended)\
• Export logs feature\
• Never log password

------------------------------------------------------------------------

## 4.4 UI Layer (WPF)

• MVVM architecture\
• ViewModels depend on Application layer only\
• No direct SSH or filesystem calls\
• Log viewer panel\
• Deployment plan preview\
• Conflict resolution UI\
• Device connection panel (IP + password)

------------------------------------------------------------------------

# 5. Device Research Findings

Derived from: • Provided PowerShell module\
• Update instructions markdown\
• Sample templates.json\
• Device filesystem paths

## 5.1 Connection

Supports: • USB (default IP: 10.11.99.1)\
• WiFi (user-provided IP)

Authentication: • Username + password\
• Password entered each run\
• Not persisted\
• Cleared on exit

------------------------------------------------------------------------

## 5.2 Device Paths (From Research)

Templates live under:

/usr/share/remarkable/templates

Registry file: templates.json

Root filesystem must be remounted RW before changes.

Typical flow observed in PowerShell:

1.  Backup templates.json\
2.  Remount root RW\
3.  Copy template files\
4.  Replace templates.json\
5.  Remount RO

------------------------------------------------------------------------

## 5.3 Safety Requirements

Because system partition is modified:

Preflight checks must include: • Firmware version detection\
• Battery level check\
• Disk space check\
• Confirm mount state

User must see warning before modifying device.

Rollback required if failure.

------------------------------------------------------------------------

# 6. templates.json Research

From sample file analysis:

Each entry contains:

• name\
• filename\
• iconCode\
• categories (string array)\
• optional landscape: true

Important findings:

• Template identity = filename\
• New templates should be appended\
• Ordering should be preserved\
• Landscape flag determines orientation\
• Categories control picker grouping\
• iconCode uses glyph encoding (UTF-8, no BOM required)

Merge Rules:

IF filename not present → append\
IF filename present AND identical → skip\
IF filename present AND different → conflict

Never silently overwrite.

------------------------------------------------------------------------

# 7. .template File Research

All provided .template files are JSON-based layout definitions.

Structure includes:

• name\
• author\
• templateVersion\
• formatVersion\
• orientation (portrait/landscape)\
• categories\
• constants\
• items

Key discovery:

Dimension fields may contain: • Numeric values\
• Expression strings

Examples reference: • templateWidth\
• templateHeight\
• parentWidth\
• parentHeight

This means:

We must model values as either: NumericValue OR ExpressionValue

Expressions must eventually be parsed and evaluated.

------------------------------------------------------------------------

# 8. Encoding Requirements

From PowerShell research and Unix device behavior:

Generated templates.json must:

• Be UTF-8 without BOM\
• Use LF (`\n`{=tex}) line endings\
• Contain no CRLF\
• Preserve glyph escape sequences properly

Tests must validate: • No BOM bytes\
• No carriage return characters

------------------------------------------------------------------------

# 9. Backup & Rollback Strategy

Backups stored under user-provided parent folder.

Structure:

Backup/ YYYY-MM-DD_HH-MM-SS/ templates.json template files/ firmware.txt

Rollback flow: • On failure, attempt automatic restore\
• Log outcome\
• Inform user

Manual restore option desirable in later phase.

------------------------------------------------------------------------

# 10. Firmware Compatibility Strategy

Phase 1: • Detect version\
• Log version\
• Display in UI\
• Warn if unknown

Phase 2: Introduce CompatibilityPolicy abstraction.

Unknown versions should warn, not block initially.

------------------------------------------------------------------------

# 11. Testing Strategy

Coverage Goals: • \>80% overall\
• \>90% preferred\
• 100% merge engine

Test Types:

Domain: • Unit tests\
• Golden file tests\
• Property-based tests

Application: • Mock orchestration tests

Infrastructure: • Mock SSH only

UI: • ViewModel tests only

CI must run full test suite.

------------------------------------------------------------------------

# 12. CI & GitHub Strategy

GitHub Actions:

On PR and push: • Restore\
• Build Release\
• Test Release\
• Upload test results

Branch Protection: • PR required\
• CI required\
• Review required

AI workflow: • Feature branches only\
• Broad refactors allowed\
• Tests must pass

------------------------------------------------------------------------

# 13. Release Strategy

CI produces executable artifact.

Release pipeline produces: • Self-contained EXE\
• MSI installer

MSI technology TBD (WiX or MSIX).

------------------------------------------------------------------------

# 14. Phased Development Plan

Phase 1: • Domain models\
• Merge engine\
• Backup logic\
• Device adapter\
• SSH abstraction\
• Basic WPF shell\
• Logging

Phase 2: • Static JSON template editor

Phase 3: • Expression engine\
• Layout resolver\
• Template preview rendering

Phase 4: • Graphical template editor

------------------------------------------------------------------------

# 15. Open Decisions Remaining

1.  Expression grammar scope\
2.  Rendering engine choice\
3.  SSH library selection\
4.  Firmware compatibility enforcement level\
5.  MSI packaging technology\
6.  Conflict resolution UX specifics\
7.  Whether to support manual restore UI in Phase 1 or Phase 2

------------------------------------------------------------------------

# 16. Core Principles

1.  Domain must remain pure.\
2.  Infrastructure must be replaceable.\
3.  Safety first.\
4.  Append-only merge policy.\
5.  No credential persistence.\
6.  PR-driven workflow only.\
7.  Tests required for behavioral changes.\
8.  Designed for extensibility without redesign.\
9.  Structured logging mandatory.\
10. Single-device focus.

------------------------------------------------------------------------

End of comprehensive research document.
