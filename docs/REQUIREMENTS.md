# Screenshot & Screen Capture Utility — Requirements Specification

*Derived from UI analysis of 4 reference screenshots: menu bar dropdown, post-capture preview popup, annotation editor toolbar, and floating results bar.*

---

## 1. Overview

A macOS menu-bar screenshot and screen-recording utility that lets a user capture the screen (fullscreen, window, area, or scrolling content), optionally annotate the result, and then quickly copy, save, pin, or upload it — all without leaving the current workflow.

**Core design principles observed:**
- Every action is reachable from one central dropdown menu with keyboard shortcuts.
- After every capture, the user gets an immediate, non-blocking preview with quick actions (copy/save) before deciding whether to annotate or discard.
- Annotation happens in a dedicated lightweight editor window, not a separate heavyweight app.
- Results can be "pinned" to the desktop as floating always-on-top images instead of being saved immediately.

---

## 2. Primary User Flow

```
[Menu Bar Icon Click / Global Hotkey]
        ↓
[Capture Mode Selection] → (Area / Window / Fullscreen / Scrolling / OCR / Record)
        ↓
[Live Capture Interaction] (crosshair select, window highlight, countdown if self-timer)
        ↓
[Floating Preview Thumbnail Appears] (bottom-right corner, auto-dismiss timer)
        ↓
    ┌───────────────┬────────────────┬───────────────┐
    │   Click Copy    │   Click Save     │  Click thumbnail │
    │  (to clipboard) │  (to disk)       │  (opens editor)  │
    └───────────────┴────────────────┴───────────────┘
                                              ↓
                                    [Annotation Editor Opens]
                                              ↓
                            (Crop / Shapes / Text / Arrows / Blur / etc.)
                                              ↓
                                  [Save As... / Done]
                                              ↓
                              [Floating "Drag me" Result Bar]
                                              ↓
                  (Pin to screen / Share / Copy / Upload to cloud)
```

---

## 3. Feature Requirements by Module

### 3.1 Capture Menu (Menu Bar Dropdown)

| # | Item | Shortcut | Requirement |
|---|------|----------|-------------|
| 1 | All-In-One | ⇧⌘5 | Single entry point that lets the user choose capture type interactively (area/window/fullscreen) from one crosshair-driven UI, rather than pre-selecting a mode from the menu. |
| 2 | Capture Area | ⇧⌘4 | User drags a rectangular marquee; capture is bound to the selected region. Must support pixel-perfect drag, arrow-key nudging, and Space-to-reposition-while-dragging. |
| 3 | Capture Previous Area | — | Repeats the last-used area selection without requiring the user to redraw it. Useful for repeated captures of the same UI region (e.g., monitoring a changing dashboard). |
| 4 | Capture Fullscreen | ⇧⌘3 | Captures the entire active display. Must support multi-display setups (capture the display under the cursor, or prompt for which display). |
| 5 | Capture Window | (highlighted state shown) | Hovering highlights individual windows under the cursor with a colored border; clicking captures just that window, including drop shadow, with transparent background where applicable. |
| 6 | Scrolling Capture | — | Captures a full scrollable region (e.g., a long webpage or chat thread) by auto-scrolling and stitching multiple frames into one continuous image. Must support **both vertical and horizontal** scroll stitching (e.g., vertical for webpages/chat threads, horizontal for wide spreadsheets or timelines/Gantt charts). |
| 7 | Self-Timer | — | Adds a configurable delay (e.g., 3/5/10s) before triggering a capture, giving the user time to set up UI state (open a menu, hover a tooltip, etc.). |
| 8 | Capture Text (OCR) | — | Runs on-device OCR against a selected region and copies the recognized text to the clipboard instead of an image. **Launch scope: English only.** Architecture should allow additional language packs to be added post-launch without a redesign of the OCR pipeline. |
| 9 | Record Screen | — | Starts a screen recording session (area or fullscreen) with its own stop/pause controls. Output formats: **PNG** (for still/frame capture), **MP4** (video), and **GIF**, with **MP4 as the default selected format** when the user chooses to record. **No size or length limits** are imposed by the app (subject only to available disk space). **GIF export is dual-mode:** by default, frame rate/quality are **derived automatically from the source MP4**; the user can switch to a **manual mode** to set frame rate and quality/compression explicitly (see §3.1a for preset values). |
| 10 | Hide Desktop Icons | — | Toggle to temporarily hide all desktop icons before a fullscreen capture, then automatically restore them after. |
| 11 | Open... | — | Opens a saved screenshot/recording file from disk directly into the editor. |
| 12 | Pin to the Screen... | — | Lets the user pin an existing image file to the desktop as a floating always-on-top window (see 3.4). |
| 13 | Restore Recently Closed File | ⌘Z | Undo-style recovery of the last closed/discarded capture (mirrors browser's "reopen closed tab" pattern). |
| 14 | About [App] | — | Standard app info panel (version, credits). |
| 15 | Check for Updates | — | Manual update check trigger. |
| 16 | Preferences | ⌘, | Opens the settings window (see §4). |
| 17 | Quit | — | Terminates the app, with confirmation only if a recording is in progress. |

**Functional requirements:**
- Menu must be accessible via a persistent menu-bar icon at all times (app runs as background/agent process).
- All items with shortcuts must have those shortcuts globally registered and user-remappable in Preferences.
- The menu must visually indicate the currently-hovered item (see highlighted "Capture Window" state in the reference).
- Menu should support being triggered while another app is in focus without stealing focus unnecessarily.

#### 3.1a GIF Manual Export Mode — Preset Values

When the user switches GIF export from **Auto** to **Manual**, the export panel should expose the following (chosen to match common conventions in comparable capture tools, favoring the values most people actually pick rather than an exhaustive technical range):

| Control | Presets / Range | Default |
|---|---|---|
| Frame rate | 10 / 15 / 20 / 24 / 30 fps (stepper or dropdown). **30 fps is a hard ceiling** — no free-entry above it, given GIF's diminishing returns past that point | **15 fps** — the standard "smooth enough, small enough" sweet spot for UI/tutorial GIFs |
| Quality / color depth | Low (64 colors), Medium (128 colors), High (256 colors) | **Medium (128 colors)** |
| Dithering | On / Off toggle | **On** (reduces banding at lower color counts with minimal size cost) |
| Resolution scale | 100% / 75% / 50% of source recording | **100%**, with 50–75% suggested inline for long recordings |
| **Live file-size estimate** | Recalculated on every control change, shown next to the export button (e.g., "~4.2 MB") | Always shown in manual mode |

The Auto mode intentionally hides all of the above and simply reuses the source MP4's frame rate (capped at 30fps for GIF, since GIF has no benefit beyond that) and defaults to the same Medium/128-color/dithering-on settings.

---

### 3.2 Post-Capture Floating Preview (Popup Thumbnail)

Appears immediately after any capture completes, anchored to a screen corner (bottom-right in reference).

| Element | Requirement |
|---|---|
| Thumbnail image | Live preview of the captured content, small fixed size, rounded corners, drop shadow to look "on top of" the desktop. |
| Pin icon (top-right badge) | One click pins the capture as a persistent floating window on the desktop (does not require opening the editor). |
| **Copy** button | Copies the full-resolution image to the system clipboard immediately; closes the popup after action. |
| **Save** button | Saves directly to disk with **no dialog**, using the **last folder the user picked** (see §4.9's Local Storage behavior) with a system-appropriate filename convention (e.g., `Screenshot 2026-08-26 at 11.30.34.png`). The save-location only changes if the user explicitly updates it (e.g., via "Save As..." in the editor or in Preferences). |
| Cloud icon (bottom-right badge) | Uploads the image to the user's **configured default** destination and copies a shareable link (or shares directly, for chat-app destinations) to clipboard. See §4.9 for the supported destination list. |
| Auto-dismiss | Popup should auto-hide after a configurable timeout (e.g., 5–10s) if the user takes no action, without discarding the underlying capture (it should remain in a temporary buffer/history). |
| Click-to-edit | Clicking the thumbnail itself (not the buttons) opens the full annotation editor. |

**Functional requirements:**
- Popup must not block interaction with the rest of the screen (non-modal, click-through outside its bounds).
- Popup must be dismissible via Escape key or click-elsewhere.
- All actions (Copy/Save/Pin/Upload) must be available without ever opening the editor, to support a "fast capture" workflow.

---

### 3.3 Annotation Editor Toolbar

Opened when the user clicks into a captured image to mark it up. Toolbar is arranged left-to-right by function group.

**Window controls:** Standard traffic-light close/minimize/zoom buttons.

**Left tool group — transform:**
| Tool | Requirement |
|---|---|
| Crop | Interactive crop handles on the image; supports free-form and fixed-ratio cropping. |
| Combine/Add (icon with "+") | **Merge tool.** Lets the user add a new image into the current canvas either by (a) importing an existing image file from disk, or (b) triggering a brand-new capture (area/window/fullscreen) that gets merged directly into the open canvas — e.g., to stitch two screenshots side by side without leaving the editor. |

**Middle tool group — selection & shapes:**
| Tool | Requirement |
|---|---|
| Selection/Pointer | Default tool for selecting, moving, and resizing already-placed annotation objects. |
| Rectangle (outline) | Draws an unfilled rectangle annotation. |
| Rectangle (filled) | Draws a solid/filled rectangle, e.g. for redaction blocks. |
| Ellipse/Circle | Draws an outlined ellipse annotation. |
| Line | Draws a straight line, ideally with Shift-to-constrain to 45°/90° angles. |
| Arrow *(active/selected in reference)* | Draws a directional arrow with arrowhead; must support drag-to-set start/end and live angle preview. |
| Text ("A") | Inserts an editable text box with configurable font size/color, click-to-place. |
| Pixelate/Mosaic | Applies a censor/blur effect over a dragged region — must be non-reversible once flattened, for privacy redaction. |
| Step Counter (numbered circle) | Places sequential numbered badges (1, 2, 3…) — auto-increments with each new placement, used for tutorial-style callouts. |
| Highlighter/Marker | Semi-transparent freehand or straight highlight stroke over content — used for marking up general image regions. |
| Pen/Freehand draw | Freehand drawing tool, pressure-sensitive if trackpad/tablet input is available. |
| Text Highlighter (badge icon) | A **text-aware highlighter**, distinct from the general marker above: runs OCR/text-detection under the hood so the highlight stroke snaps to and covers actual text characters/lines cleanly (like highlighting in a PDF), rather than being a freehand stroke over arbitrary pixels. |

**Right tool group — style controls:**
| Control | Requirement |
|---|---|
| Color swatch (purple circle) | Opens a color picker; applies to whichever tool/annotation is currently active or selected. Must remember last-used color per tool. |
| Line weight selector | Cycles or opens a menu of stroke widths (thin/medium/thick). |
| Arrow style selector | Choose arrowhead style/direction variants. |

**Action group (far right):**
| Button | Requirement |
|---|---|
| Save as... | Opens a save dialog to export the annotated result as a new file (format options: PNG, JPG, PDF, etc.). |
| Done | Finalizes editing, flattens annotations onto the base image, and transitions to the floating result bar (§3.4) or closes back to clipboard/save flow. |

**Functional requirements:**
- All drawing tools must support undo/redo (⌘Z / ⇧⌘Z) at the individual-annotation level, not just whole-image level.
- Annotations must remain non-destructively editable (movable, resizable, restylable) until the user clicks "Done" or exports.
- Keyboard shortcuts should be assignable to each tool (e.g., `R` for rectangle, `A` for arrow — standard in this class of app).
- Color and line-weight settings must persist as defaults across editor sessions.

---

### 3.4 Floating Result Bar ("Drag me")

A minimal floating control strip that appears docked to an edge of the screen once a capture/edit is finalized, or when an image is explicitly "pinned."

| Element | Requirement |
|---|---|
| Pin icon (far left) | Toggles whether this floating bar/image stays pinned above all other windows persistently. |
| "Drag me" handle (center) | Grab handle allowing the user to reposition the floating bar/pinned image anywhere on screen; must support multi-monitor dragging. |
| Share icon | Opens the native OS share sheet (Mail, Messages, AirDrop, third-party share extensions). |
| Copy icon | Copies current image to clipboard. |
| Cloud upload icon | Uploads to the user's configured default destination and copies a shareable link (or shares directly, for chat-app destinations). See §4.9 for the supported destination list. |

**Functional requirements:**
- The bar should auto-hide/fade when not hovered, and reveal on mouse-over, to stay unobtrusive.
- Pinned images must remain interactive (resizable via drag corners, closable via a hover-revealed close button, and keep their own right-click context menu with Copy/Save/Delete/Open in Editor).
- Bar must respect window-level "always on top" behavior without stealing keyboard focus from the active app.

---

## 4. Cross-Cutting / Non-Functional Requirements

1. **Performance:** Capture-to-preview latency should be under ~200ms for area/window/fullscreen capture on supported hardware.
2. **Native feel:** UI must follow macOS HIG — vibrancy/blur backgrounds, rounded corners, SF Symbols-style iconography, light/dark mode support (all reference screenshots show a translucent purple/violet vibrancy background consistent with macOS system materials).
3. **Global hotkeys:** All primary actions must work system-wide regardless of which app currently has focus, without requiring accessibility-permission prompts to reappear each session.
4. **History/recents:** Retention is limited to the **single most-recently closed/discarded capture** ("Restore Recently Closed File" — see menu item 13). There is **no searchable history panel or capture library** at launch; only the last file is recoverable, and it is overwritten the next time a capture is discarded.
5. **Multi-display support:** Menu, popups, and floating bar must correctly target the display under the user's cursor.
6. **Privacy:** Pixelate/redaction annotations must be irreversibly flattened on export — the underlying pixels must not be recoverable from the exported file.
7. **Extensibility:** Cloud upload destination, default save folder, filename format, and post-capture auto-actions (e.g., "always copy," "always open editor") should be configurable in Preferences.
8. **Accessibility:** All icon-only buttons require descriptive tooltips and VoiceOver labels.
9. **Supported upload / share destinations:** The cloud icon (in both the post-capture popup and the floating result bar) must support, at minimum, the following out of the box:
   - **Google Drive**
   - **OneDrive**
   - **iCloud** (native first-party storage)
   - **WhatsApp**
   - **Telegram**
   - *(extensible list — additional providers such as Dropbox, Slack, or S3 can be added as plugin-style integrations post-launch)*

   Each destination requires its own OAuth/account-linking flow in Preferences (see §5). For file-storage destinations (Google Drive, OneDrive, iCloud) the result is an uploaded file + copied shareable link. For messaging destinations (WhatsApp, Telegram) the result is a direct share/send action into that app rather than a link-copy, since these are chat targets, not file hosts.

   **Messaging fallback behavior:** For WhatsApp and Telegram, the app first attempts to hand off to the **installed desktop app** (if present and logged in). If the desktop app is **not installed**, the flow automatically **falls back to a web-share path** (the provider's web client). This fallback **never requires temporary server-side hosting** — the image is handed off entirely through OS-native mechanisms (system clipboard image data and/or OS drag-and-drop into the browser's drop target), so the user can paste or drop the image straight into WhatsApp Web / Telegram Web without the app uploading it anywhere first. The handoff is **image-only** — no accompanying caption, filename text, or "Shared via [App]" text is appended to the clipboard alongside the image.

   **Default storage target:** The cloud icon's one-click behavior is driven by a single configurable **default storage target** set in Preferences, chosen from the full destination list above:
   - **Local Storage** — saves directly to disk, **silently and with no dialog**, to the **last folder the user picked** (defaulting to the standard Screenshots folder on first use). The save-location picker only reappears if the user explicitly changes the destination folder (e.g., via "Save As..." in the editor, or by updating the default folder in Preferences) — it does not prompt on every capture.
   - **Any linked cloud provider** — e.g. **Google Drive**, **OneDrive**, or **iCloud** — uploads to that provider and copies a shareable link. No separate first-party "app storage" destination is required; the supported providers are exactly Google Drive, OneDrive, and iCloud (plus the messaging targets for direct share).

   Per-capture-type default overrides (e.g., always sending recordings to a different target than screenshots) are noted as a candidate for a future release rather than a launch requirement.

---

## 5. Preferences (Implied Requirements)

Not directly visible in the screenshots but required to support the observed behaviors:
- Default capture folder location (used when "Local Storage" is the default target)
- Default filename template
- Auto-dismiss timing for the post-capture popup
- **Default storage target** for the cloud icon: **Local Storage** or a linked cloud provider (**Google Drive**, **OneDrive**, **iCloud**) — see §4.9
- Account linking / OAuth for each optional destination: Google Drive, OneDrive, iCloud, WhatsApp, Telegram
- **GIF export mode**: Auto (derive from MP4 recording) vs. Manual (frame rate, color/quality, dithering, resolution scale — see §3.1a), plus the manual controls themselves when Manual is selected
- Hotkey remapping table for every menu item
- Toggle: "Open editor automatically after capture" vs. "Show quick popup only"
- Toggle: "Hide desktop icons" persistence setting
- Launch-at-login toggle

---

## 6. Product Decisions Log

Original open questions from the initial screenshot analysis, now resolved by the product owner:

| Question | Decision |
|---|---|
| Scrolling Capture direction? | Both vertical **and** horizontal scroll stitching supported. |
| OCR launch languages? | **English only** at launch; architecture must allow adding language packs later. |
| Record Screen output formats & limits? | Support **PNG, MP4, and GIF**. Default selection is **MP4** for recordings (PNG for still capture). **No size or length limits.** |
| Capture history scope? | **Last closed file only** — no searchable history/library at launch. |
| Cloud/share destinations? | **Google Drive, OneDrive, iCloud, WhatsApp, Telegram**, extensible to more later (see §4.9). |
| "Star badge" tool identity? | Corrected: it's a **text highlighter** (text-aware, snaps to detected text), not an AI/magic tool. |
| Messaging destination fallback? | **Yes** — share flow first tries the installed/logged-in desktop app (WhatsApp/Telegram); if the app is **not installed**, it **falls back to a web-share flow** (e.g., `web.whatsapp.com` / `web.telegram.org`) instead of failing silently. |
| Web-share handoff mechanism? | **OS-native only, no temp hosting, image-only.** The image is handed to the browser via the **system clipboard** and/or **OS drag-and-drop**, never uploaded to a temporary server first, and **with no accompanying caption text**. |
| Default destination scope? | **Configurable, not a single fixed global default.** The default storage target is chosen from **Local Storage** or a linked cloud provider — **Google Drive, OneDrive, or iCloud** (no separate first-party app-storage destination). Per-capture-type overrides are a future-release candidate. |
| GIF export quality? | **Configurable, dual-mode.** Default: **auto**, derived from the source MP4. Manual mode exposes frame rate (**hard ceiling of 30fps**), color/quality preset, dithering, and resolution scale, with sensible UX defaults (15fps / Medium-128 colors / dithering on / 100% scale) and a **live file-size estimate** — see §3.1a. |
| Local Storage save behavior? | **Silent, no dialog.** Saves to the **last folder the user picked**, defaulting to the standard Screenshots folder on first use. The picker only reappears via an explicit "Save As..." or a Preferences change — never on every capture. |

All product questions raised during requirements gathering are now resolved; there are no outstanding open items. This document reflects the final agreed specification.
