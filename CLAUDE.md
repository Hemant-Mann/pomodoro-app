# CLAUDE.md

Guidance for agents working in this repo. `README.md` is the user-facing manual, and it is
also the spec: the escalation ladder, the hourly long break and the away rules are all
written down there. Read this file first, then the README for anything about what the app
is supposed to *do*.

## What this is

A macOS menu bar break reminder. Native Swift + AppKit + SwiftUI, no dependencies, no
package manager, ~500 KB app bundle.

## Build and run

```bash
./build.sh        # compile Sources/*.swift into build/Pomodoro.app, ad-hoc sign it
./run.sh          # build.sh, then pkill the running copy and relaunch
```

There is no test suite and no `swift test`. See **Testing time-based logic** below — it is
the part of this repo most likely to trip you up.

The app is a menu bar accessory (`LSUIElement`), so a successful launch shows **no window
and no Dock icon** — look for 🍅 in the menu bar. Do not treat a silent launch as a failure.

### Hard constraints

These are load-bearing. Do not "modernise" past them without being asked:

- **Only the Xcode Command Line Tools are installed, not Xcode.** No `.xcodeproj`, no
  `xcodebuild`, no `Package.swift`. `swiftc Sources/*.swift` is the entire build, and the
  CLT SDK does ship SwiftUI/AppKit/UserNotifications, so nothing more is needed.
- **No third-party dependencies.** Anything that would need Homebrew or SwiftPM gets
  written by hand instead — that is why `Quotes.swift` contains a 40-line cowsay.
- `build.sh` targets `arm64-apple-macosx14.0`: Apple Silicon, macOS 14+. Add an x86_64
  slice only if asked.
- `Entry.swift` uses `@main enum` + `-parse-as-library`. Top-level code in a `main.swift`
  does not survive Swift 6 actor isolation; do not convert it back.
- Ad-hoc signing (`codesign -s -`) is what makes local notifications and the login item
  work. Keep the `codesign` line in `build.sh`.

## Architecture

```
Entry.swift            @main, sets .accessory activation policy
  └─ AppDelegate       status item · popover · notifications · preferences window
       ├─ TimerEngine  the state machine (singleton, @MainActor) ← all timing lives here
       ├─ Stats        focus seconds + break counts, today and all time
       ├─ Settings     durations, persisted in UserDefaults
       └─ OverlayController → BreakOverlay   full-screen break window, one per display
```

`DashboardView` (the popover) and `PreferencesView` observe the singletons directly.
`AppDelegate` subscribes to `engine.objectWillChange` to keep the menu bar clock in step,
and owns the two engine callbacks, `onBreakStarted` / `onBreakEnded`, which drive the
overlay.

### TimerEngine invariants

- **It is the only place timing state mutates.** `phase`, `remaining`, `isPaused` and
  `skipStreak` are `@Published private(set)`; add a method rather than widening access.
- **`remaining` is derived from `deadline`, not decremented.** `step()` recomputes it from
  wall-clock time every 0.5 s, so the countdown stays honest across drift and suspension.
- **`focusBanked` and `Stats` accumulate by `tick` instead.** They count ticks that actually
  ran, so time the app spent asleep never inflates focused time or long-break progress.
  Keep that distinction — it is the difference between the clock and the ledger.
- **`phase == .idle` means stopped**, and nearly every public method early-returns on it.
- Escalation lives in the two computed durations (`currentFocusDuration`,
  `currentBreakDuration`), not in the transitions. Change the rules there.

### Away handling

`observeSleep()` and `observeLock()` both funnel into `leave()` / `returnFromAway()`.
Sleep arrives on `NSWorkspace.shared.notificationCenter`; lock arrives as
`com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` on `DistributedNotificationCenter`.

Closing the lid fires **both**, which is why `leave()` ignores the second signal — otherwise
a single nap would be charged twice against `focusBanked`. If you add a third away signal,
route it through the same pair.

The rule: time away ≥ one break's length counts as having taken the break, so the focus
block restarts clean. Shorter than that, the block is left alone.

## Testing time-based logic

A 30-minute timer cannot be tested by hand, and the popover cannot be clicked from a script.
Three techniques work; all of them build **scratch files outside the repo**, never committed:

1. **Headless harness.** Compile the real `TimerEngine` + `Settings` + `Stats` against a test
   `@main` and drive it through `breakNow()` / `skipBreak()` / `stopSession()`, asserting on
   `blockDuration` and `remaining`. Runs in milliseconds. Pump the run loop with
   `RunLoop.main.run(until:)` so the ticker and notification observers fire.
2. **Time-scaled build.** Copy `Sources/`, `sed 's/\* 60/\* 1.0/g'` in `TimerEngine.swift` so
   minutes become seconds, and build to a separate bundle id. A full focus → break →
   long-break cycle then takes ~35 s.
3. **Offscreen rendering for UI.** `screencapture` needs Screen Recording permission, so use
   `ImageRenderer` to draw `BreakOverlay` / `DashboardView` straight to PNG. Note it renders
   `NSViewRepresentable` as a yellow-and-red placeholder — swap the blur backdrop for a solid
   colour in the render copy.

For the lock/unlock path specifically: post the distributed notification from a **separate
process**, the way `loginwindow` does. Shrink `Settings.shared.breakMinutes` to 1 to get the
"away long enough" threshold down to 60 s.

## Conventions

- Comments explain **why**, not what. Match the existing dry, plain-spoken register; several
  are load-bearing explanations of a non-obvious rule. Do not add narration.
- SwiftUI for views, AppKit only where SwiftUI cannot reach — window levels, the status item,
  the full-screen overlay.
- Colours are literal `Color(red:green:blue:)` values defined next to where they are used.
  There is no design-token layer and adding one is not wanted.
- Everything user-visible is `@MainActor`.

## Regressions to not re-introduce

Each of these was a real bug. The fix looks arbitrary in isolation, which is exactly why it
keeps getting "cleaned up".

- **Overlay windows are pinned to `NSAppearance(named: .darkAqua)`** in `OverlayController`.
  In Light mode the overlay's `.plusLighter` gradient blows out against the light HUD
  material. The break screen is meant to be dark in both themes — do not make it follow the
  system appearance.
- **The filled button in `DashboardView` carries its own green**, deliberately independent of
  the phase `accent`. When it used the accent, the `Start` button inherited the idle colour
  (`.secondary`), rendered gray, and read as disabled.
- **Never drive a UI rebuild from the 0.5 s tick.** The original `NSMenu` was rebuilt on every
  tick and flickered or dismissed itself while open. The popover observes
  `engine.objectWillChange` instead; keep it that way.

## State and gotchas

- All persistence is `UserDefaults` under bundle id `com.jinwo.pomodoro`. Nuke it with
  `defaults delete com.jinwo.pomodoro` — that clears settings *and* all-time stats, which is
  the only way to reset all-time stats since the UI only resets today.
- **This directory is not a git repository.** There is a `.gitignore` (`build/`, `.DS_Store`)
  but no history, so there is nothing to diff against and no commit to make unless asked.
- Changing the focus duration in Preferences calls `resetCycle()`, restarting the current
  block. That is deliberate.
- The popover open/close path is the one flow never exercised end-to-end; eyeball it after
  touching `AppDelegate`.
- If notification permission is denied, `notify()` falls back to a `Glass` sound. The overlay
  shows either way, so a break is never silently missed.
