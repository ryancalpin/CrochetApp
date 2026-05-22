# UX Integration Plan — apply ux-overhaul wins onto session-improvements

> **For agentic workers:** execute task-by-task; each task ends with `** BUILD SUCCEEDED **`. Source of truth for ported code is the `ux-overhaul` branch (read with `git show ux-overhaul:<path>`).

**Goal:** Bring the ux-overhaul design system + reliability fixes onto the feature-rich `feature/session-improvements` base (branch `ux-integration`) without losing any of its features (search, tags, yarn stash, repeat counter, audio cue, AI persistence, hover annotations).

**Base:** branch `ux-integration` (= `feature/session-improvements`), builds clean. Sources at `CrochetApp/CrochetApp/CrochetApp/`.

**Build command:**
```
cd "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp" && xcodebuild build -scheme CrochetApp -configuration Debug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```

**Color decision (Option 3):** keep session's custom row/stitch/repeat color pickers + presets. Add light/dark for surfaces/text/chrome via Asset Catalog colorsets + `Theme.swift`. Add a hue-preserving accent adapter `Color.legible(_:in:)` that nudges a picked accent's lightness/saturation for the current `colorScheme` so any picked color stays readable in both modes. Pills/accents route through the adapter.

**Preserve (do NOT regress):** repeat counter (`CounterStore.repeatCount`, `entry.showRepeatCounter`, `repeatPill`, `repeatColorHex`), audio cue, hover-button annotations (already implemented), concurrent-or-sequential AI loading, search/tags/yarn stash in `PatternLibraryView`, AI persistence.

---

## IP1 — Design tokens + light/dark + accent adapter
**Files:** new `Assets.xcassets` colorsets (`surface`, `surfaceRaised`, `surfaceSidebar`, `textPrimary`, `textSecondary`, `divider`) with Any+Dark; new `DesignSystem/Theme.swift`; new `DesignSystem/Typography.swift`; convert raw `Color(NSColor.windowBackgroundColor/controlBackgroundColor/separatorColor)` → tokens across `CounterBarView`, `PatternLibraryView`, `PatternContentView`, `AIPanelView`, `PatternStatsBannerView` (until removed in IP3), `SettingsView`, `MarkdownView` placeholders. Add pbxproj entries.
- Reuse colorset values + Theme surface/text tokens from `git show ux-overhaul:CrochetApp/CrochetApp/DesignSystem/Theme.swift` (the surface/text part only — NOT the per-scheme accent extension, since this base uses hex pickers).
- Add accent adapter to Theme.swift:
```swift
extension Color {
    /// Keep hue; nudge lightness/saturation so a user-picked accent stays legible on the
    /// current background. Light mode: ensure not-too-pale. Dark mode: ensure not-too-dark.
    func legible(in scheme: ColorScheme) -> Color {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if scheme == .dark { b = max(b, 0.62); s = min(s, 0.85) }
        else { b = min(b, 0.78) }
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b))
    }
}
```
- Set `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = NO` in both configs (collides with explicit statics) — see ux-overhaul commit.
- Disable disk symbol collision; add a comment in Theme.swift explaining why.
- Add `@Environment(\.colorScheme) private var colorScheme` to views that render accents, and route accent usage through `.legible(in: colorScheme)`.
Verify: build green.

## IP2 — Components + CounterBar refactor + Clear-goal fix
**Files:** new `DesignSystem/CounterPill.swift`, `GlassHUD.swift`, `SectionCard.swift` (copy from `git show ux-overhaul:...`); modify `CounterBarView.swift`.
- Refactor `rowPill`/`stitchPill`/`repeatPill` to use `CounterPill` (3 instances). Repeat pill keeps its add/remove context menu and `entry?.showRepeatCounter` gating.
- Route pill colors: `settings.rowColor.legible(in: colorScheme)` etc.
- Check `GoalInputPopover` on this base for the Clear-goal bug (Clear calling onDismiss); if present, fix via `onClear` (as ux-overhaul did).
- Tokenize bar background → `Color.surface`, timer chip → `Color.surfaceRaised`, `.secondary` → `.textSecondary`.
- Preserve `audioCueButton`, overflow menu, both reset dialogs.
Verify: build green.

## IP3 — Remove perpetual-spinner banner
**Files:** delete `PatternStatsBannerView.swift` (+pbxproj); modify `ContentView.swift`, `AIPanelView.swift`.
- Remove the banner block + `bannerDifficulty`/`bannerTotalRows` state from ContentView and the bindings into AIPanelView; remove the `@Binding`s + assignments from AIPanelView (difficulty/total stay in the panel's own sections).
Verify: build green.

## IP4 — AI on-demand gating + service ownership
**Files:** `ContentView.swift`, `AIPanelView.swift`.
- Mount `AIPanelView` only when `showAIPanel` (remove zero-width always-mounted hack). Own `PatternAIService` externally (a `@MainActor` shared box, as ux-overhaul did) so cache survives close/reopen. Note: session's AIPanelView takes a `library` param — preserve it.
- Optional: make section loads sequential (avoid concurrent on-device sessions). Adopt `SectionCard` in place of `AIFeatureSection` for visual consistency (then delete `AIFeatureSection.swift` if unused).
Verify: build green.

## IP5 — Focus mode (with repeat counter)
**Files:** `ContentView.swift`, `CrochetAppApp.swift`.
- Port focus mode from `git show ux-overhaul:...ContentView.swift` / `CrochetAppApp.swift`: `@State focusMode`, ⌃⌘F command + `.toggleFocusMode` notification, hide sidebar + counter bar, float `GlassHUD` with ROW/STITCH **and REPEAT (when `entry.showRepeatCounter`)** pills. Sidebar slide `.transition`.
Verify: build green.

## IP6 — Remaining reliability fixes
**Files:** `SessionTimer.swift`, `AppSettings.swift`, `SettingsView.swift`, `MarkdownView.swift`, `PatternLibraryView.swift`, `PatternContentView.swift`.
- Timer `userPaused` guard (port from ux-overhaul).
- AppSettings: add `UserDefaults.didChangeNotification` → `objectWillChange.send()` observer in init + deinit cleanup.
- Remove phantom ⌘O rows/text in SettingsView + MarkdownView placeholder; add ⌃⌘F row.
- Drag-drop extension validation in PatternLibraryView `.onDrop`.
- PDFKitView: hold security scope for view lifetime; load doc only on URL change; `NSColor(named: "surface")` instead of dead `viewBackground`.
Each as its own commit. Verify build green after each.

## IP7 — (Optional) re-add convert/yarn-sub AI features
Only if user confirms. Re-add `convertTerminology` + `suggestYarnSubstitutions` to `PatternAIService` (copy from `git show main:...PatternAIService.swift` original, adapt to current service shape) + two `SectionCard`s. Default: SKIP unless greenlit.

## IP8 — Final verification
Clean build; visual matrix (light + dark, Focus mode, AI panel, repeat counter, yarn stash intact, hover note). Then finishing-a-development-branch.
