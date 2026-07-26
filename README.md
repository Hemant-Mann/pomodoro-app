# Pomodoro

A menu bar break reminder for macOS. Native Swift, no dependencies, ~500 KB.

Needs macOS 14+ on Apple Silicon, and the Xcode Command Line Tools to build — not Xcode.

```bash
./run.sh          # build and launch
```

Then look for the 🍅 in your menu bar. There's no window and no Dock icon; that's expected.
To keep it around:

```bash
cp -R build/Pomodoro.app /Applications/
```

and tick **Start at login** in Preferences. The app is ad-hoc signed, so the first launch
after moving it may draw an unidentified-developer warning — right-click → **Open** clears
it for good.

## How it works

Focus for **30 minutes**, then a full-screen break overlay appears (plus a notification)
with a **3 minute** countdown and a **Skip this break** button.

**Skipping makes the next round harder.** Each consecutive skip halves the next focus block
and doubles the next break:

| Skips in a row | Focus block | Break |
| -------------- | ----------- | ----- |
| 0              | 30 min      | 3 min |
| 1              | 15 min      | 6 min |
| 2              | 7.5 min     | 12 min |
| 3+             | 5 min (floor) | 15 min (cap) |

Sitting a break out to the end resets you to 30/3.

**Every hour of focus time earns a 10 minute break** to stand up and walk around. The hour is
counted from actual focus time, so pausing doesn't cheat it. If a break is due as both a long
break and an escalated one, you get whichever is longer. Skipping a long break doesn't clear
it — you still owe the walk on the next break.

If the Mac sleeps or the screen is locked for longer than a break, that counts as your break:
the focus block starts over when you come back instead of ambushing you. Walking away for 5
minutes with 10 minutes left gets you a fresh 30, not the 10 you left behind. A quick lock
that's shorter than a break leaves the block running where it was.

## Menu bar

The menu bar shows the current phase and time left — 🍅 focus, ☕️ short break, 🚶 long break,
⏸ paused, ⏹ stopped. Click it for the dashboard:

```
Focusing                22:14
▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░
30 min block · long break in 18 min

TODAY
Focused                2h 45m
Breaks taken                5
Breaks skipped              2

ALL TIME
Focused              128h 10m
Breaks taken              412

[ Pause ] [ Break ] [ Stop ]
Preferences…             Quit
```

**Pause** holds the current block where it is. **Break** starts a break early — it counts as
an earned break, not a skip. **Stop** ends the session: the timer goes idle and the cycle
starts clean when you press **Start**. Today's numbers survive a stop, a quit, and a restart.

During a break the middle button becomes **Skip**, matching the overlay's button.

Today's stats roll over at midnight; the all-time totals keep counting. Focused time only
accrues while a focus block is actually running, so pausing or stopping doesn't inflate it.

## Preferences

| Setting | Range | Default |
| ------- | ----- | ------- |
| Focus block | 5–120 min | 30 |
| Short break | 1–30 min | 3 |
| Long break | 3–60 min | 10 |
| Long break every | 20–240 min of focus | 60 |

Also here: **Start at login**, and a **Reset** for today's stats. Changing the focus length
restarts the current cycle.

Everything is stored in `UserDefaults`. To wipe all of it — settings and all-time stats
together, which is the only way to clear all-time:

```bash
defaults delete com.jinwo.pomodoro
```

## Build

Requires only the Xcode Command Line Tools — no Xcode. `build.sh` compiles `Sources/*.swift`
into `build/Pomodoro.app` and ad-hoc signs it, which is what lets local notifications and the
login item work.

`LSUIElement` is set, so there's no Dock icon or app switcher entry.

## Layout

| File | |
| ---- | --- |
| `Sources/TimerEngine.swift` | the state machine: escalation, the hourly rule, sleep/lock handling |
| `Sources/DashboardView.swift` | the menu bar panel |
| `Sources/Stats.swift` | focus time and break counts, today and all time |
| `Sources/AppDelegate.swift` | menu bar item, popover, notifications |
| `Sources/BreakOverlay.swift` | the break screen |
| `Sources/OverlayController.swift` | full-screen windows, one per display |
| `Sources/Quotes.swift` | break messages + a small cowsay |
| `Sources/Settings.swift` | durations, persisted in UserDefaults |
