# omarchy-dsh-agent

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`, the
official DeepSeek coding agent) as a first-class Omarchy agent — web-first,
entirely in user space, nothing under `/usr/share/omarchy/` touched.

```bash
omarchy plugin add https://github.com/ziouf/omarchy-dsh-agent.git --enable
```

## What it does

- **Background service** — runs `dsh web` for the whole desktop, restarting it
  automatically if it exits. The URL the instance reports is captured, so a
  custom port still opens the right address.
- **Web app** — installs a "DeepSeek Harness" launcher (searchable as `dsh`)
  that opens the UI in its own app window and focuses it instead of stacking
  duplicates.
- **Agents panel** — regenerates the `dsh.json` usage record every 15 minutes,
  so Omarchy's Agents bar panel gains a DSH tab: DeepSeek prepaid balance
  (`remaining / funded / spent`) plus best-effort local token stats scanned
  from `$DSH_HOME` (default `~/.dsh`) session logs.

DeepSeek's API is prepaid, so like Fireworks the tab shows a credit balance
instead of rate-limit meters. dsh itself is a developer preview; unrecognized
session formats are skipped rather than guessed at.

## Requirements

- Omarchy (Quattro or newer)
- Node.js >= 24 available through [mise](https://mise.jdx.dev/) (Omarchy ships it)
- A DeepSeek API key for the balance display — without one the tab says
  "Waiting for auth" and shows local stats only. Put `DEEPSEEK_API_KEY=...`
  in your environment or in `~/.dsh/.env`. Get a key at
  <https://platform.deepseek.com>.

## Optional wiring

The service and the app launcher work out of the box. Two snippets make dsh
blend into the rest of Omarchy:

**Default-agent menu entry** — append to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"setup.default.agent.dsh": {
  "icon": "\uf16d",
  "label": "DeepSeek Harness",
  "when": "omarchy-cmd-present dsh",
  "checked": "[[ \"$(omarchy-default-agent)\" == \"dsh\" ]]",
  "action": "$HOME/.config/omarchy/plugins/ziouf.dsh/scripts/set-default"
}
```

**Keybinding** — Omarchy's agent keybinding (`Super+Shift+Ctrl+A`) only knows
the built-in agents. To route it through this plugin (it launches dsh's web
app when dsh is the default and forwards to `omarchy-agent` otherwise), edit
`~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + SHIFT + CTRL + A")
o.bind("SUPER + SHIFT + CTRL + A", "Agent",
  "$HOME/.config/omarchy/plugins/ziouf.dsh/scripts/launch-agent --pick")
```

Then set dsh as your default once via the menu entry (or run
`scripts/set-default` directly), which also installs dsh if needed.

## Files it touches

| Path | Why |
|---|---|
| `~/.local/state/omarchy/dsh/web-url` | The live instance URL |
| `~/.local/state/omarchy/agents/usage/dsh.json` | Usage record read by the Agents panel |
| `~/.cache/omarchy/agent-usage/dsh-balance.json` | Balance probe cache (15 min) |
| `~/.local/share/applications/DeepSeek Harness.desktop` | Web-app launcher |

Removal:

```bash
omarchy plugin remove ziouf.dsh
omarchy-webapp-remove "DeepSeek Harness"
rm -f ~/.config/omarchy/defaults/agent   # or pick another default agent
```

## License

[MIT](LICENSE)
