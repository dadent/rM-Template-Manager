# Coding Standards

*Status: **Proposed** — awaiting review and approval.*
*Version 0.1 · 2026-10-16*

A **living document.** It is deliberately separate from `PRD.md` (what to build) and the
[ADRs](architecture/decisions/) (which technologies and structures, and why). This file
answers a narrower question: *how is code in this repository written?*

It is binding on humans and AI agents alike. `CLAUDE.md` and `AGENTS.md` both point here
rather than restating any of it.

---

## 1. How this document is maintained

This file grows from review findings, per
[ADR-0009](architecture/decisions/0009-two-model-ai-review-chain.md).

- When a review comment concerns a **convention or idiom**, the fix is not complete until
  the rule is recorded here. Fixing only the instance guarantees the next agent repeats it.
- When Claude's personas and Codex **disagree on style**, that is a gap in this document.
  Settle it once, write it down, and both follow it from then on. The same preference is
  never re-litigated on a second PR.
- Structural or technology decisions belong in an ADR, not here. If a proposed rule needs a
  paragraph of justification, it is probably an ADR.
- **Prune as deliberately as you append.** A standard too long to read is a standard nobody
  follows. Rules that the compiler, analyzers, or `.editorconfig` already enforce should be
  deleted from this prose — mechanical enforcement beats documentation every time.

Each rule is tagged with how it is enforced:

- **[build]** — compiler or analyzer; violating it fails the build
- **[test]** — an automated test asserts it
- **[review]** — judgment; checked by reviewers

The analyzer configuration behind every **[build]** tag is specified in
[ADR-0010](architecture/decisions/0010-static-analysis-and-validation-gates.md). Most of
§13 (Forbidden) is enforced by `BannedSymbols.txt`, so those entries are build errors that
quote their own rationale rather than conventions a reviewer has to remember.

**Promoting a rule from [review] to [build] is always worth doing.** Per
[ADR-0009](architecture/decisions/0009-two-model-ai-review-chain.md), review is an
iterative loop, so a rule the compiler enforces costs seconds while the same rule enforced
by a reviewer costs a full convergence round. If a rule here could plausibly be an
analyzer rule, that is a backlog item, not a permanent state.

---

## 2. Non-negotiables

1. **Nullable reference types are enabled everywhere, and warnings are errors.** **[build]**
   No `#nullable disable`. No `!` null-forgiving operator without an adjacent comment
   justifying it.
2. **The Domain layer has no IO and no third-party packages.** **[test]**
   See `architecture/overview.md` §3.1 and §7.
3. **Passwords never reach a log sink, an exception message, or disk.** **[test]**
4. **Generated `templates.json` is UTF-8 without BOM, with LF line endings.** **[test]**
   Per `PRD.md` §10.1.
5. **No device write without a preceding backup.** **[test]**
6. **Formatting is settled, not negotiable** — see §14, enforced by `.editorconfig`. **[build]**

---

## 3. Language and types

- Target the latest C# language version; prefer current idioms (collection expressions,
  pattern matching, primary constructors where they genuinely shorten code).
- **Domain types are immutable.** Use `record` / `readonly record struct` for values;
  `sealed class` with private setters where a record does not fit. **[review]**
- `sealed` by default on classes. Open for inheritance only with a reason. **[review]**
- Prefer `IReadOnlyList<T>` / `IReadOnlyDictionary<K,V>` on public surfaces. Never expose a
  mutable collection from a domain type. **[review]**
- Use strongly typed identifiers over bare `string` where confusion is possible — e.g. a
  template `filename` is an identity, not arbitrary text. **[review]**
- `var` when the type is evident from the right-hand side; the explicit type otherwise.
- No `#region`. If a file needs regions to be navigable, it needs splitting.

## 4. Error modeling

- **Expected outcomes are return values, not exceptions.** A merge conflict, a failed
  pre-flight check, and an unparsable template are *results* the caller inspects. Reserve
  exceptions for genuine faults — broken invariants, unreachable states. **[review]**
- Never catch `Exception` except at a top-level boundary (UI command handler, workflow
  entry point), and never swallow one silently. **[review]**
- Validation returns *all* findings, not the first. A user fixing a template wants the full
  list. **[review]**
- Diagnostics name the thing that failed and where: which template, which expression, which
  identifier. `"Invalid expression"` is not an acceptable message. **[review]**

## 5. Async

- All IO is `async`, returns `Task`/`Task<T>`, and accepts a `CancellationToken`. **[review]**
- No `async void` outside WPF event handlers. No `.Result`, no `.Wait()`, no
  `GetAwaiter().GetResult()`. **[build]** (analyzer)
- Suffix async methods `Async`.
- Use `ConfigureAwait(false)` in Domain, Application, and Infrastructure; omit it in UI code
  that must resume on the dispatcher. **[review]**

## 6. Naming and file organization

- One public type per file; the filename matches the type.
- Namespaces match folder structure, rooted at `RmTemplateManager.<Layer>`.
- Interfaces are `I`-prefixed and named for the role, not the implementation:
  `ISshTransport`, not `ISshNetWrapper`.
- Avoid `Helper`, `Util`, `Manager`, and `Service` as type-name suffixes — they describe
  nothing. Name what it does: `MergeEngine`, `ExpressionParser`, `BackupStore`. **[review]**
- No abbreviations except established domain terms (`Ssh`, `Json`, `Rm`).

## 7. JSON and encoding

- `System.Text.Json` only. No Newtonsoft. **[review]**
- Serializer options are declared once in a shared, explicitly configured instance. Never
  rely on defaults for files written to the device. **[review]**
- **Round-trip fidelity is a hard requirement.** Reading and rewriting a device manifest
  without logical changes must produce byte-identical output — including entry order and
  `\uXXXX` glyph escapes. **[test]**
- Never reorder, normalize, or "tidy" a manifest. Append only, per `PRD.md` §4.4.

## 8. Logging and secrets

- Serilog with **structured** parameters: `logger.Information("Uploaded {File} to {Path}",
  file, path)`. Never string interpolation into a log template. **[review]**
- Levels: `Debug` for diagnostics, `Information` for lifecycle, `Warning` for recoverable
  or overridden conditions, `Error` for failures, `Fatal` for unrecoverable.
- **Every SSH command, file transfer, merge decision, and pre-flight result is logged.**
- A password, or any object that could contain one, is never a log parameter. Credentials
  are held in a dedicated type whose `ToString()` returns a redaction marker. **[test]**

## 9. Dependency injection

- Constructor injection only. No service locator, no static mutable state, no singletons
  reached through a global. **[review]**
- All registration happens in the WPF composition root. It is the only project permitted to
  reference Infrastructure concretely. **[test]**
- Inject `IClock` rather than calling `DateTime.Now`; inject abstractions rather than
  touching `Environment` or `File` directly. Untestable time and IO is a defect. **[review]**

## 10. Testing

- xUnit. Test project names mirror the project under test, suffixed `.Tests`.
- Test names state the behavior: `Merge_WhenFilenameExistsWithDifferentEntry_ReportsConflict`.
  Not `TestMerge3`. **[review]**
- Arrange / Act / Assert, visually separated. **[review]**
- **No logic in tests** — no loops or conditionals deciding what to assert. Use
  `[Theory]`/`[InlineData]` for variation. **[review]**
- One behavior per test. Multiple assertions are fine when they describe one outcome.
- Builders or fixture factories for test data; never a wall of inline object construction
  repeated across tests. **[review]**
- Coverage targets per `PRD.md` §11.1: >80% overall, **100% on the merge and expression
  engines.** Coverage is a floor, not a goal — an untested branch in the merge engine is a
  defect regardless of the percentage.
- Golden-file tests run against the firmware-versioned corpus in `TestKit`. A corpus file is
  never edited to make a test pass.
- Every bug fix starts with a failing test that reproduces it. **[review]**

## 11. WPF and MVVM

- `CommunityToolkit.Mvvm` source generators: `[ObservableProperty]`, `[RelayCommand]`. No
  hand-written `INotifyPropertyChanged` plumbing. **[review]**
- **ViewModels contain no device, filesystem, or SSH knowledge.** They call Application
  services and shape results for display. **[test]**
- No business logic in code-behind. `.xaml.cs` holds view concerns only — ideally just the
  constructor. **[review]**
- No logic in value converters beyond formatting.
- Every long-running command reports progress and is cancellable. **[review]**
- ViewModels are unit-tested; Views are not tested. **[review]**

## 12. Comments

- Comment **why**, never **what**. The code states what it does. **[review]**
- XML doc comments on public Domain and Application surfaces — these are the project's
  conceptual vocabulary.
- A comment explaining a non-obvious device behavior, firmware quirk, or format constraint
  is valuable; cite the source (an ADR, a research document, or an observation).
- No commented-out code. No `TODO` without a linked issue number. **[review]**

## 13. Forbidden

Entries marked **[banned]** are enforced by `BannedSymbols.txt` and fail the build with a
message citing this section. The rest are review items until someone mechanizes them.

| Pattern | Why |
|---|---|
| `catch (Exception) { }` | Hides the failures this product most needs to surface |
| `DateTime.Now` in Domain/Application | Untestable; inject `IClock` **[banned]** |
| `System.IO` in Domain/Application | Breaks the layering contract **[test]** |
| Newtonsoft.Json | One serializer; byte-level output control matters here **[banned]** |
| String-interpolated log messages | Defeats structured logging |
| `.Result` / `.Wait()` | Deadlock risk on the UI thread **[banned]** |
| Reordering or reformatting a device manifest | Violates the append-only invariant |
| Editing a corpus fixture to make a test pass | Destroys the regression baseline |
| Silent fallback on an unparsable expression | Renders a plausible-looking wrong template |

---

## 14. Formatting and layout

*Owner preferences, recorded 2026-10-21. All three are mechanically enforceable, so they
live in `.editorconfig` and are* **[build]** *rules rather than review items.*

Appended as §14 rather than inserted near the top so that existing §-references from the
ADRs stay valid; it moves when this document is next restructured.

### 14.1 Indentation — four spaces, never tabs

```ini
indent_style = space
indent_size  = 4
tab_width    = 4
end_of_line  = lf
```

`end_of_line = lf` is added for consistency with the LF requirement the project already
has for generated device files, and to keep diffs free of line-ending noise.

### 14.2 Braces — opening brace on its own line (Allman)

```csharp
if (batteryPercent < MinimumSafePercent)
{
    return PreflightResult.Blocked(LowBattery);
}
```

Not `if (…) {` with a trailing brace.

```ini
csharp_new_line_before_open_brace = all
csharp_new_line_before_else  = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
```

Worth noting: this is already the idiomatic C# convention, unlike C and C++ where K&R
bracing is common. So the preference costs nothing in friction — default templates,
analyzers, and `dotnet format` all expect it.

### 14.3 Parentheses — liberal, for order-of-execution clarity

Prefer explicit parentheses around sub-expressions even where operator precedence already
produces the right answer. `(a * b) + c` over `a * b + c`. The reader should not have to
recall a precedence table to verify intent.

```ini
dotnet_style_parentheses_in_arithmetic_binary_operators = always_for_clarity:suggestion
dotnet_style_parentheses_in_relational_binary_operators = always_for_clarity:suggestion
dotnet_style_parentheses_in_other_binary_operators      = always_for_clarity:suggestion
dotnet_style_parentheses_in_other_operators             = never_if_unnecessary:silent
```

**This configuration is load-bearing, not decorative.** Left at its defaults,
`AnalysisMode=All` reports `IDE0047` — "remove unnecessary parentheses" — and would flag
every clarifying parenthesis as a diagnostic to fix. Setting `always_for_clarity` inverts
that: the analyzer stops objecting to deliberate parentheses and instead *suggests adding*
them where precedence is non-obvious.

So this is the first concrete instance of the tuning that
[ADR-0010](architecture/decisions/0010-static-analysis-and-validation-gates.md) predicted
would be necessary — an analyzer default that contradicts a deliberate house style, fixed
by configuring the individual rule rather than by lowering the analysis mode. The last
line is kept at `never_if_unnecessary` so that genuinely redundant parentheses around
single operands are still discouraged.

This preference pays off twice over in the expression engine
([ADR-0006](architecture/decisions/0006-expression-grammar-scope.md)), where precedence is
the subject matter and ambiguity in our own code would be especially poor form.
