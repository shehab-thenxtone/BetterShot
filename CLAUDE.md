# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

BetterShot is a macOS menu-bar screenshot and screen-recording utility (capture → annotate → copy/save/pin/share). It is at the very start of development.

- This checkout (main) contains only `docs/` (requirements + reference screenshots).
- The Swift package scaffold lives in a separate worktree at `.claude/worktrees/scaffold/` (own branch, not yet merged). It holds `Package.swift`, `README.md`, `docs/PLAN.md`, and `Tests/BetterShotCoreTests/` (AppSettings, FilenameTemplate, GIFExportSettings tests). Check that worktree's branch before assuming code exists here.

`docs/REQUIREMENTS.md` is the source of truth for *what* to build (it cites sections like §3.1a, §4.9 — code and plan reference these). `docs/PLAN.md` (in the scaffold worktree) covers *how* and the phase order.

## Commands

Requires macOS 14+ and Xcode 16+ (Swift 6). Pure Swift Package — no Xcode project. Run from the package root (currently the scaffold worktree):

```sh
swift build                                   # build all modules
swift test                                    # run all tests (Swift Testing, not XCTest)
swift test --filter FilenameTemplateTests     # run one test suite / `Suite/testName` for one test
scripts/bundle.sh                             # build build/BetterShot.app (LSUIElement agent, ad-hoc signed)
open build/BetterShot.app
```

`scripts/bundle.sh` is planned in PLAN.md and may not exist yet.

## Architecture

Targets (Package.swift): `BetterShotCore` (pure Swift, no AppKit, no I/O), `BetterShot` (executable app target), `BetterShotCoreTests`. PLAN.md adds `BetterShotAnnotations` and `BetterShotServices` as phases land. Dependencies point strictly downward: `BetterShot` → `Services`/`Annotations` → `Core`. Keep Core free of AppKit and side effects so it stays unit-testable.

Design points that span multiple files:
- **One capture pipeline.** Every mode (area/window/fullscreen/scrolling/OCR/record) yields a `CaptureResult`; a single `CaptureCoordinator` runs mode → capture → result → post-capture action (popup / editor / auto-copy per Preferences). New modes must plug in without UI changes.
- **Destinations are plugins.** `UploadDestination` protocol (`share(_:) async throws -> ShareOutcome`). File hosts (Drive/OneDrive/iCloud) return a link; WhatsApp/Telegram hand off via clipboard/drag with a web fallback — no temp hosting, image-only, no caption.
- **Annotations are immutable data, not views.** Edits produce new document values (undo/redo = snapshot stack); rendering is a pure `flatten(document) -> CGImage`. Pixelate is only made irreversible at flatten (privacy requirement §4.6) — add a test when touching this.
- **Settings** are one `Codable` `AppSettings` struct behind an injected store (UserDefaults); no singletons beyond the app container. Only the single last-closed capture is persisted (Application Support) — no history DB.
- **OCR** sits behind an `OCRProvider` protocol (Vision, English only at launch; languages are a parameter).
- **Hotkeys** use Carbon `RegisterEventHotKey` to avoid Accessibility prompts (§4.3).
- Local Storage save is silent (no dialog) into the last-picked folder; GIF export is capped at 30 fps with Auto/Manual modes and a live size estimate (§3.1a).

No third-party dependencies at launch. OAuth client IDs must come from config, never hardcoded. iCloud needs an entitlement that plain SwiftPM can't carry (revisit packaging at the Destinations phase).

## Gotchas

- Reference screenshots in `docs/reference/` show another product's branding ("CleanShot"); do not copy its name, icons, or assets. `unrelated-form-validation.png` has no bearing on this app.
- Rebuilding with ad-hoc signing can re-trigger the macOS Screen Recording (TCC) prompt.
