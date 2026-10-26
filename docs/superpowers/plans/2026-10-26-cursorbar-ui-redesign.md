# CursorBar UI redesign implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the menu bar item and dropdown as macOS 26+ Liquid Glass, with a local-time usage panel, Thai/English chrome, and menu-bar visibility settings.

**Architecture:** Keep session fetching in `CursorAPI` and state in `UsageStore`. Pure ranking and calendar-day helpers live in `UsageMath`. Chrome strings live in `L10n`. SwiftUI for the status item and panel lives beside `App.swift`.

**Tech Stack:** Swift 6, SwiftUI, macOS 26 Liquid Glass (`glassEffect`, `.buttonStyle(.glass)`).

## Global Constraints

- Minimum system: macOS 26
- Glass only on the panel, Refresh, Done, and the system menu-bar highlight
- Menu bar toggles do not hide dropdown data
- New-install defaults: gauge on, quota on, agents on, daily off, remaining off, overspend off
- Languages: system / th / en, default system; dates and currency stay on system formatters
- Day boundaries use `TimeZone.current`
- Top models: at most 3, at most 20 pages of 100 events, no truncation warning
- Do not change the 5-minute refresh or `--status` output
- No Enterprise API, no dock icon, no timezone picker

---

### Task 1: Data helpers

**Files:**
- Create: `Sources/CursorBar/UsageMath.swift`
- Modify: `Sources/CursorBar/CursorAPI.swift`
- Modify: `Sources/CursorBar/UsageStore.swift`
- Modify: `Sources/CursorBar/App.swift`

**Interfaces:**
- Produces: `UsageMath.topModelSpends(events:limit:)`, `UsageMath.dayString(_:timeZone:)`, `UsageMath.ModelSpend`
- Produces: `CursorAPI.fetchTopModelSpends(cycleStart:)`
- Produces: `UsageStore.topModelSpends`, `UsageStore.statusMessages`, `UsageStore.teamOnDemand`, `UsageStore.loadError`

- [ ] Add model ranking and local-day helpers with `--self-check`
- [ ] Decode `model` on usage events and page through the billing cycle
- [ ] Compare profile token days in the machine timezone
- [ ] Publish top models, status sentences, and team on-demand from refresh

### Task 2: Chrome and panel

**Files:**
- Create: `Sources/CursorBar/L10n.swift`
- Create: `Sources/CursorBar/MenuBarStatus.swift`
- Create: `Sources/CursorBar/PanelView.swift`
- Modify: `Sources/CursorBar/App.swift`
- Modify: `Package.swift`
- Modify: `scripts/package.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: UsageStore fields from Task 1 and `L10n.t(_:_:)`

- [ ] Raise the deployment target to macOS 26
- [ ] Draw the monochrome gauge status item and the six settings switches
- [ ] Replace the dropdown with the hero layout, settings page, and Thai/English chrome

### Task 3: Verify

- [ ] Run `swift build` and `.build/debug/CursorBar --self-check`
