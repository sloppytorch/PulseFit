# PulseFit — Interval Timer + Workout Log

A complete iOS workout app: a full-featured **interval timer** for running and
cardio, plus a **workout journal** with dates, types, notes and stats. 100%
on-device, no accounts, no network.

Built as a ready-to-open Xcode project (iOS 16+, SwiftUI, Xcode 14+).

---

## Features

### ⏱ Interval Timer
- **Template-based**: classic builder (Get Ready → N sets × M rounds of
  Work/Rest with set rest and cool down) **or** fully custom segment lists
  (add, name, reorder, color-code).
- Ships with built-ins: **Tabata, HIIT 30/15, Run Intervals, EMOM 10**.
- Big color-coded progress ring, phase countdown, "next up" preview,
  set/round indicator, phase dots.
- **Synthesized audio cues** (no audio assets — beeps generated at runtime),
  distinct tones per phase, 3-2-1 countdown ticks, finish fanfare.
- **Spoken prompts** ("Work", "Rest", "Cool Down", custom names).
- **Haptics** — heavy on work, light elsewhere.
- **Keeps running in the background / locked screen** (silent keep-alive
  audio) and posts **lock-screen notifications** at each phase change.
- Skip forward/back, pause/resume; wall-clock based so it stays accurate
  even if iOS suspends the app.
- When a session ends (or you stop it early) you're offered to **log it as a
  workout in one tap**, pre-filled with the template name and summary.

### 📝 Workout Log
- Log **date & time, type, duration, distance, calories, RPE effort 1–10 and
  notes**.
- **Type autocomplete exactly how you wanted it**: type anything new; the next
  time you tap the type box your **past categories** appear (most recent
  first) and filter as you type.
- Pace (min/km or min/mi) auto-calculated when you log a distance.
- Search, filter by period and type; grouped by day (Today / Yesterday / …);
  swipe to delete; full detail view with edit.
- Auto icon per workout type (run, bike, swim, strength, yoga, …).

### 📊 Stats
- Weekly goal ring (goal configurable in Settings).
- Summary cards: total workouts, total time, current streak, this week.
- **Last 8 weeks bar chart** (tap bars for details).
- **16-week activity heatmap** (tap squares for that day).
- Breakdown by workout type with proportional bars.
- Records & streaks: longest session, farthest distance, biggest week,
  longest streak.

### ⚙️ Settings & Data
- Metric / imperial units, weekly goal.
- Toggles: sounds, voice prompts, haptics, background timer, lock-screen
  phase alerts.
- **Export/Import** all data as JSON, **sample data loader**, delete-all.
- Everything is stored as JSON in the app's Documents folder — private and
  portable.

---

## Building

### On a Mac with Xcode
1. Open `PulseFit.xcodeproj`.
2. Pick the **PulseFit** scheme and an iPhone simulator → **Run**.
3. For a device build: select your signing team under
   *Signing & Capabilities* (or just sideload, below).

### Producing an .ipa for sideloading (Sideloadly / AltStore / SideStore)
```bash
./scripts/build_ipa.sh            # → PulseFit-unsigned.ipa
```
The script archives the app **unsigned**; your sideloader signs it with your
Apple ID during install. No special entitlements are required by the app
(background audio + local notifications only).

### Building the .ipa with GitHub Actions (no Mac needed)
This repo ships with `.github/workflows/build-ipa.yml`. On every push to
`main` (or via **Actions → Run workflow**), GitHub's macOS runner runs the
unit tests and archives an unsigned `PulseFit-unsigned.ipa`:

1. Push this repo to GitHub.
2. Open the **Actions** tab → wait for "Build iOS IPA" to go green.
3. Open the run → download the **PulseFit-unsigned-ipa** artifact → unzip it.
4. Sideload the ipa with your signer.

> Minutes note: private repos include ~2000 Actions min/month, but macOS
> runners bill at 10×, so each build costs ~100–150 "minutes" — fine for
> occasional builds. Making the repo **public** gives unlimited free macOS
> builds (Settings → Danger Zone → Change visibility).

### Unit tests
`PulseFitTests` covers the interval engine (phase expansion, boundary math,
transitions), stats (streaks, weeks, breakdowns), the autocomplete filter and
JSON decoding resilience. Run with `⌘U` in Xcode.

---

## Project layout
```
PulseFit/
  PulseFit.xcodeproj
  PulseFit/
    PulseApp.swift            app entry, tab root, notification delegate
    Models/                   Workout, timer models, pure engine, stats math
    Store/                    JSON-persisted workout & template stores
    Audio/                    synthesized beeps, speech, keep-alive
    Support/                  theme, formatters, haptics
    Timer/                    home, template editor, runner
    Log/                      list, form (autocomplete), detail
    Stats/                    dashboard, charts, heatmap
    Settings/                 preferences, export/import
    Assets.xcassets           generated app icon + accent color
    Info.plist
  PulseFitTests/              unit tests
  scripts/
    generate_icon.py          regenerates the app icon (numpy)
    build_ipa.sh              unsigned .ipa for sideloaders
    validate_project.py       structural checks (pbxproj/plist/assets/Swift)
```

## Notes
- Deployment target: **iOS 16.0** (works on iPhone & iPad, portrait-first).
- The runner force-dark UI; the rest follows the system appearance.
- Debugged from Linux: every Swift file passes structural validation
  (delimiter/string/comment balance), the Xcode project, Info.plist, asset
  JSONs and PNG icon are machine-validated, and pure logic is covered by the
  XCTest suite. Final compile happens in Xcode by design (Apple toolchain).
