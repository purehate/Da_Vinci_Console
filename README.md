# 󰔎 Da Vinci Console

A tmux session + window picker built on [sesh](https://github.com/joshmedeski/sesh) and [fzf](https://github.com/junegunn/fzf) — with live pane previews, window-tree navigation, and one-key project jumping via zoxide.

---

## Features

- **Session tree view** — sessions with their windows nested underneath, icons matched by command/name
- **Live pane previews** — see the last 20 lines of any session or window without switching
- **Window flat view** (`Ctrl-W`) — all windows across all sessions in one list
- **Jump mode** (`Ctrl-J`) — browse sesh/zoxide directories; selecting one creates a new session automatically via `sesh connect`
- **Kill sessions** (`Ctrl-D`) — delete a session without leaving the picker
- **Fully themeable** — override colors with environment variables, no script editing needed
- **Nerd Font icons** — matched by session/window name and running command

---

## Requirements

| Tool                                            | Version   | Notes                                       |
| ----------------------------------------------- | --------- | ------------------------------------------- |
| [tmux](https://github.com/tmux/tmux)            | any       | Obviously                                   |
| [fzf](https://github.com/junegunn/fzf)          | **0.58+** | Requires bordered input/list/preview labels |
| [sesh](https://github.com/joshmedeski/sesh)     | any       | For jump mode and `sesh connect`            |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | any       | Powers jump mode directory list             |
| A [Nerd Font](https://www.nerdfonts.com/)       | any       | For icons to render correctly               |

> **fzf 0.58+ is required.** The bordered input/list/preview panel labels were introduced in that release. Earlier versions will error.

---

## Install

```bash
git clone https://github.com/smiley/Da_Vinci_Console ~/.config/tmux/da-vinci-console
chmod +x ~/.config/tmux/da-vinci-console/da-vinci-console.sh
```

Or use the install script to copy the script to `~/.config/tmux/`:

```bash
./install.sh
```

---

## Tmux Binding

Add to your `tmux.conf`:

```tmux
bind s run-shell "bash ~/.config/tmux/da-vinci-console.sh"
```

Or see [`extras/tmux.conf`](extras/tmux.conf) for the full snippet.

Invoke with `<prefix> s`.

---

## Keybindings

| Key                 | Action                                                   |
| ------------------- | -------------------------------------------------------- |
| `Enter`             | Switch to selected session or window                     |
| `Ctrl-J`            | Jump mode — browse sesh/zoxide dirs, create new sessions |
| `Ctrl-W`            | Windows view — all windows across all sessions           |
| `Ctrl-S`            | Sessions view — back to default tree view                |
| `Ctrl-D`            | Kill the selected session                                |
| `Ctrl-/`            | Toggle preview pane                                      |
| `Alt-↑` / `Alt-↓`   | Scroll inside preview                                    |
| `Tab` / `Shift-Tab` | Move down / up                                           |
| `Esc` / `Ctrl-C`    | Exit without switching                                   |

---

## Theming

Colors are controlled by environment variables. Set them in your shell profile or tmux config:

| Variable           | Default              | Description                                  |
| ------------------ | -------------------- | -------------------------------------------- |
| `DVC_COLOR_ACTIVE` | `#14E21A`            | Active indicator, highlights, pointer        |
| `DVC_COLOR_BORDER` | `#24b030`            | Border and label color                       |
| `DVC_COLOR_DIM`    | `#333333`            | Dim separator lines                          |
| `DVC_TITLE`        | `󰔎 Da Vinci Console` | Border label text (supports Nerd Font icons) |

### Example — Catppuccin Mocha

```bash
export DVC_COLOR_ACTIVE="#a6e3a1"
export DVC_COLOR_BORDER="#89b4fa"
export DVC_COLOR_DIM="#45475a"
export DVC_TITLE=" Da Vinci Console"
```

### Example — Tokyo Night

```bash
export DVC_COLOR_ACTIVE="#9ece6a"
export DVC_COLOR_BORDER="#7aa2f7"
export DVC_COLOR_DIM="#3b4261"
export DVC_TITLE="󰔎 Da Vinci Console"
```

---

## Adding Icons

Icons are matched in the `icon_for()` function. Edit `da-vinci-console.sh` to add your own:

```bash
icon_for() {
    local n="${1,,}"; n="${n##*/}"
    case "$n" in
        myproject*) echo "󱓞" ;;  # add your own here
        ...
    esac
}
```

---

## How Jump Mode Works

`Ctrl-J` loads the output of `sesh list -c -z`, which combines:

- Sessions configured in your `sesh.toml`
- Your most-visited directories from zoxide

Selecting an entry calls `sesh connect <path>`. If a tmux session already exists for that directory, it switches to it. Otherwise, sesh creates a new session there and switches to it automatically.

---

## Acknowledgements

- [sesh](https://github.com/joshmedeski/sesh) by Josh Medeski — the session manager powering jump mode
- [fzf](https://github.com/junegunn/fzf) by Junegunn Choi — the fuzzy finder engine
