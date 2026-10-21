# rM Template Manager — Product Requirements Document

*Version: 1.0*
*Last Updated: 2026-03-02*

---

> ### ⚠ Partially superseded — v2.0 revision pending
>
> This is the original March 2026 PRD, committed unchanged as the project's requirements
> baseline. The architecture work of October 2026 supersedes several sections. Until v2.0
> lands, **the ADRs win where they conflict with this document.**
>
> | This document | Superseded by | What changed |
> |---|---|---|
> | §1.3 — .NET 8 (LTS) | [ADR-0002](docs/architecture/decisions/0002-target-dotnet-10-lts.md) | .NET 8 leaves support in Nov 2026; target .NET 10 LTS. WPF is unchanged ([ADR-0003](docs/architecture/decisions/0003-wpf-desktop-shell.md)). |
> | §12.4 — MSI installer required | [ADR-0008](docs/architecture/decisions/0008-installer-packaging.md) | No installer. Running this needs a device in Developer Mode, so the realistic deployment target is one machine. A single-file EXE from the release pipeline is the whole distribution story. |
> | §10.4 — architecture summary | [`docs/architecture/overview.md`](docs/architecture/overview.md) | Expanded into the full architecture contract, with executable layering rules and a five-layer validation stack. |
> | §11 / §12.1 — testing and CI | [ADR-0010](docs/architecture/decisions/0010-static-analysis-and-validation-gates.md) | Static analysis added as the first validation gate, ahead of tests. |
> | §14.1 — open decisions | ADRs [0005](docs/architecture/decisions/0005-ssh-library.md), [0006](docs/architecture/decisions/0006-expression-grammar-scope.md), [0007](docs/architecture/decisions/0007-preview-rendering.md), [0008](docs/architecture/decisions/0008-installer-packaging.md) | Expression grammar, rendering engine, SSH library, and packaging are now decided. Grammar scope is pending a corpus refresh. Conflict-resolution UX and `iconCode` handling remain open. |
>
> Everything else — the device protocol, manifest schema, merge rules, safety lifecycle,
> workspace layout, and the template file format — remains current and is the authority.
> Start at [`docs/architecture/overview.md`](docs/architecture/overview.md) for the
> document map.

---

## 1. Product Overview & Vision

### 1.1 Product Name

rM Template Manager

### 1.2 Purpose

A polished Windows desktop application for managing custom templates on the reMarkable Paper Pro tablet. The application automates the manual SSH/SCP workflow currently required to deploy, update, and maintain user-created templates on the device.

### 1.3 Target Platform

- Windows desktop (WPF)
- .NET 8 (LTS)
- Single-device focus (one reMarkable Paper Pro at a time)

### 1.4 Value Proposition

Today, managing custom templates on a reMarkable Paper Pro requires manually SSHing into the device, copying files via SCP, editing a JSON manifest, remounting the filesystem, and rebooting. This process is error-prone, tedious, and must be repeated after every firmware update.

rM Template Manager provides:

- **One-click deployment** of user templates to the device
- **A persistent local workspace** for managing a personal template library
- **Safe, automated device interaction** with backup, rollback, and pre-flight checks
- **Full template lifecycle** — from deploying pre-authored files through viewing, previewing, creating, and editing templates within the application

### 1.5 Incremental Build Path

The application will be built incrementally toward the full vision:

1. **Deploy** — Manage and deploy pre-authored .template files to the device
2. **View** — Display template metadata, JSON content, and visual preview
3. **Create & Edit** — Full in-app template authoring with expression support and live preview

### 1.6 Design Principles

1. **Domain must remain pure.** No IO, no SSH, no filesystem in the domain layer.
2. **Infrastructure must be replaceable.** All external dependencies behind interfaces.
3. **Safety first.** Pre-flight checks, backup, rollback, user confirmation before device modification.
4. **Append-only merge policy.** Never silently overwrite existing templates.
5. **No credential persistence.** Password entered per session, cleared on exit.
6. **PR-driven workflow only.** All changes via feature branches and pull requests.
7. **Tests required for behavioral changes.** No merging without passing tests.
8. **Designed for extensibility without redesign.** Templates are the first feature; architecture supports future expansion.
9. **Structured logging mandatory.** All operations logged; passwords never logged.
10. **Single-device focus.** One connected device at a time.

---

## 2. User Personas & Use Cases

### 2.1 End-User Persona

**Name:** Template Author
**Description:** A technical reMarkable Paper Pro owner who creates and manages custom templates for personal use. Comfortable with basic technical concepts but wants to avoid manual SSH/SCP workflows.

**Goals:**
- Maintain a personal library of custom templates
- Quickly re-deploy templates after firmware updates
- Safely modify the device without risk of corruption
- Preview templates before deployment
- Eventually create and edit templates within the app

#### Core Use Cases

| ID | Use Case | Description |
|----|----------|-------------|
| EU-01 | Connect to Device | Connect to reMarkable Paper Pro via USB (default IP 10.11.99.1) or WiFi (user-provided IP) using SSH password authentication. |
| EU-02 | View Device Templates | Retrieve and display the list of templates currently installed on the device, including name, category, orientation, and icon. |
| EU-03 | Import Templates to Library | Select a local folder containing .template files and import them into the persistent workspace library. |
| EU-04 | Manage Template Library | View, organize, and remove templates from the local workspace library. |
| EU-05 | Preview Merge Plan | Before deployment, view a detailed plan showing what will be added, skipped, or flagged as conflicts. |
| EU-06 | Deploy Templates | Execute the merge plan to deploy user templates to the device, including manifest update and file transfer. |
| EU-07 | Backup Device Templates | Create a timestamped backup of the device's current templates.json and template files before making changes. |
| EU-08 | Restore from Backup | Restore a previous backup to the device, reverting to a known-good state. |
| EU-09 | Re-apply After Firmware Update | Detect that a firmware update has wiped user templates and offer to re-apply the full library from the workspace. |
| EU-10 | View Template Details | Display template metadata, JSON content, and a visual preview of the rendered layout. |
| EU-11 | Create/Edit Template | Author new templates or modify existing ones within the app, with validation and live preview. |
| EU-12 | Configure Settings | Set default device IP, workspace location, logging level, backup retention, and other preferences. |

#### Edge Cases

| ID | Edge Case | Expected Behavior |
|----|-----------|-------------------|
| EC-01 | Unknown firmware version, checks pass | Warn user, ask permission to proceed. |
| EC-02 | Unknown firmware version, checks fail | Warn user, recommend cancel (default), allow override. |
| EC-03 | Low battery during deployment | Pre-flight check blocks deployment with warning. |
| EC-04 | Insufficient disk space | Pre-flight check blocks deployment with warning. |
| EC-05 | Deployment failure mid-operation | Automatic rollback to backup state; notify user. |
| EC-06 | Network disconnect during operation | Detect failure, attempt rollback, log outcome. |
| EC-07 | Duplicate filename in manifest | Flag as conflict; never silently overwrite. |
| EC-08 | Corrupt or missing templates.json | Detect during device inspection; warn user before proceeding. |

### 2.2 Developer Persona — Traditional Workflow

**Name:** Contributor
**Description:** A software developer contributing to the project via standard IDE, CLI, and PR-based workflow.

**Goals:**
- Quickly clone, build, and run the project
- Run tests locally before submitting PRs
- Understand the codebase structure and conventions
- Refactor with confidence backed by comprehensive tests

#### Developer Use Cases

| ID | Use Case | Description |
|----|----------|-------------|
| DV-01 | Clone & Build | Clone the repository and build the solution using standard .NET CLI or Visual Studio 2022. |
| DV-02 | Run Tests Locally | Execute the full test suite locally to validate changes before pushing. |
| DV-03 | Create Feature Branch | Start work on a new feature or fix using a dedicated feature branch. |
| DV-04 | Submit PR | Open a pull request targeting the main branch; CI runs automatically. |
| DV-05 | Review CI Results | Inspect GitHub Actions build and test results on the PR. |
| DV-06 | Debug Failing Tests | Investigate and fix test failures using IDE debugger and test output. |
| DV-07 | Refactor Safely | Make structural changes with confidence that the test suite will catch regressions. |

### 2.3 Developer Persona — AI-Assisted Workflow

**Name:** AI-Assisted Contributor
**Description:** A developer using GitHub Copilot or other AI coding agents to implement features incrementally across multiple sessions.

**Goals:**
- Resume work across sessions using documented project state
- Generate code that fits the architecture with AI assistance
- Validate AI-generated code with the test suite
- Ensure all AI contributions go through human review via PRs

#### AI-Assisted Use Cases

| ID | Use Case | Description |
|----|----------|-------------|
| AI-01 | Resume Session | Read tasks.md to understand current project state, completed work, and next actionable task. |
| AI-02 | Understand Architecture | Reference the PRD and research docs to understand design decisions, constraints, and interfaces. |
| AI-03 | Generate Code | Use AI agents to generate implementation code that conforms to the layered architecture and coding conventions. |
| AI-04 | Validate Changes | Run the full test suite to verify AI-generated code does not introduce regressions. |
| AI-05 | Submit for Review | Create a PR with AI-generated changes for human review before merging. |
| AI-06 | Track Progress | Update tasks.md with completed work and status changes at the end of each session. |

---

## 3. Functional Requirements — Device Connection & Communication

### 3.1 Connection Methods

| Method | Default IP | Notes |
|--------|-----------|-------|
| USB | 10.11.99.1 | Recommended; most reliable |
| WiFi | User-provided | Requires device and host on same network |

### 3.2 Authentication

- **Protocol:** SSH (password-based authentication)
- **Username:** `root`
- **Password:** Entered by user each session
- **Persistence:** Password MUST NOT be persisted to disk, registry, or configuration files
- **Cleanup:** Password cleared from memory when the application exits or disconnects

### 3.3 SSH Transport Abstraction

The application MUST interact with the device exclusively through an SSH transport interface:

```
ISshTransport
  ExecuteCommand(command: string) → CommandResult
  UploadFile(localPath: string, remotePath: string) → TransferResult
  DownloadFile(remotePath: string, localPath: string) → TransferResult
```

This interface MUST be mockable for testing. No direct SSH library calls outside the infrastructure layer.

### 3.4 Device Adapter

The device adapter encapsulates all device-specific knowledge:

| Responsibility | Details |
|---------------|---------|
| Template directory | `/usr/share/remarkable/templates` |
| Manifest file | `templates.json` within the template directory |
| Remount read-write | `mount -o remount,rw /` |
| Remount read-only | `mount -o remount,ro /` |
| Firmware detection | Read firmware version from device |
| Battery level check | Query device battery percentage |
| Disk space check | Query available disk space on root partition |
| Device restart | Trigger device reboot after deployment |

### 3.5 Device Inspection

Before any modification, the application MUST perform device inspection:

1. Verify SSH connectivity
2. Confirm `/usr/share/remarkable/templates` directory exists
3. Confirm `templates.json` exists at the expected path
4. Download and parse `templates.json` to confirm it conforms to the expected schema
5. Detect firmware version and evaluate compatibility

---

## 4. Functional Requirements — Template Management

### 4.1 Template Manifest Schema (templates.json)

The manifest is a JSON file containing an array of template entries:

```json
{
  "templates": [
    {
      "name": "Display Name",
      "filename": "FileIdentifier",
      "iconCode": "\ue9fe",
      "categories": ["Category1", "Category2"],
      "landscape": true
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable display name shown on the device |
| `filename` | string | Yes | File identifier (without extension); serves as the template's unique identity |
| `iconCode` | string | Yes | Unicode glyph code for the template picker icon |
| `categories` | string[] | Yes | One or more categories for grouping in the template picker |
| `landscape` | boolean | No | If `true`, template is landscape orientation; if absent, portrait is assumed |

**Key rules:**
- Template identity is determined by the `filename` field
- The same `filename` may appear in multiple entries (portrait and landscape variants)
- Ordering of entries MUST be preserved during merge operations
- The file MUST be encoded as UTF-8 without BOM with LF line endings

### 4.2 Known Categories

Observed categories from the stock manifest:

- Creative
- Lines
- Grids
- Planners

User templates may introduce additional categories.

### 4.3 Manifest Operations

| Operation | Description |
|-----------|-------------|
| Read | Download templates.json from device and parse into structured model |
| Display | Present all template entries with name, filename, categories, orientation |
| Merge | Combine device manifest with user library entries per merge rules |
| Write | Serialize merged manifest and upload to device |

### 4.4 Merge Rules

The merge engine is a core domain component with strict rules:

| Condition | Action |
|-----------|--------|
| User filename NOT present in device manifest | **Append** the entry to the manifest |
| User filename present AND entry is identical | **Skip** (no action needed) |
| User filename present AND entry differs | **Conflict** — flag for user resolution |

**Invariants:**
- NEVER silently overwrite an existing entry
- ALWAYS preserve the order of existing device entries
- User entries are appended after existing entries
- Conflicts MUST be presented to the user for resolution before deployment

### 4.5 Template File Deployment

For each template entry being deployed, the corresponding `.template` file must be uploaded to `/usr/share/remarkable/templates/` on the device. The filename on the device is `{filename}.template` where `{filename}` matches the manifest entry's `filename` field.

### 4.6 Post-Firmware-Update Detection

When the application connects to a device and reads the manifest, it SHOULD detect that previously deployed user templates are no longer present. This is the primary use case for the application — the user has just updated firmware and wants to re-apply their personal template library.

Detection heuristic:
- Compare device manifest entries against the user's workspace library
- If the library contains templates that are not on the device, present the user with the option to re-deploy them

---

## 5. Functional Requirements — Workspace & Local Library

### 5.1 Workspace Location

The application maintains a persistent workspace directory for storing the user's template library, deployment history, backups, and settings.

| Property | Value |
|----------|-------|
| Default location | `{Documents}\rM Template Manager\` |
| Configurable | Yes — user can change via settings |
| Created automatically | Yes — on first launch if it does not exist |

### 5.2 Workspace Structure

```
{workspace}/
  library/                    # User's template library
    {filename}.template       # Template files
  library.json                # Library catalog (metadata for all templates)
  backups/                    # Device backups
    {YYYY-MM-DD_HH-MM-SS}/
      templates.json          # Device manifest at time of backup
      templates/              # Template files from device
      firmware.txt            # Firmware version at time of backup
  history/                    # Deployment history log
  settings.json               # Application settings
```

### 5.3 Library Management

| Operation | Description |
|-----------|-------------|
| Import | Copy .template files from a user-selected local folder into the library; parse and catalog metadata |
| List | Display all templates in the library with name, author, categories, orientation |
| View | Show detailed template metadata and content |
| Remove | Remove a template from the library |
| Sync status | Show which library templates are currently deployed on the connected device |

### 5.4 Library Catalog (library.json)

Maintains metadata for all templates in the library:

```json
{
  "templates": [
    {
      "filename": "P Grid Meeting",
      "name": "Grid - Mtg Notes",
      "author": "DAdent",
      "categories": ["Grids"],
      "orientation": "portrait",
      "importedAt": "2026-03-01T12:00:00Z",
      "manifestEntry": {
        "name": "Grid - Mtg Notes",
        "filename": "P Grid Meeting",
        "iconCode": "\ue99c",
        "categories": ["Grids"]
      }
    }
  ]
}
```

### 5.5 Deployment History

The workspace tracks deployments:

| Field | Description |
|-------|-------------|
| Timestamp | When the deployment occurred |
| Device firmware | Firmware version at time of deployment |
| Templates deployed | List of template filenames that were deployed |
| Result | Success, partial failure, or rolled back |

---

## 6. Functional Requirements — Template File Format & Expressions

### 6.1 Template File Structure (.template)

Template files are JSON documents defining the visual layout of a template:

```json
{
  "name": "Display Name",
  "author": "Author Name",
  "templateVersion": "1.0.0",
  "formatVersion": 1,
  "categories": ["Category"],
  "orientation": "portrait",
  "constants": [
    { "variableName": "value or expression" }
  ],
  "items": [
    { /* item definition */ }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Display name of the template |
| `author` | string | Yes | Author of the template |
| `templateVersion` | string | Yes | Semantic version of the template |
| `formatVersion` | number | Yes | Format schema version (currently `1`) |
| `categories` | string[] | Yes | Template categories |
| `orientation` | string | Yes | `"portrait"` or `"landscape"` |
| `constants` | object[] | No | Named constants or expressions for reuse in items |
| `items` | object[] | Yes | Visual elements that compose the template layout |

### 6.2 Constants

Constants define named values that can be referenced in item definitions. Each constant is a single-key object in an ordered array:

```json
"constants": [
  { "gridSize": 52 },
  { "magicGridOffset": -25 },
  { "GridXpos": "templateWidth / 2 - templateHeight / 2 + magicGridOffset" }
]
```

**Rules:**
- Constants are evaluated in order (later constants may reference earlier ones)
- Values may be numeric literals or expression strings
- Expression strings are enclosed in quotes and evaluated at render time

### 6.3 Built-in Variables

The expression engine provides these built-in variables:

| Variable | Description |
|----------|-------------|
| `templateWidth` | Width of the template canvas in device units |
| `templateHeight` | Height of the template canvas in device units |
| `parentWidth` | Width of the parent bounding box |
| `parentHeight` | Height of the parent bounding box |
| `paperOriginX` | X-axis origin point of the paper |

### 6.4 Expression Engine Requirements

Expressions appear in dimension fields, bounding box coordinates, path data, and position values. The expression engine MUST support:

| Feature | Example |
|---------|---------|
| Numeric literals | `52`, `-25`, `58.4` |
| Arithmetic operators | `+`, `-`, `*`, `/` |
| Parentheses | `(templateWidth / 2 - 150)` |
| Variable references | `templateWidth`, `gridSize` |
| Ternary conditionals | `templateWidth > mobileMaxWidth ? magicOffsetY : mobileOffsetY` |
| Comparison operators | `<`, `>`, `<=`, `>=`, `==`, `!=` |
| Logical operators | `\|\|`, `&&` |
| String `"infinite"` | Special repeat value for infinite tiling |
| String `"down"` | Special repeat direction value |

### 6.5 Item Types

#### Group

A container that holds child items and defines a bounding box and optional repeat behavior:

```json
{
  "id": "optional-id",
  "type": "group",
  "boundingBox": { "x": 0, "y": 0, "width": "templateWidth", "height": "gridSize" },
  "repeat": { "rows": "infinite", "columns": "infinite" },
  "children": [ /* child items */ ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | No | Optional identifier |
| `type` | string | Yes | `"group"` |
| `boundingBox` | object | Yes | Position and size (values may be expressions) |
| `repeat` | object | No | Tiling behavior: rows and/or columns |
| `children` | array | Yes | Nested item definitions |

#### Path

An SVG-like path definition:

```json
{
  "id": "optional-id",
  "type": "path",
  "strokeWidth": 3,
  "data": ["M", 0, 0, "L", "parentWidth", 0]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `"path"` |
| `strokeWidth` | number | No | Line thickness |
| `data` | array | Yes | SVG-like path commands (M = moveTo, L = lineTo); values may be expressions |

#### Text

A text label placed at a specific position:

```json
{
  "type": "text",
  "text": "Topic:",
  "fontSize": 60,
  "position": { "x": "expression", "y": 95 }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `"text"` |
| `text` | string | Yes | Text content to display |
| `fontSize` | number | Yes | Font size in device units |
| `position` | object | Yes | X/Y coordinates (values may be expressions) |

### 6.6 Repeat Behavior

The `repeat` field on groups controls tiling:

| Value | Meaning |
|-------|---------|
| `"infinite"` | Tile indefinitely to fill available space |
| `"down"` | Repeat downward only |
| *(numeric)* | Repeat a specific number of times |

---

## 7. Functional Requirements — Template Viewing & Editing

### 7.1 Template Viewing

The application MUST support viewing template details:

| Capability | Description |
|------------|-------------|
| Metadata display | Show name, author, version, orientation, categories |
| JSON viewer | Display the raw JSON content of the .template file with syntax highlighting |
| Constant listing | Display evaluated constant values |

### 7.2 Visual Preview

The application MUST render a visual preview of how a template will appear on the device:

| Requirement | Description |
|-------------|-------------|
| Expression evaluation | Resolve all constants and expressions to numeric values |
| Path rendering | Draw all path items (M/L commands) on a canvas |
| Text rendering | Place text items at their computed positions |
| Group handling | Render groups with their bounding boxes and repeat behavior |
| Orientation | Render in correct portrait or landscape orientation |
| Canvas dimensions | Use device-accurate template dimensions |

### 7.3 Template Editor

The application MUST eventually support creating and editing templates:

| Capability | Description |
|------------|-------------|
| Create new | Start a new .template file from scratch or from a built-in starter template |
| Edit existing | Modify any field of an existing .template file |
| Live preview | Update the visual preview as edits are made |
| Validation | Validate the template structure and expressions before saving |
| Save | Write the .template file to the workspace library |

### 7.4 Template Validation

Before deployment or save, templates MUST be validated:

| Check | Description |
|-------|-------------|
| Schema conformance | Required fields present, correct types |
| Expression validity | All expressions parse and evaluate without error |
| Variable resolution | All referenced variables are defined (built-in or constant) |
| Filename uniqueness | No duplicate filenames within the library |

---

## 8. Functional Requirements — Safety, Backup & Rollback

### 8.1 Pre-Flight Checks

Before any device modification, the application MUST perform these checks and present results to the user:

| Check | Condition | Action |
|-------|-----------|--------|
| SSH connectivity | Cannot connect | Block operation; display error |
| Manifest exists | templates.json missing or unreadable | Block operation; display error |
| Manifest format | templates.json does not conform to expected schema | Block operation; display error |
| Firmware version | Unknown version, but all other checks pass | Warn user; ask permission to proceed |
| Firmware version | Unknown version AND structural checks fail | Warn user; recommend cancel (default); allow override |
| Battery level | Below safe threshold | Block operation; display warning |
| Disk space | Insufficient space for deployment | Block operation; display warning |
| Mount state | Cannot remount read-write | Block operation; display error |

### 8.2 User Confirmation

The application MUST display a confirmation dialog before any device modification that includes:

- Summary of changes to be made (templates added, conflicts resolved)
- Current firmware version
- Battery level
- Any warnings from pre-flight checks

The user must explicitly confirm before the operation proceeds.

### 8.3 Deployment Lifecycle

The device modification follows a strict lifecycle:

1. **Pre-flight checks** — All checks pass or user overrides warnings
2. **Backup** — Create timestamped backup of current device state
3. **Remount RW** — `mount -o remount,rw /`
4. **Upload template files** — SCP each new .template file to the device
5. **Upload manifest** — SCP the merged templates.json to the device
6. **Remount RO** — `mount -o remount,ro /`
7. **Verify** — Confirm files were written correctly
8. **Restart notification** — Inform user that a device restart is required for changes to take effect

If any step fails after remounting RW, the application MUST attempt automatic rollback.

### 8.4 Backup Structure

```
{workspace}/backups/{YYYY-MM-DD_HH-MM-SS}/
  templates.json          # Device manifest at time of backup
  templates/              # All template files from device
  firmware.txt            # Firmware version string
```

### 8.5 Automatic Rollback

On deployment failure:

1. Restore the backed-up templates.json to the device
2. Remove any newly uploaded template files
3. Remount filesystem read-only
4. Log the failure with full details
5. Notify the user of the rollback result

### 8.6 Manual Restore

The application MUST provide a manual restore feature:

- List all available backups with timestamps and firmware versions
- Allow user to select a backup and restore it to the device
- Restore follows the same safety lifecycle (pre-flight checks, remount, upload, remount)

---

## 9. Functional Requirements — UI/UX

### 9.1 Architecture

- **Pattern:** MVVM (Model-View-ViewModel)
- **Rule:** ViewModels depend on the Application layer only; no direct SSH, filesystem, or infrastructure calls
- **Framework:** WPF with data binding

### 9.2 Main Application Views

#### Connection Panel

| Element | Description |
|---------|-------------|
| IP address field | Text input; defaults to 10.11.99.1 (configurable in settings) |
| Password field | Secure text input; masked; cleared on disconnect |
| Connect button | Initiates SSH connection and device inspection |
| Connection status | Visual indicator (disconnected, connecting, connected, error) |
| Device info | Display firmware version, battery level, disk space after connection |

#### Device Templates View

| Element | Description |
|---------|-------------|
| Template list | Scrollable list of all templates on the device |
| Template details | Name, filename, categories, orientation, icon |
| Filter/search | Filter templates by name or category |
| Sync indicators | Show which device templates match library templates |

#### Library View

| Element | Description |
|---------|-------------|
| Library template list | All templates in the local workspace library |
| Import button | Opens folder picker to import .template files |
| Template details | Name, author, categories, orientation, import date |
| Remove button | Remove selected template from library |
| Deploy status | Indicator showing if template is currently on device |

#### Deployment Plan View

| Element | Description |
|---------|-------------|
| Actions list | Line-by-line list of what will happen: Add, Skip, Conflict |
| Conflict resolution | For each conflict, show device vs. library entry with resolution options |
| Deploy button | Execute the plan after user review and confirmation |
| Cancel button | Abort without making changes |

#### Template Preview Panel

| Element | Description |
|---------|-------------|
| Canvas | Rendered visual preview of the selected template |
| Orientation toggle | Switch between portrait/landscape if applicable |
| Zoom controls | Zoom in/out on the preview |

#### Log Viewer

| Element | Description |
|---------|-------------|
| Log output | Scrollable, searchable log of all application operations |
| Log level filter | Filter by severity (Debug, Info, Warning, Error) |
| Export button | Save logs to file |
| Auto-scroll | Follow latest entries |

#### Settings Panel

| Setting | Default | Description |
|---------|---------|-------------|
| Default device IP | 10.11.99.1 | Pre-filled in connection panel |
| Workspace location | `{Documents}\rM Template Manager\` | Path to persistent workspace |
| Logging level | Info | Minimum log severity displayed |
| Backup retention | Keep all | Number of backups to retain (or keep all) |
| Auto-backup | Enabled | Automatically backup before deployment |

### 9.3 Dialog Patterns

| Dialog | Trigger | Content |
|--------|---------|---------|
| Deployment Confirmation | User clicks Deploy | Summary of changes, warnings, firmware version, battery level |
| Firmware Warning | Unknown firmware + checks pass | Warning message with Proceed/Cancel buttons |
| Firmware Incompatibility | Unknown firmware + checks fail | Strong warning; Cancel (default) + Override button |
| Rollback Notification | Deployment failure | Rollback result details with OK button |
| Restore Confirmation | User selects Restore | Backup details with Confirm/Cancel buttons |

### 9.4 Responsiveness

- All SSH operations MUST run asynchronously to keep the UI responsive
- Long-running operations MUST display progress indicators
- The UI MUST remain interactive during device communication (cancel button available)

---

## 10. Non-Functional Requirements

### 10.1 Encoding

| Requirement | Details |
|-------------|---------|
| Character encoding | UTF-8 without BOM |
| Line endings | LF (`\n`) only; no CRLF |
| Glyph handling | Preserve Unicode escape sequences (e.g., `\ue9fe`) correctly |

Tests MUST validate:
- No BOM bytes in generated files
- No carriage return characters in generated files

### 10.2 Logging

| Requirement | Details |
|-------------|---------|
| Framework | Structured logging (Serilog recommended) |
| Levels | Debug, Info, Warning, Error, Fatal |
| Export | User can export logs to file |
| Sensitive data | Passwords MUST NEVER appear in logs |
| Scope | All SSH commands, file operations, merge decisions, and error conditions logged |

### 10.3 Performance

| Requirement | Details |
|-------------|---------|
| UI responsiveness | All device operations async; UI never blocks |
| Connection timeout | Configurable; reasonable default (e.g., 10 seconds) |
| File transfer | Progress reporting for multi-file uploads |

### 10.4 Architecture

**Layered Modular Monolith:**

```
Domain → Application → Infrastructure → UI (WPF)
```

| Layer | Responsibilities | Rules |
|-------|-----------------|-------|
| **Domain** | Template models, merge engine, expression engine, layout resolution, validation, conflict detection | No IO, no SSH, no filesystem; 100% testable in isolation |
| **Application** | Workflow coordination: plan merge, apply merge, backup, restore, firmware detection, deployment orchestration, safety pre-checks | Depends on interfaces only |
| **Infrastructure** | SSH transport, device adapter, local file persistence, logging | Implements interfaces; mockable |
| **UI** | WPF views, ViewModels | MVVM; ViewModels depend on Application layer only |

### 10.5 Testability

- All layers testable in isolation through dependency injection and interfaces
- Domain layer has zero external dependencies
- Infrastructure mocked in all non-integration tests
- Expression engine fully testable with deterministic inputs and outputs

### 10.6 Extensibility

The architecture MUST support future expansion without redesign:
- New device types (if reMarkable releases new models)
- Additional template features
- New file formats
- Plugin or extension points for community contributions

---

## 11. Testing Requirements

### 11.1 Coverage Goals

| Scope | Target |
|-------|--------|
| Overall | > 80% code coverage |
| Preferred | > 90% code coverage |
| Merge engine | 100% code coverage |
| Expression engine | 100% code coverage |

### 11.2 Test Types by Layer

| Layer | Test Type | Description |
|-------|-----------|-------------|
| Domain | Unit tests | Test individual models, merge logic, expression evaluation |
| Domain | Golden file tests | Compare merge output against known-good reference files |
| Domain | Property-based tests | Fuzz merge engine with generated inputs |
| Application | Mock orchestration tests | Test workflow coordination with mocked infrastructure |
| Infrastructure | Mock SSH tests | Test device adapter with mocked SSH transport |
| UI | ViewModel tests | Test ViewModels in isolation with mocked Application services |

### 11.3 CI Integration

- Full test suite runs on every push and every pull request
- Tests MUST pass before PR can be merged
- Test results uploaded as CI artifacts

---

## 12. CI, Build & Release Requirements

### 12.1 GitHub Actions Pipeline

On every PR and push to main:

1. **Restore** — Restore NuGet packages
2. **Build** — Build in Release configuration
3. **Test** — Run full test suite in Release configuration
4. **Upload** — Upload test results as artifacts

### 12.2 Branch Protection

| Rule | Setting |
|------|---------|
| Pull request required | Yes |
| CI checks required | Yes |
| Review required | Yes |
| Direct push to main | Blocked |

### 12.3 AI Development Workflow

- All AI-generated code goes through feature branches
- Broad refactors allowed (not limited to single-file changes)
- Tests MUST pass before merge
- Human review required on all PRs

### 12.4 Release Artifacts

| Artifact | Description |
|----------|-------------|
| Self-contained EXE | Single executable with all dependencies bundled |
| MSI installer | Windows installer package (technology TBD: WiX or MSIX) |

---

## 13. Firmware Compatibility

### 13.1 Firmware Detection

The application MUST:
- Detect and read the device firmware version on connection
- Display the firmware version in the UI
- Log the firmware version for diagnostic purposes

### 13.2 Device Inspection

Before any modification, the application MUST verify:

| Check | Description |
|-------|-------------|
| Manifest location | `templates.json` exists at `/usr/share/remarkable/templates/templates.json` |
| Manifest format | File parses as valid JSON matching the expected schema |
| Manifest structure | Contains a `templates` array with entries having required fields |
| Template directory | `/usr/share/remarkable/templates/` directory is accessible |

### 13.3 Two-Tier Compatibility Response

**Tier 1 — Unknown firmware, checks pass:**
- All device inspections succeed (manifest exists, parses correctly, structure valid)
- Action: Display warning about unknown firmware version; ask user for permission to proceed
- User can proceed or cancel

**Tier 2 — Unknown firmware, checks fail:**
- One or more device inspections fail (missing manifest, parse error, unexpected structure)
- Action: Display strong warning about potential incompatibility; default action is Cancel
- User can override and proceed, but this is explicitly not recommended

### 13.4 CompatibilityPolicy Abstraction

The firmware compatibility logic SHOULD be encapsulated in a `CompatibilityPolicy` abstraction to support:
- Adding known-good firmware versions over time
- Adjusting check severity levels
- Adding new device inspection checks without modifying workflow logic

---

## 14. Open Decisions & Constraints

### 14.1 Open Decisions

| Decision | Options | Notes |
|----------|---------|-------|
| Expression grammar scope | Full arithmetic + ternary vs. simplified subset | Analyze all reference templates to determine minimum viable grammar |
| Rendering engine | WPF canvas, SkiaSharp, or other | Must handle path drawing and text placement |
| SSH library | SSH.NET, Renci.SshNet, or other | Must support SCP and command execution |
| MSI packaging technology | WiX or MSIX | WiX is more mature; MSIX is more modern |
| Conflict resolution UX | Side-by-side diff, radio buttons, or dropdown | Depends on common conflict scenarios |
| iconCode handling | Render actual glyphs or display code only | Requires access to reMarkable icon font |

### 14.2 Scope Constraints

| Constraint | Details |
|------------|---------|
| Target device | reMarkable Paper Pro only |
| Platform | Windows only (WPF) |
| Device count | Single device at a time |
| Template source | Local filesystem only (no online repositories) |
| Authentication | Password only (no key-based SSH) |
| Multi-user | Not supported; single personal user |

---

## 15. Glossary & Reference

### 15.1 Key Terms

| Term | Definition |
|------|-----------|
| **Template** | A visual layout definition (.template file) that defines the background pattern for a notebook page on the reMarkable device |
| **Manifest** | The `templates.json` file on the device that registers all available templates with their display names, icons, and categories |
| **Merge** | The process of combining user library templates with the device's existing manifest |
| **Deployment** | The full process of uploading template files and an updated manifest to the device |
| **Deployment Plan** | A preview of what the merge operation will do (add, skip, or flag conflicts) before execution |
| **Workspace** | The persistent local directory where the application stores the user's template library, backups, history, and settings |
| **Library** | The user's collection of custom template files maintained in the workspace |
| **Conflict** | A situation where a user template's filename matches a device template but the manifest entries differ |
| **Rollback** | Automatic restoration of the device to its pre-deployment state after a failure |
| **Pre-flight check** | A verification performed before device modification to ensure safety conditions are met |
| **Expression** | A string formula in a .template file that is evaluated to a numeric value at render time |

### 15.2 Device Reference

| Item | Value |
|------|-------|
| Template directory | `/usr/share/remarkable/templates` |
| Manifest file | `/usr/share/remarkable/templates/templates.json` |
| Default USB IP | `10.11.99.1` |
| SSH username | `root` |
| Remount RW | `mount -o remount,rw /` |
| Remount RO | `mount -o remount,ro /` |
| Password location | Settings → Help → Copyrights & Licenses |

### 15.3 Template Manifest Entry Quick Reference

```json
{
  "name": "string (required) — display name",
  "filename": "string (required) — file identifier / unique key",
  "iconCode": "string (required) — Unicode glyph",
  "categories": ["string[] (required) — picker categories"],
  "landscape": "boolean (optional) — true for landscape"
}
```

### 15.4 Template File Quick Reference

```json
{
  "name": "string — display name",
  "author": "string — author name",
  "templateVersion": "string — semantic version",
  "formatVersion": "number — format schema version",
  "categories": ["string[] — categories"],
  "orientation": "string — portrait or landscape",
  "constants": [{ "name": "value or expression" }],
  "items": [
    {
      "type": "group | path | text",
      "boundingBox": { "x": 0, "y": 0, "width": 0, "height": 0 },
      "repeat": { "rows": "infinite", "columns": "infinite" },
      "children": [],
      "data": ["M", 0, 0, "L", 0, 0],
      "text": "string",
      "fontSize": 0,
      "position": { "x": 0, "y": 0 },
      "strokeWidth": 0
    }
  ]
}
```

---

*End of Product Requirements Document.*
