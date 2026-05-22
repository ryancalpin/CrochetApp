# UX & Visual Overhaul — Design Spec

**Date:** 2026-05-21
**Project:** CrochetApp / "Crochet Helper" (macOS, AppKit + SwiftUI)
**Scope:** Visual design system, layout restructure, and reliability fixes to remove the "basic / broken / alpha" feel.

---

## Problem

The app works (build succeeds) but feels unfinished. Three sources:

1. **Looks basic.** ~80 hardcoded `.font(.system(size: N))` calls (sizes 9–13), flat pink accents, ad-hoc `NSColor.windowBackgroundColor` / `Color(red:…)` backgrounds, no cohesive design language, no Dynamic Type.
2. **Cluttered.** The counter bar, a redundant stats banner, and an AI panel all compete for attention above the pattern.
3. **Feels broken.** Perpetual loading spinners in the banner, dead `⌘O` / "File → Open" hints, a "Clear" button that doesn't clear, a timer that resumes itself after you pause it, undiscoverable Alt-click annotations, and a hidden 6-call AI burst on every pattern open.

## Goals

- A real, token-based design system: **warm craft** in light mode, **calm focus** in dark mode, one coherent language across both.
- Cleaner structure: **Calm Reader** default layout + a **Focus mode**; remove redundant chrome.
- Fix the reliability bugs that make it feel alpha.

## Non-goals

- iOS / iPadOS (this stays a macOS desktop app).
- App sandboxing / Mac App Store readiness.
- New AI features. (Existing unwired `convertTerminology` / `suggestYarnSubstitutions` are addressed: surface or delete — see §6.)

---

## 1. Design System

### 1.1 Color tokens (Asset Catalog colorsets, light + dark)

Replace scattered literal colors with named colorsets, each defining a Light and Dark appearance. Surfaces are shared across all schemes; only Row/Stitch accents vary by scheme.

| Token | Light (warm craft) | Dark (calm focus) |
|---|---|---|
| `surface` | `#FBF6EF` (cream) | `#16151A` (warm charcoal) |
| `surfaceRaised` | `#FFFFFF` | `#211F28` |
| `surfaceSidebar` | `#F3E9DC` | `#1F1D24` |
| `textPrimary` | `#3A2F26` | `#E8D5C4` |
| `textSecondary` | `#7A6A58` | `#9A92A6` |
| `divider` | `#ECE0D0` | `#2A2730` |

`AccentColor` asset is set to the Classic Row terracotta (drives system tinting).

### 1.2 Color schemes (all 5 kept)

Each `PillColorScheme` supplies a **Row** and **Stitch** accent, each with a light and dark variant (dark variants are lighter/glowing so they read on charcoal). Defined as colorsets named `scheme/<name>/row` and `scheme/<name>/stitch`, resolved through the existing `AppSettings.PillColorScheme` enum (which keeps the same cases but reads from the catalog instead of hardcoded `Color(red:…)`).

Default scheme stays **Classic** (terracotta `#C26B5A` / berry `#9A6FB0`; dark `#F0A878` / `#C3AEF5`).

### 1.3 Typography

A single `Typo` scale built on semantic SwiftUI text styles so Dynamic Type works:

- Counter numerals → `.system(.largeTitle, design: .rounded).weight(.bold)` with `.monospacedDigit()`.
- Pill labels / chips → `.caption2`.
- Pattern name / section titles → `.headline`.
- Body / list rows → `.body` / `.callout`.
- Secondary metadata → `.caption`.

No raw point sizes in view code (except deliberate icon glyph sizing via SF Symbol `.imageScale`).

### 1.4 Reusable components

Extract styling into shared views so it lives in one place:

- `CounterPill` (Row/Stitch variant, color from scheme, `−`/value/`+`).
- `StatChip` (label + value).
- `SectionCard` (used by AI inspector sections).
- `GlassHUD` (floating counter cluster for Focus mode, `.regularMaterial` + shadow).

---

## 2. Layout

### 2.1 Default — "Calm Reader"

```
┌──────────┬─────────────────────────────────────────────┐
│ Sidebar  │  Counter bar: [Row] [Stitch]  ▕progress▏  ⏱  ✦AI │
│ Patterns ├─────────────────────────────────────────────┤
│  · ...   │                                             │
│  · ...   │           Pattern content (full width)       │
│          │                                             │
└──────────┴─────────────────────────────────────────────┘
```

- Sidebar unchanged structurally (Pinned / Recent, ＋, drag-drop).
- Counter bar: Row pill, Stitch pill, inline row-progress bar (only when a goal is set), session timer (if enabled), `✦ AI` toggle. Compact overflow menu (`⋯`) below the existing `compactBreakpoint` is retained.
- **The `PatternStatsBannerView` is removed entirely.** Difficulty and total-rows move into the AI inspector.

### 2.2 Focus mode

Toggled by toolbar button, View menu item, and `⌃⌘F`.

- Sidebar collapses (animated).
- Pattern content fills the window.
- Counters render as a `GlassHUD` floating top-center over the content (translucent material, never auto-hides).
- Exiting restores the Calm Reader layout.
- State is per-session (not persisted) — simplest, matches the timer's existing "resets on relaunch" convention.

### 2.3 AI inspector (on demand only)

- Opens only when the user toggles `✦ AI`. **Remove the always-mounted `AIPanelView` from the hierarchy** when the panel is closed.
- To preserve the in-memory result cache across open/close, `PatternAIService` is **owned one level up** (in `ContentView` as a `@StateObject`, or an `@Observable` injected via environment) and passed into `AIPanelView`, rather than being the panel's own `@StateObject`. This keeps caching behavior while letting the panel view come and go.
- Sections (Summary, Abbreviations, Materials, Difficulty, Stitch Verifier, Time Estimate, Q&A) load **lazily and sequentially** when the panel is open — not 6 concurrent calls on pattern open.
- Each section keeps its Regenerate button.

---

## 3. Reliability fixes (in scope)

| # | Bug | Fix |
|---|---|---|
| 1 | Perpetual banner spinners on macOS <26 / no AI | Banner removed; difficulty/total live in the inspector and show real loading/empty/error states. |
| 2 | "Clear" goal button only dismisses | Wire the Clear button to actually clear the goal (`onConfirm(nil)` path / dedicated `onClear`). |
| 3 | Timer resumes itself after manual pause on app focus change | Track `userPaused` separately from focus-pause; `didBecomeActive` only resumes if the user didn't manually pause. |
| 4 | Phantom `⌘O` / "File → Open Pattern" hints | Remove the text from `SettingsView` Shortcuts tab and `EmptyMarkdownPlaceholder`. Point users at ＋ / drag-drop. |
| 5 | AI fires 6 calls on every pattern open | Gated behind the panel being open (see §2.3). |
| 6 | `@AppStorage` inside `AppSettings: ObservableObject` may not publish | Convert `AppSettings` to fire `objectWillChange` on writes (manual `objectWillChange.send()` in setters, or migrate to `@Observable` reading `UserDefaults`), so appearance changes update the counter bar live. Verify at runtime. |
| 7 | Annotations undiscoverable (Alt-click) | Replace with a hover `＋ note` affordance at the row edge (see §4). |
| 8 | Drag-drop accepts any file type | Validate dropped URLs against the same allowed types as the file importer; ignore others. |
| 9 | PDF security scope released before lazy page loads; doc rebuilt every update | Hold access for the view's lifetime (start in `makeNSView`, stop in dismantle) and only set `document` when the URL actually changes. |
| 10 | Dead `NSColor(named: "viewBackground")` reference | Use a real `surface` colorset. |

## 4. Annotations — hover affordance

- On hover over any `<p>`/`<li>` block in the rendered pattern, a small `＋ note` control fades in at the block's trailing edge (injected by the existing annotation JS).
- Clicking it opens the inline editor (same amber-ruled input that exists today).
- Existing notes still render below their block and remain click-to-edit.
- Keyboard: Return saves, Escape cancels (unchanged).
- The Alt-click handler is removed. Paragraph-index keying (`[Int:String]` over `p,li` order) is unchanged, so existing saved notes still resolve.

## 5. Settings changes

- Appearance tab: keep the 5-scheme swatch picker (restyled), Counter Display Size, Show Timer. Add a **Focus mode** hint/shortcut reference.
- Shortcuts tab: remove the `⌘O` row; add the `⌃⌘F` Focus mode row.
- Counting / Pace tabs: unchanged.

## 6. Dead code decision

`convertTerminology` and `suggestYarnSubstitutions` (plus their unused `isLoadingConversion` / `isLoadingYarnSub` flags) are implemented in `PatternAIService` but wired to no UI. **Decision: surface them** as two additional AI inspector sections ("US ↔ UK Convert", "Yarn Substitutes"), since the work is already done and they fit the panel. If implementation reveals they're low-value, delete instead — do not leave them dangling.

---

## Architecture / files touched

- **New:** `DesignSystem/` — `Colors.swift` (token accessors), `Typography.swift`, `Components/CounterPill.swift`, `Components/StatChip.swift`, `Components/SectionCard.swift`, `Components/GlassHUD.swift`. Asset Catalog colorsets.
- **Removed:** `PatternStatsBannerView.swift`.
- **Heavily edited:** `ContentView.swift` (layout, Focus mode, AI ownership/gating), `CounterBarView.swift` (components, Clear fix), `SettingsView.swift` (shortcut rows, restyle), `AppSettings.swift` (observation fix, scheme→catalog), `SessionTimer.swift` (manual-pause tracking), `MarkdownView.swift` (hover affordance, placeholder text, PDF access), `AIPanelView.swift` (lazy/sequential load, new sections), `PatternLibraryView.swift` (drag-drop validation), `PatternContentView.swift` (PDF lifecycle, color token).

## Testing & verification

- Build must succeed (`** BUILD SUCCEEDED **`) after each task.
- Visual verification per CLAUDE.md, adapted for macOS: launch the built app, load a sample pattern, and capture screenshots in **both light and dark mode** and in **Focus mode**; confirm against this spec before declaring UI work done. (iOS simulator rules in CLAUDE.md don't apply — this is a Mac app.)
- Specific checks: banner gone, no perpetual spinners with AI unavailable; Clear goal clears; pause survives app switch; ＋ note appears on hover; appearance settings update the bar live; AI does not run until the panel opens.

## Rollout

Single feature branch; phased implementation (design system → layout → Focus mode → AI restructure → bug fixes → dead-code decision), build green at each phase. Implementation plan to follow via writing-plans.
