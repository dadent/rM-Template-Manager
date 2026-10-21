# reMarkable Buddy: Market Research & Path Forward

*Prepared 2026-10-12 for Daniel. Builds on `PRD.md` (v1.0, 2026-03-02) and `research/research_scheduling.md` (2026-03-01).*

Confidence labels: **High** = confirmed in a primary or official source. **Medium** = third-party source or inference from strong evidence. **Low** = speculation. Nothing here is legal or financial advice.

---

## 1. Executive summary

1. **reMarkable still has no official custom-template feature** (High). Release notes 3.20 through 3.28 (Jun 2025 to Sep 2026) say nothing about custom templates. "Methods" is a curated template library, and some of it is Connect-only. Custom `.template` installs still need SSH, which on the Paper Pro means Developer Mode, and Developer Mode factory-resets the device.
2. **reMarkable has no OneNote integration and nothing announced** (High for shipped features, Medium for roadmap). Its Microsoft-adjacent features are OneDrive import (3.25, 3.28) and Outlook-calendar meeting notes (3.27, Connect).
3. **The OneNote sync market is no longer empty.** **ReMarkSync** is a paid product ($4.99/mo or $59/yr) for Windows and macOS. It syncs one way from reMarkable to OneNote, and handwriting arrives as editable OneNote ink. It needs no Developer Mode because it reads the official desktop app's local files. Two-way sync is "in development" with no date. **rmOneNoteSync** is a GPL-3.0 alpha (C#/.NET 9 + Avalonia) that runs a daemon on the device and needs Developer Mode.
4. **Template management is also served.** **RCU** costs $12, is AGPLv3, and v5.1.1 shipped 2026-08-20. It installs templates on the Paper Pro and repairs them after firmware updates. What it lacks is a dedicated Windows-native visual template *editor* with a live preview (Medium).
5. **Two-way rM ↔ OneNote sync is feasible only in a limited form** (Medium). One-way sync with searchable ink is proven. A full round trip, where both sides edit the same page and the result merges cleanly, is not realistic for a solo developer on unofficial formats. A workable version keeps reMarkable as the source of truth and brings OneNote additions back as a new layer or a new page.
6. **Recommendation:** Don't start over. Rebrand the effort as a product family, with Template Manager as module 1. Ship it fast to restore your coding momentum and get a portfolio piece. Then build a one-way OneNote sync spike as module 2 that competes on something ReMarkSync doesn't offer. Decide on two-way after ReMarkSync ships theirs.
7. **AI tooling:** Use **Claude Code on your existing Claude plan** as the main tool and **Codex CLI on ChatGPT Plus** as a second-opinion reviewer, so there's no new spend. Upgrade to a higher tier only if you hit limits every week.
8. **GitHub/IP:** Split the work by value. Make portfolio-grade code public under a source-available license (FSL or PolyForm Noncommercial). Keep the monetizable sync engine in a private repo, with a public showcase of its design. Check trademark use of "reMarkable" in the product name before committing to "reMarkable Buddy".

---

## 2. Where you left off (from your repo)

- The repo `github.com/dadent/rM-Template-Manager` has two commits, both on 2026-03-01: research docs and reference templates. **There is no application code yet.** I couldn't confirm from here whether the repo is public or private.
- `PRD.md` describes a well-architected WPF/.NET 8 app with a layered monolith (Domain → Application → Infrastructure → UI), an SSH transport abstraction, a merge engine, an expression engine, a preview renderer, backup and rollback, and CI with branch protection.
- **That work is reusable.** The architecture principles, merge rules, and safety lifecycle carry straight over. The only stack decision to revisit is **.NET 8, which reaches end of support in November 2026 (High). Target .NET 10 LTS instead.**

---

## 3. Market research

### 3.1 Custom template tools

| Tool | What it does | Price / license | Notes |
|---|---|---|---|
| **reMarkable (official)** | No custom template support. "Methods" is a curated library you import as notebooks or workbooks. | Some Methods templates need Connect ($3.99/mo) | No `.template` import on 3.20–3.28 (High) |
| **RCU** (davisr.me) | Uploads PNG/SVG/RMT templates, repairs them after firmware updates, backups, PDF/Markdown export | $12, AGPLv3, source given to buyers | v5.1.1 (2026-08-20); supports Paper Pro on 3.28 (High) |
| **Manual SSH / scripts** (e.g. `rmtemplate`, your PowerShell script) | Edits `/usr/share/remarkable/templates` and `templates.json` | Free | Paper Pro needs Developer Mode, and enabling it factory-resets the device (High). Firmware updates wipe the templates. |
| **PDF "templates"** (Templacity, Key2Success, Etsy sellers) | PDF notebooks/planners imported through the desktop or mobile app | Paid content | Doesn't appear in the template picker, so it isn't a real template (Medium) |

**Gap:** Nobody offers a polished Windows-native tool that combines a **visual template editor**, an expression-aware preview, and a one-click redeploy after firmware updates (Medium). This gap is narrow: it serves only users who already have Developer Mode on.

### 3.2 OneNote sync tools

| Tool | Direction | How it gets data | OneNote output | Status / price |
|---|---|---|---|---|
| **ReMarkSync** | One-way, rM → OneNote. Two-way "in development". | Reads the **official desktop app's local sync files**. No Developer Mode, nothing installed on the tablet. | Editable OneNote ink with colors, typed text, PDFs with annotations (A4 only for high fidelity). Folders → section groups, notebooks → sections. | Shipping. $4.99/mo or $49→$59/yr. Windows and macOS. Not affiliated with reMarkable or Microsoft. |
| **rmOneNoteSync** | rM → OneNote | On-device C daemon plus a desktop client. No cloud. | Full ink data | Alpha, GPL-3.0, 7 stars. Developer Mode required. |
| Obsidian equivalents (Scrybble, reMarkable Sync, round-trip plugins) | Mostly one-way | Cloud API or desktop app | Markdown/PDF/OCR | Shows demand for "rM → my PKM tool" |

**Implications (Medium):**
- ReMarkSync has already solved the core one-way problem, including the hard part (ink → OneNote ink), without Developer Mode. **Competing head-on with a v1 clone is weak.**
- The places you could still stand out:
  - **Handwriting → searchable text** pushed into the OneNote page as a text layer. ReMarkSync's FAQ doesn't mention OCR or recognition.
  - **Selective sync by tag or folder**, combined with template-aware page layouts.
  - **A local-only, privacy-first build**, possibly free for personal use.
  - **The return path**, done narrowly and reliably.
- A one-way sync is still a strong portfolio project. It touches OAuth, Microsoft Graph, a binary file format, a sync state machine, and conflict handling, even if it never sells.

### 3.3 Official reMarkable direction (3.20 → 3.28)

Recent releases lean on cloud "Connect" features: Slack (3.20), Handwriting Search (3.22), Convert to Notebook from Word, Google Drive, OneDrive and Dropbox (3.23/3.25/3.28), Miro (3.26), Outlook/Google calendar meeting notes and AI "Convert and share" (3.27), and a web app (3.26+). **None of them involve OneNote or custom templates** (High).

**Risk (Low–Medium speculation):** reMarkable is clearly adding Microsoft-ecosystem integrations, and a "Send to OneNote" share target would fit the Slack and Miro pattern. If it ships, it will most likely be one-way export from the share menu, not continuous sync.

---

## 4. Technical feasibility: rM ↔ OneNote

### 4.1 Getting data off the reMarkable

| Path | Developer Mode? | Read | Write back | Risk |
|---|---|---|---|---|
| **Desktop-app local cache** (ReMarkSync's approach) | No | Yes (.rm v5/v6, metadata) | Possible but risky: the desktop app owns that cache | Breaks if reMarkable changes its cache layout |
| **reMarkable cloud API** (unofficial: rmapi, rmapi-js) | No | Yes | PDF/EPUB upload works. Writing native notebooks needs root-hash updates, and a bad write can corrupt sync. | Unofficial, changes without notice, and the cloud needs a reMarkable account |
| **USB web interface** | No | PDF export only | Upload PDF/EPUB | Lossy: no ink vectors |
| **SSH / on-device daemon** | **Yes** (factory reset on Paper Pro) | Full | Full | Warranty disclaimer. Firmware updates can break it. |

**Recommendation:** Read from the desktop-app cache or the cloud API. Don't depend on Developer Mode for the sync product. Template Manager keeps its SSH dependency, because templates have no other path.

### 4.2 Parsing reMarkable pages
- The v6 `.rm` format is reverse-engineered. `rmscene` (Python) reads it and has an **experimental** writer. `rmc` converts to SVG/PDF (Medium). Paper Pro colors and newer block types appear as unknown blocks in some tools.
- For .NET you would either port the parser (a strong portfolio item in its own right) or call into Python. Porting gives you a clean C# library you can open-source.

### 4.3 Writing to OneNote (Microsoft Graph)
- **Create pages:** `POST /me/onenote/sections/{id}/pages` with HTML plus multipart images and attachments (High).
- **Ink:** OneNote supports **writing InkML** (a `presentation-onenote-inkml` part) and **reading ink back** (`GET …/content?includeInkML=true`). Microsoft announced these as a **beta in 2017**, and I couldn't confirm they're GA (Medium). ReMarkSync's editable-ink output shows the path works in practice.
- **Auth:** App-only auth for OneNote Graph APIs was **retired on 2025-03-31**. Only delegated (signed-in user) auth works (High). That's fine for a desktop app.
- **Limits:** Graph can't delete, rename, or move sections or section groups. Sections have a page cap (HTTP 507). Work and school accounts may need admin consent.
- **Searchability in OneNote:** OneNote can search handwritten ink on Windows and OCR text in images (Medium). For reliable cross-platform search, add recognized text yourself, using local OCR/HTR or a cloud handwriting API.

### 4.4 Can you round-trip?

| Scenario | Feasible? | How |
|---|---|---|
| rM ink → OneNote, searchable | **Yes** (proven) | .rm → InkML, plus an optional OCR text layer |
| OneNote typed text → back on rM | **Partly** | Render as a new page or layer (PDF/image, or a v6 text block through the experimental writer) |
| OneNote pen ink → back on rM | **Technically possible, fragile** | InkML → .rm strokes. Coordinate, pen-type and pressure mapping is lossy. |
| Both sides edit the same page, then merge | **Not realistic** (Medium–High) | No shared change model, unofficial formats, and the reMarkable cloud owns versioning. You'd be building a CRDT over two proprietary systems. |

**Workable two-way design:** reMarkable is the source of truth for ink. OneNote edits come back as an **"annotations from OneNote" layer or an appended page**, and are never merged into the original strokes. Use last-writer-wins per page, with a conflict copy. This matches how you described your own use: you write by pen on the rM, and add typed (sometimes inked) notes in OneNote.

---

## 5. Path forward

### 5.1 Decision: evolve, don't restart

Turn **rM-Template-Manager** into the first module of a product family, working name **reMarkable Buddy**. Check the name first (see 5.4).

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| A. Finish Template Manager only | PRD done, small scope, fast win | Narrow market, RCU exists, needs Developer Mode | Too small alone |
| B. Drop it, build OneNote sync | Bigger market, richer portfolio | ReMarkSync already shipping; high technical risk; slow first demo | Risky as the *first* project after a gap |
| **C. Shared core + Template module first, then OneNote module** | Fast visible win; reuses PRD architecture; sync builds on the same core | Two products to maintain | **Recommended** |

### 5.2 Proposed phases (rough; adjust to your pace)

| Phase | Weeks | Scope | Portfolio signal |
|---|---|---|---|
| **0. Reset** | 1 | Upgrade the PRD to .NET 10. Restructure the repo. Add `CLAUDE.md`/`AGENTS.md`, `tasks.md`, ADRs. Set up CI. | Modern AI-assisted SDLC setup |
| **1. Template Manager MVP** | 3–5 | Domain models, merge engine, SSH deploy with backup and rollback, WPF shell (PRD EU-01…EU-09) | Shipped desktop app, tests, CI, signed release |
| **2. Template preview/editor** | 3–4 | Expression engine, renderer, live preview (EU-10/11) | Parsers, rendering, property-based tests |
| **3. Sync spike (one-way)** | 3–4 | `.rm` v6 parser in C#, Graph OAuth, one notebook → OneNote with ink plus OCR text | API integration, binary formats |
| **4. Decide** | — | Compare against ReMarkSync (has two-way shipped?) and user interest | Product judgment |
| **5. Sync product** | ongoing | Selective sync, state store, the narrow return path from 4.4 | Monetizable |

Phases 1 and 3 can overlap once the shared core exists. For the job search, a **demo video and README** at the end of Phase 1 matter more than finishing Phase 2.

### 5.3 AI tooling decision

| Tool | Cost to you | Fit |
|---|---|---|
| **Claude Code** (CLI, IDE, desktop) | Included in Claude Pro ($20/mo) and above. Session and weekly limits are shared with chat. Max is $100/$200. | **Primary.** Agentic multi-file work, `CLAUDE.md`, skills, hooks, subagents, PR review |
| **Codex CLI** | Included in ChatGPT Plus ($20/mo). Pro tiers $100/$200. | **Secondary:** a second-opinion reviewer and a fallback when Claude limits hit |
| **GitHub Copilot** | Free tier available. Pro $10, Pro+ $39, Max $100. Moved to "AI Credits" billing on 2026-06-01 (Medium, third-party sources). | Optional. The Free tier is enough for IDE completions. |

- **Recommendation:** Spend $0 extra for the first month. Track how often you hit limits. If it's weekly, upgrade **one** plan, whichever tool you prefer by then, rather than adding Copilot.
- **Job-market angle (Medium):** Employers care more about evidence of a disciplined AI workflow than about which tool you used. Show it with:
  - instructions files (`CLAUDE.md`/`AGENTS.md`)
  - small PRs with tests
  - AI-reviewed PRs with human sign-off
  - a short write-up per phase on what the AI did well or badly

  This also makes the project tool-agnostic.

### 5.4 GitHub, licensing and IP strategy

Note: you own the copyright in your code whether it's public or not. A license controls what others may *legally* do with it. It can't physically stop copying, so put the most valuable code where nobody can see it.

**Recommended structure (open-core / showcase):**

| Repo | Visibility | License | Contents |
|---|---|---|---|
| `remarkable-buddy` (or similar) | **Public** | **FSL-1.1** (Functional Source License: any use except a competing commercial product; becomes Apache-2.0/MIT after 2 years) **or PolyForm Noncommercial** | Template Manager app, shared core, docs, ADRs, CI, AI-workflow write-ups. Employers can read and run it. |
| `rm-format` / `rmlines-net` | **Public** | **MIT/Apache-2.0** | A C# `.rm` v6 parser library. Building community goodwill and credibility is worth more than the code. |
| `remarkable-buddy-sync` | **Private** | Proprietary | The OneNote sync engine and conflict logic. Give recruiters a short-lived invite or a screen-share walkthrough. |
| Public showcase page | Public | — | Architecture diagram, demo video, design decisions for the private sync engine |

**Housekeeping:**
- Add `LICENSE`, `NOTICE`, and a copyright header.
- If you ever accept outside contributions, require a CLA or DCO so you keep the right to relicense.
- **Don't copy code** from GPL/AGPL projects (rmOneNoteSync, RCU) into anything you might make proprietary.
- Check each dependency's license before you use it.
- **Trademark (Medium):** "reMarkable" is the company's trademark. A name like "X for reMarkable" is the more common and safer pattern than putting "reMarkable" in your product name. Check their trademark guidelines or consult a lawyer before you buy a domain.
- **Terms of service:** The cloud API is unofficial. Read reMarkable's terms before you sell anything that uses it.

### 5.5 Web presence (later)

- Now: claim a GitHub profile README and a domain or handle for *you* (AI and robotics projects), not for the product. The product name may change.
- After Phase 1: a GitHub Pages site with the demo video, blog posts per phase, and links to the repos.

---

## 6. Open questions for you

1. Is `dadent/rM-Template-Manager` currently public or private?
2. Is Developer Mode already on for your Paper Pro? Your PowerShell workflow suggests yes.
3. Which Claude plan are you on (Pro or Max)? That decides how much Claude Code headroom you have.
4. What's your target time budget per week? The phase durations above assume ~15–20 hrs/week.
5. Do you want to stay Windows/WPF, or go cross-platform (Avalonia/.NET MAUI) to reach the Mac users who make up much of the reMarkable market?

---

## Sources

- reMarkable release notes overview: https://support.remarkable.com/articles/Knowledge/Release-notes-overview
- reMarkable Methods: https://methods.remarkable.com/
- reMarkable Developer Mode docs: https://developer.remarkable.com/documentation/developer-mode
- ReMarkSync: https://www.remarksync.com/ and FAQ https://www.remarksync.com/faq
- rmOneNoteSync: https://github.com/Excustic/rmOneNoteSync
- RCU: https://www.davisr.me/projects/rcu/
- Templacity template guide: https://templacity.com/remarkable/how-to-add-templates-to-remarkable-paper-pro/
- Custom templates guide (vendor): https://brandenbodendorfer.com/remarkable-custom-templates-complete-guide/
- Juri.dev custom template notes: https://juri.dev/notes/custom-template-remarkable
- rmapi-js: https://www.npmjs.com/package/rmapi-js
- rmscene changelog: https://data.safetycli.com/changelogs/rmscene
- Microsoft Graph create OneNote page: https://learn.microsoft.com/graph/onenote-create-page
- OneNote ink beta APIs (2017): https://devblogs.microsoft.com/microsoft365dev/onenote-ink-beta-apis/
- OneNote app-only auth retirement (MC1011142): https://mc.merill.net/message/MC1011142
- Copilot pricing (third-party): https://automationatlas.io/answers/github-copilot-pricing-explained-2026/
- Claude Code pricing (third-party): https://www.morphllm.com/claude-code-pricing
- Codex pricing (third-party): https://uibakery.io/blog/openai-codex-pricing
- PolyForm licenses: https://polyformproject.org/why-adopt-polyform
