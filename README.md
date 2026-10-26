# CursorBar

A lightweight macOS menu bar app that shows your Cursor plan usage and how much you have left this billing cycle.

No browser tab, no manual cookie paste — CursorBar reads your session from the local Cursor IDE database and fetches usage from Cursor's dashboard API.

![CursorBar dropdown showing agent status, needs-input alerts, usage breakdown by category, daily utilization, and billing cycle](docs/screenshot.png)

## Features

- **Menu bar icon** — a system gauge symbol plus the figures you turn on in Settings. A yellow badge means an agent needs input. The quota percent turns red when you are over. With every switch off, only the gauge remains
- **Configurable menu bar** — Settings chooses gauge, quota percent, agent badge, today percent, remaining money, and overspend. The dropdown still shows the full panel
- **Languages** — System, Thai, or English. Dates and currency follow the Mac
- **Daily utilization** — today's spend, from local midnight, measured against a daily budget (total quota / working days in the billing cycle)
- **Usage breakdown** — dollar amounts used, total credits (including bonus), and remaining balance
- **Overspend tracking** — shows charges beyond included credits and on-demand spend with budget/remaining
- **Billing cycle info** — current period dates and days until reset
- **Auto-refresh** — on launch and every 5 minutes
- **Manual refresh** — click Refresh in the dropdown anytime
- **Built-in updates** — checks GitHub for new versions on startup, with a manual check button and one-click update from the dropdown

## Requirements

- macOS 26 or later
- [Cursor IDE](https://cursor.com) installed and signed in on this Mac
- Swift 6 — only needed if [building from source](#build-from-source)

## Install

### Homebrew (recommended)

```bash
brew tap c-johannesen/cursorbar
brew install cursorbar
```

Or without adding the tap permanently:

```bash
brew install c-johannesen/cursorbar/cursorbar
```

This installs `CursorBar.app` to `/Applications`. Open it from Applications or run:

```bash
open -a CursorBar
```

### Build from source

```bash
git clone https://github.com/c-johannesen/cursorbar.git
cd cursorbar
bash scripts/install.sh
```

This builds CursorBar locally, installs it to `/Applications/CursorBar.app`, and opens it.

### Launch later

```bash
open -a CursorBar
```

Or, if you built from source:

```bash
bash scripts/launch.sh
```

## Usage

| Menu bar | Click to open dropdown |
|----------|------------------------|
| Gauge and the figures you enabled | Click to open the panel |

**Menu bar**

- Yellow badge — that many agents need your input
- Red quota percent — included usage is at or over the limit, or there is overspend
- Dim gauge — nothing is running and quota is 0%

Agent status is read from local Cursor IDE data (transcripts and `state.vscdb`). Cloud agent status and plan/input flags can lag the UI by a minute or two because the IDE debounces writes to disk. Click an agent under **Needs input** to focus it in the Cursor app.

**Color in the panel**

- Red value — that meter is at 100% or the daily budget is over 100%

**Auto-refresh:** immediately on launch, then every **5 minutes** while the app is running.

**Errors:** if something goes wrong, the menu bar shows `!` — open the dropdown for details.

## Troubleshooting

Check that CursorBar can read your account:

```bash
/Applications/CursorBar.app/Contents/MacOS/CursorBar --status
```

Expected output: `OK 42%` (your percentage will differ).

Common issues:

| Problem | Fix |
|---------|-----|
| `!` in menu bar | Make sure Cursor is installed and you're signed in, then click **Refresh** |
| App won't open from Finder | Run `bash scripts/launch.sh` — it clears Gatekeeper quarantine flags |
| `Swift is not installed` | Run `xcode-select --install` |
| `No auth token found` | Sign out and back into Cursor, then relaunch CursorBar |

## How it works

1. Reads `cursorAuth/accessToken` from Cursor's local SQLite database  
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
2. Derives a session cookie from the JWT
3. Calls `GET https://cursor.com/api/usage-summary`

The token is read fresh on every refresh and is **never stored** by CursorBar.

## Development

```bash
git clone https://github.com/c-johannesen/cursorbar.git
cd cursorbar

# Build only
bash scripts/package.sh

# Build, install to /Applications, and launch
bash scripts/package.sh --install --open

# Verify API access
.build/release/CursorBar --status
```

Project layout:

```
Sources/CursorBar/
  App.swift           # MenuBarExtra UI
  AgentMonitor.swift  # Live agent count & needs-input detection
  TokenProvider.swift # Read auth from Cursor IDE DB
  CursorAPI.swift     # Fetch usage-summary
  UsageStore.swift    # Refresh timer & display state
  UpdateChecker.swift # GitHub release updates
scripts/
  install.sh          # One-step install
  launch.sh           # Start the app
  package.sh          # Build .app bundle
```

## Limitations

- Uses Cursor's **undocumented** dashboard API — may break without notice
- Agent status is inferred from local IDE files — may lag the UI or miss edge cases
- Individual Cursor accounts only (reads your local IDE session)
- Not signed with an Apple Developer ID — first launch may require right-click → Open, or use `scripts/launch.sh`

## Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

The `main` branch is protected: only the repository owner can push to or merge into `main`. Everyone else should fork the repo and open a PR.

## License

MIT — see [LICENSE](LICENSE).
