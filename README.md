# 󰔎 Da Vinci Console

A tmux session + window picker built on [sesh](https://github.com/joshmedeski/sesh) and [fzf](https://github.com/junegunn/fzf) — three sections in one view: live sessions & windows, auto-discovered git repos, and current directory. Git previews, smart dedup, language icons, and one-key project jumping.

![Da Vinci Console screenshot](assets/screenshot.png)

---

## Features

- **Three-section unified view** — Sessions & Windows, Repos, and Current Dir all visible at once, no mode switching needed
- **Auto-discovered repos** — scans `~/` for git repos automatically; pin specific dirs via `SESH_REPO_DIRS`
- **Git branch inline** — current branch shown next to every repo entry
- **Language icons** — detects Rust, Node, Go, Python, PHP, Java, Ruby, C++ by manifest file
- **Color-coded repos** — work dirs (blue) vs personal dirs (purple), configurable via `SESH_WORK_DIRS`
- **Smart dedup** — repos already open as sessions show `●` in green and switch directly to the existing session
- **Git preview** — branch, dirty status, last 8 commits, and onefetch stats in the preview pane
- **Live pane previews** — see the last 20 lines of any session or window without switching
- **`Ctrl-N` new session** — create a named tmux session at any repo path and jump straight to it
- **`Ctrl-X` kill window** — kill individual windows without leaving the picker
- **`Ctrl-D` kill session** — delete sessions on the fly
- **Jump mode** (`Ctrl-J`) — sesh configured dirs + zoxide frecency, split into labelled sections
- **Windows view** (`Ctrl-W`) — all windows across all sessions grouped by session
- **Shell-aware installer** — detects bash/zsh/fish and shows the right config syntax
- **Nerd Font icons** — matched by session name, window name, and running command

---

## Requirements

| Tool                                            | Version   | Notes                                       |
| ----------------------------------------------- | --------- | ------------------------------------------- |
| [tmux](https://github.com/tmux/tmux)            | any       | Obviously                                   |
| [fzf](https://github.com/junegunn/fzf)          | **0.58+** | Requires bordered input/list/preview labels |
| [sesh](https://github.com/joshmedeski/sesh)     | any       | For jump mode and `sesh connect`            |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | any       | Powers jump mode directory list             |
| A [Nerd Font](https://www.nerdfonts.com/)       | any       | For icons to render correctly               |

**Optional:** [onefetch](https://github.com/o2sh/onefetch) — adds rich repo stats to the git preview pane.

> **fzf 0.58+ is required.** The bordered input/list/preview panel labels were introduced in that release. Earlier versions will error.

---

## Install

```bash
git clone https://github.com/purehate/Da_Vinci_Console
cd Da_Vinci_Console
./install.sh
```

The installer detects your shell (bash/zsh/fish), shows the correct tmux bind snippet, and checks all dependencies.

---

## Tmux Binding

Add to your `tmux.conf`:

```tmux
bind s display-popup -B -x C -y C -w 72% -h 72% -s "bg=default" -E "~/.config/tmux/sesh_picker.sh"
```

Or see [`extras/tmux.conf`](extras/tmux.conf) for the full snippet. Invoke with `<prefix> s`.

---

## Keybindings

| Key                 | Action                                               |
| ------------------- | ---------------------------------------------------- |
| `Enter`             | Switch to selected session, window, or repo          |
| `Ctrl-N`            | Create a new named session at the selected repo path |
| `Ctrl-X`            | Kill the selected window                             |
| `Ctrl-D`            | Kill the selected session                            |
| `Ctrl-A`            | Return to the default all-sections view              |
| `Ctrl-J`            | Jump mode — sesh configured dirs + zoxide frecency   |
| `Ctrl-W`            | Windows view — all windows across all sessions       |
| `Ctrl-/`            | Toggle preview pane                                  |
| `Alt-↑` / `Alt-↓`   | Scroll inside preview                                |
| `Tab` / `Shift-Tab` | Move down / up                                       |
| `Esc` / `Ctrl-C`    | Exit without switching                               |

---

## Configuration

### Repo directories

Without any config, the picker auto-scans `~/` up to 3 levels deep for git repos, skipping hidden dirs, `node_modules`, `.venv`, `vendor`, `target`, etc.

To pin specific directories (faster, explicit):

```bash
# bash / zsh — add to ~/.bashrc or ~/.zshrc
export SESH_REPO_DIRS="~/DEVELOPMENT:~/work:~/personal"

# fish — add to ~/.config/fish/config.fish
set -gx SESH_REPO_DIRS "$HOME/DEVELOPMENT:$HOME/work:$HOME/personal"
```

### Work vs personal colour

Repos under work dirs render in blue; everything else in purple. Default work dir is `~/DEVELOPMENT`.

```bash
export SESH_WORK_DIRS="~/DEVELOPMENT:~/client-work"
```

### Theming

| Variable           | Default              | Description                           |
| ------------------ | -------------------- | ------------------------------------- |
| `DVC_COLOR_ACTIVE` | `#14E21A`            | Active indicator, highlights, pointer |
| `DVC_COLOR_BORDER` | `#24b030`            | Border and label colour               |
| `DVC_COLOR_DIM`    | `#333333`            | Dim separator lines                   |
| `DVC_TITLE`        | `󰔎 Da Vinci Console` | Border label text                     |

#### Catppuccin Mocha

```bash
export DVC_COLOR_ACTIVE="#a6e3a1"
export DVC_COLOR_BORDER="#89b4fa"
export DVC_COLOR_DIM="#45475a"
export DVC_TITLE=" Da Vinci Console"
```

#### Tokyo Night

```bash
export DVC_COLOR_ACTIVE="#9ece6a"
export DVC_COLOR_BORDER="#7aa2f7"
export DVC_COLOR_DIM="#3b4261"
export DVC_TITLE="󰔎 Da Vinci Console"
```

---

## Adding Icons

Icons are matched in `icon_for()`. Edit `da-vinci-console.sh` to add your own:

```bash
icon_for() {
    local n="${1,,}"; n="${n##*/}"
    case "$n" in
        myproject*) echo "󱓞" ;;  # add your own here
        # ...
    esac
}
```

---

## Acknowledgements

- [sesh](https://github.com/joshmedeski/sesh) by Josh Medeski — session manager powering jump mode
- [fzf](https://github.com/junegunn/fzf) by Junegunn Choi — the fuzzy finder engine
- [onefetch](https://github.com/o2sh/onefetch) — repo stats in the preview pane
