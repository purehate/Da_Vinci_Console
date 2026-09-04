# Da Vinci Console

A focused tmux session picker built with `fzf` — plus a **herdr-style agent
dashboard** that shows which coding agents are running and where, all inside
tmux.

It only cares about tmux: sessions, windows, panes, agents, and a good-looking
live preview.

![Da Vinci Console screenshot](assets/screenshot.png)

## Features

- Tmux sessions with nested windows
- **Agent-aware**: each coding agent is nested directly under its own
  window with a status light (◐ focused / ● working / ○ idle). No separate
  agents panel — they live with their window and are clickable to jump to it
- Live preview of the selected session or window
- Pane drill-down when a window has multiple panes
- Create, rename, and kill directly from the picker
- A shareable `extras/tmux.conf` that puts the same agent status lights in your
  tmux status-line window pills — so agents are visible *everywhere*, not just
  in the picker

## How it works

Agents are detected by walking each window pane's process tree for known agent
command names (`pi claude codex opencode gemini aider cursor-agent grok
continue qwen-code` — override with `TMUX_AGENTS`). "Working" is approximated
by CPU-time growth between refreshes.

The detection logic lives in `agents/`, shared by both the picker and the
tmux status line:

```
agents/
├── lib.sh            # shared watch-list + detection
├── agents_state.sh   # all agents + status lights (feeds the picker)
├── window_agent.sh   # " | pi ●" for one window (feeds the status line)
└── jump.sh           # <prefix>+a fzf picker across all agents
```

## Requirements

| Tool | Notes |
| --- | --- |
| [tmux](https://github.com/tmux/tmux) | Required |
| [fzf](https://github.com/junegunn/fzf) | Required |

## Install

```bash
git clone https://github.com/purehate/Da_Vinci_Console
cd Da_Vinci_Console
./install.sh
```

The installer copies the picker to `~/.config/tmux/sesh_picker.sh`, the
dynamic-size popup wrapper to `~/.config/tmux/picker_popup.sh`, the
prefix-aware status-left renderer to `~/.config/tmux/status_left.sh`, and the
agent module to `~/.config/tmux/agents/`.

## Tmux status line (agents in the window pills)

The repo ships a complete shareable config in
[`extras/tmux.conf`](extras/tmux.conf) that turns your status line into an
agent dashboard:

```
1:acme | pi ◐   2:api | claude ○   3:workers   4:docs | codex ●
```

Each window pill shows `| agent ⦁`; click a pill to jump to that window. No
agent → the pill looks normal.

The same `extras/tmux.conf` also draws a live pane border with the current
path, the running agent's light, and the git branch — so the agent follows you
around the window, not just in the status line or picker.

Its status-right is a full powerline dashboard: git branch, pane count, a live
agent count, CPU, memory, load, and the date. The status-left is prefix-aware
— the session block flips to blue with a keyboard glyph while you're holding
`<prefix>` — and shows the hostname. Window pills are centered.

```bash
cp extras/tmux.conf ~/.config/tmux/tmux.conf   # back up yours first!
tmux source-file ~/.config/tmux/tmux.conf       # or <prefix>+r
```

Or just add the picker binding to your existing config:

```tmux
bind-key s run-shell "~/.config/tmux/picker_popup.sh"
```

The `picker_popup.sh` wrapper sizes the popup to fit the list (dynamic height
+ width) with an opaque background, so it hugs the content and reads cleanly
regardless of terminal transparency.

## Keybindings

| Key | Action |
| --- | --- |
| `Enter` | Switch to selected session/window |
| `Ctrl-N` | Create a new session |
| `Ctrl-R` | Rename selected session/window |
| `Ctrl-D` | Kill selected session/window |
| `Ctrl-G` | Filter to agent windows only |
| `Ctrl-T` | Show all sessions/windows |
| `Ctrl-/` | Toggle preview |
| `Alt-Up` / `Alt-Down` | Scroll preview |
| `Esc` / `Ctrl-C` | Exit |

## Agent status lights

- **◐** — focused (the window/pane you're viewing)
- **◓ ◑ ◒ ◔** — working (CPU time grew since last refresh; the light spins)
- **○** — idle

Each agent also gets its own **brand colour** (pi=green, claude=orange,
codex=red, gemini=blue, aider=pink, opencode=teal, …) so you can scan who's
running where at a glance — in the picker, the preview, and the session
summaries.

## Icons

Icons are intentionally simple ASCII markers so the picker works cleanly
without a Nerd Font. Agent windows map to a letter (`pi`→P, `claude`→C,
`codex`→X, ...). Edit `icon_for()` in `da-vinci-console.sh` to customise.
