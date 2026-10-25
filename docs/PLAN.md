# BetterShot — Architecture & Implementation Plan

Source of truth for *what*: [REQUIREMENTS.md](REQUIREMENTS.md). This doc covers *how* and *in what order*.

## 1. Stack decisions

| Concern | Choice | Why |
|---|---|---|
| Language / UI | Swift 6, AppKit shell + SwiftUI views | Menu-bar agent, floating panels and global hotkeys need AppKit; SwiftUI for editor toolbar, preferences, popups. |
| Min OS | macOS 14 | `SCScreenshotManager` (ScreenCaptureKit still capture); Vision OCR. |
| Build | Swift Package (no Xcode project) + `scripts/bundle.sh` producing `BetterShot.app` | No generated project files, diff-friendly, `swift test` works in CI. |
| Capture | ScreenCaptureKit | Apple's supported path; window shadow, multi-display, recording. |
| OCR | Vision `VNRecognizeTextRequest` behind an `OCRProvider` protocol | English only at launch; languages are a parameter so packs can be added later. |
| Hotkeys | Small Carbon `RegisterEventHotKey` wrapper | No Accessibility prompt needed (req. §4.3). |
| Recording / GIF | AVFoundation (MP4) + ImageIO (GIF) | Native, no ffmpeg. |
| Persistence | `UserDefaults` (settings), Application Support (last-closed capture) | No database needed. |
| Tests | Swift Testing | Ships with the toolchain. |

No third-party dependencies at launch.

## 2. Module layout

Dependencies point strictly downward: `BetterShot` → `Services` / `Annotations` → `Core`.

```
Sources/
├── BetterShotCore/          Pure Swift. No AppKit, no I/O. Fully unit-testable.
│   ├── Capture/             CaptureMode, CaptureResult
│   ├── Settings/            AppSettings (Codable), FilenameTemplate, GIFExportSettings (+size estimate)
│   ├── Destinations/        UploadDestination protocol, ShareOutcome
│   └── OCR/                 OCRProvider protocol
├── BetterShotAnnotations/   Annotation document model + renderer (CoreGraphics). No UI.
│   ├── Model/               Annotation, AnnotationDocument
│   ├── History/             Undo/redo (value-type snapshots)
│   └── Render/              flatten(document) -> CGImage  (pixelate destructive here → req. §4.6)
├── BetterShotServices/      Side-effecting implementations of Core protocols.
│   ├── Capture/             ScreenCaptureKit capturer, scrolling stitcher
│   ├── Recording/           MP4 recorder, GIF encoder
│   ├── OCR/                 VisionOCRProvider
│   ├── Storage/             LocalStorage (last folder), RecentlyClosedStore (single slot)
│   └── Destinations/        GoogleDrive, OneDrive, ICloud, WhatsApp, Telegram
└── BetterShot/              App target (executable). AppKit/SwiftUI only.
    ├── App/                 @main, AppDelegate, dependency container
    ├── MenuBar/             NSStatusItem + menu (§3.1 items 1–17)
    ├── Capture/             CaptureCoordinator (permission → overlay → capture → hand-off), alerts, clipboard sink
    ├── Hotkeys/             Global shortcut registry + remapping
    ├── Overlay/             Crosshair/area/window selection windows
    ├── Preview/             Floating post-capture popup (§3.2)
    ├── Editor/              Editor window + toolbar (§3.3)
    ├── ResultBar/           "Drag me" bar + pinned image windows (§3.4)
    └── Preferences/         Settings window (§5)
Tests/                       One test target per library module.
docs/                        REQUIREMENTS, PLAN, reference screenshots.
scripts/                     bundle.sh (builds .app: Info.plist, LSUIElement, ad-hoc signing).
```

Folders appear as the phase that needs them lands — none are created empty.

### Key design points
- **One capture pipeline.** Every mode yields a `CaptureResult` (image or video URL). A single `CaptureCoordinator` runs *mode → capture → result → post-capture action* (popup / editor / auto-copy per Preferences). New modes plug in without touching UI.
- **Destinations are plugins.** `UploadDestination` (`id`, `displayName`, `share(_:) async throws -> ShareOutcome`). File hosts return a link; messaging targets hand off via clipboard/drag (no temp hosting, image-only — §4.9). Adding Dropbox/Slack/S3 = one new type + registration.
- **Annotations are data, not views.** Document is an immutable value; edits produce new values, so undo/redo is a snapshot stack and rendering is a pure function. Pixelate becomes destructive only at `flatten`, keeping editing non-destructive until Done.
- **Settings are one `Codable` struct** behind a small store, injected — no singletons beyond the app container.
- **Last closed capture only** — single-slot store, no history DB (§4.4).

## 3. Delivery phases (one or more commits per phase; tests first in Core/Annotations)

| # | Phase | Outcome |
|---|---|---|
| 0 | Scaffold | Repo, package, docs; `swift build` / `swift test` green. |
| 1 | Core models + settings | `AppSettings`, `FilenameTemplate`, `GIFExportSettings` (30 fps cap, presets, size estimate), tested. |
| 2 | Menu bar shell | Agent app (`LSUIElement`), status item, full §3.1 menu wired to a stub coordinator, `bundle.sh`. |
| 3 | Permission + fullscreen/area/window capture | ScreenCaptureKit, overlay, multi-display, Capture Previous Area. |
| 4 | Post-capture popup | Copy / Save (silent, last folder) / Pin / Cloud / auto-dismiss / click-to-edit. |
| 5 | Global hotkeys + Preferences | Remappable shortcuts; General, Shortcuts, Destinations tabs. |
| 6 | Annotation model + renderer | All tools as data, undo/redo, flatten, privacy test (pixelate irreversible). |
| 7 | Editor UI | Toolbar per reference, crop, merge tool, Save as…, Done. |
| 8 | Pin + result bar | Always-on-top pinned windows, "Drag me" bar, share sheet. |
| 9 | OCR (Capture Text) | Vision provider, English, text to clipboard. |
| 10 | Self-timer, Hide Desktop Icons, Open…, Restore Recently Closed | Small menu features. |
| 11 | Recording | MP4 default, PNG frame, GIF auto/manual with live size estimate. |
| 12 | Scrolling capture | Vertical + horizontal stitching. |
| 13 | Destinations | iCloud, Google Drive, OneDrive (OAuth), WhatsApp/Telegram handoff + web fallback. |
| 14 | Polish | Light/dark, VoiceOver labels, tooltips, <200 ms check, update check. |

**Status:** phases 0–4 done. After a capture the preview popup appears bottom-right with Copy, Save (silent, remembered folder, never overwrites) and Upload (follows the default storage target; only Local exists yet). Pin is disabled until phase 8 and clicking the thumbnail does nothing until the phase 7 editor. Settings use defaults until phase 5 persists them. Interactive behaviour (overlay drag, Space-to-move, arrow nudging, window hover, multi-display, popup placement/dismissal) is implemented but needs manual verification with Screen Recording permission granted.

## 4. Risks & open items
- **Screen-recording permission (TCC):** ad-hoc rebuilds can re-prompt; `bundle.sh` signs with a stable identity when available (§4.3).
- **Scrolling capture** must drive another app's scroll (Accessibility or synthesized events) — highest risk; spike early in phase 12.
- **WhatsApp/Telegram detection** via `NSWorkspace` bundle-ID lookup; web fallback = clipboard image + open web client.
- **OAuth** for Drive/OneDrive needs client IDs from the product owner; read from config, never hardcoded.
- **iCloud** needs an entitlement + provisioning that plain SwiftPM can't carry; revisit packaging (Xcode project or signed bundle) at phase 13.
- Reference screenshots show another product's branding ("CleanShot"). BetterShot must not copy its name, icons or assets. `docs/reference/unrelated-form-validation.png` is a form-error screenshot with no bearing on this app.
