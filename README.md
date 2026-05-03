# QMA Watcher

**Quantum Memory AI fuel bar** — cost, tokens, agents, and projects in your terminal and menu bar.

Fork of [exe-watcher](https://github.com/AskExe/exe-fuelbar) by [Exe AI](https://github.com/AskExe) (MIT license), rebranded for the Quantum Memory AI ecosystem.

```bash
npm install -g qma-watcher
```

---

## What you get

**Dashboard** — Interactive TUI with gradient charts, responsive panels, keyboard navigation. Breaks down spend by day, project, model, activity type, tools, MCP servers, and shell commands.

**Optimize** — Scans your sessions and config for waste. Hands back exact, copy-paste fixes. Grades your setup A through F.

**Compare** — Side-by-side model comparison on your own data.

**Menubar** — Native macOS app showing today's cost in your menu bar. (Uses upstream exe-watcher menubar builds.)

**Export** — CSV and JSON export for any time period.

---

## CLI reference

```bash
# Dashboard
qma-watcher                                    # interactive (default: 7 days)
qma-watcher today                              # today only
qma-watcher month                              # this month

# Reports
qma-watcher report -p 30days
qma-watcher report --format json
qma-watcher status                             # compact one-liner

# Tools
qma-watcher optimize                           # find waste, get fixes
qma-watcher compare                            # model comparison
qma-watcher export                             # CSV export
qma-watcher export -f json                     # JSON export

# Config
qma-watcher currency GBP                       # set display currency
qma-watcher plan set claude-max                # track plan usage
qma-watcher menubar                            # install macOS menubar app
```

See the [upstream README](https://github.com/AskExe/exe-fuelbar#readme) for full documentation, supported tools, activity tracking, and configuration details.

---

## Upstream sync

This fork tracks `AskExe/exe-fuelbar` as `upstream`. Branding lives in a single commit on `qma-brand`, merged to `main`.

### Pulling upstream updates

```bash
git fetch upstream
git merge upstream/main
```

Conflicts will only appear in branding files (package.json name, README, etc.). Resolve by keeping our QMA branding.

### What was changed from upstream

- Package name: `exe-watcher` → `qma-watcher`
- CLI binary name: `exe-watcher` → `qma-watcher`
- All display strings: "Exe Watcher" → "QMA Watcher"
- Config/cache dirs: `~/.config/exe-watcher` → `~/.config/qma-watcher`, `~/.cache/exe-watcher` → `~/.cache/qma-watcher`
- Author/repo URLs → KingJackWins/qma-watcher
- **No functionality changes** — all features identical to upstream

### What was NOT changed

- Mac menubar app (still downloads from upstream `AskExe/exe-watcher` releases)
- Swift source in `mac/` (not rebranded — uses upstream builds)
- All test files (unchanged, may reference upstream names)

---

## Origin & attribution

This is a branding fork of [exe-watcher](https://github.com/AskExe/exe-fuelbar) by [Exe AI](https://askexe.com), which itself was forked from [codeburn](https://github.com/getagentseal/codeburn) by [AgentSeal](https://github.com/getagentseal).

Full credit to Exe AI for the dashboard, optimize, compare, and menubar features. Full credit to AgentSeal for the original codeburn foundation.

---

## License

MIT

---

Built by [Quantum Memory AI](https://quantummemory.ai). Upstream: [Exe AI](https://askexe.com). Originally forked from [codeburn](https://github.com/getagentseal/codeburn). Pricing data from [LiteLLM](https://github.com/BerriAI/litellm). Exchange rates from [Frankfurter](https://www.frankfurter.app/).
