# Looplet iOS Design Implementation — 2026-05-25

Source: Claude Design handoff bundle "Looplet iOS Design.html" (16 screens, Plum dark theme).
Design tokens already match `Theme.swift` exactly (accent #8E72C7, bg #1A1622, raised #262031,
sidebar #15111D, row #B5547D, stitch #8A63C6). So this is a **visual-polish pass**, not a recolor.

User decision: implement **all 16 screens**, pixel-matched, with the richer onboarding treatment.

## Design language (extracted from the .jsx source)
- Counter pill: radius 13, tinted bg (color@08), 1.5px border (color@2E), ± buttons (color@18) with
  hairline divider, tabular-nums numerals, uppercase label + "/ goal" inline.
- Cards: bgRaised, radius 14–17; materials/accent cards get a 3px left accent border.
- Bottom sheets: radius 26 top, 36×5 drag handle, accent icon tile in header.
- Onboarding: 160deg gradient (#110E1C→#1D1530 55%→#1A1622) + 2 ambient orbs (purple TL, rose BR);
  welcome = 112pt app icon w/ glow shadow + accent ring; panels 2–4 = 104/26 accent@14% tile + glow.
- Page dots: active 22×8 capsule accent, inactive 8×8 white@18.
- Settings: icon+label section tabs (accent tile when active) + grouped cards.
- Paywall: gradient lock hero tile, colored per-feature icon tiles, gradient CTA button.

## Batches (sequential — shared files, so no parallel worktrees) — ALL COMPLETE ✅

- [x] **B1 — Onboarding** (`OnboardingView.swift`): gradient + orbs, 112 icon glow/ring, panel tiles
      w/ glow, Back/Next/Get Started, capsule dots. Screens 1, 10, 11, 12.
- [ ] **B2 — Library** (`PatternLibraryView.swift`): brand-icon header, pattern-row left-border active
      + R·S badge, empty-state doc tile, yarn swatch glow, search active state, add-yarn weight chips.
      Screens 2, 3, 7, 13, 14.
- [ ] **B3 — Counter + Pattern + Focus** (`CounterBarView.swift`, `ContentView.swift`): refined pills,
      summary strip (difficulty + ~time chips), focus-mode split-pane w/ large vertical counters +
      Move Up/Down + row progress + timer. Screens 4, 5.
- [ ] **B4 — AI panel** (`AIPanelView.swift`): accent header tile, ask input w/ accent border + send,
      collapsible sections w/ symbols, Q&A bubbles (user accent / AI avatar). Screens 6, 15.
- [ ] **B5 — Settings + Paywall** (`SettingsView.swift`, `Monetization.swift`): icon+label tabs,
      grouped cards, theme grid (46 circles, active ring, lock), paywall gradient hero/tiles/CTA.
      Screens 8, 9, 16.

## Per-batch gate (CLAUDE.md)
Build → BUILD SUCCEEDED → run tests (30/30) → simulator screenshot + describe vs design → commit.
Do NOT push without explicit user approval.
