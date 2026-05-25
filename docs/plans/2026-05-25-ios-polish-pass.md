# iOS Polish Pass — 2026-05-25

Feedback from device testing (iPhone 17 Pro Max, iOS 26.5):

1. Onboarding is missing the app icon and needs polish.
2. No way to reach Settings on iPhone (gear only lives in the pattern detail toolbar; a
   fresh install with no patterns can never open Settings).
3. Yarn "Add to Stash" sheet has tons of blank space (full-screen sheet, top-aligned form).
4. Need a mock/sample pattern to test with in the simulator.
5. The app needs a lot of polish generally.

## Tasks

- [x] **T1 — Sample pattern**: `SampleContent.swift` (Classic Granny Square) +
      `PatternLibrary.addSamplePattern()` writes to Application Support and imports. "Try a
      Sample Pattern" + "Import a File" actions added to the patterns empty state. Verified:
      loads and renders the pattern, persists in the library.
- [x] **T2 — Settings access on iPhone**: `onOpenSettings` closure added to
      `PatternLibraryView`; gear in the Library header (iOS only). `ContentView` wires
      `{ showSettings = true }`. Verified: gear opens Settings from an empty library.
- [x] **T3 — Onboarding polish**: `BrandIcon` imageset added; welcome panel shows the
      rounded/shadowed app icon, other panels use tinted SF-Symbol tiles. Larger title,
      better spacing, animated capsule page dots. Verified on panels 1 + 2.
- [x] **T4 — Sheet sizing/polish**: Yarn sheet reworked to a grouped `Form` in a
      `NavigationStack` with `.presentationDetents([.medium, .large])` + drag indicator;
      Tag + Rename sheets get medium detents. Verified: yarn sheet is half-height, no blank
      space.
- [x] **T5 — Verify**: BUILD SUCCEEDED (0 warnings), 30/30 tests pass, every changed screen
      screenshotted on iPhone 17 Pro and confirmed.

## Also fixed (minor copy polish)

- Yarn empty state "Click + to add a skein" → "Tap ＋ …" on iOS.
- Settings goal footer "right-click on a counter" → "touch and hold a counter" on iOS
  (counter pills use `.contextMenu`, which is a long-press on touch).

## Notes / constraints

- Pattern files are stored as security-scoped bookmarks; a file written into our own
  sandbox (Application Support) resolves with a plain bookmark — safe to seed.
- `rc-` skill naming convention; Info.plist edits go in the existing plist.
- Build + visual verify before declaring done (CLAUDE.md).
