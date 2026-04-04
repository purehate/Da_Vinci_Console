# 󰔎 Da Vinci Console

Da Vinci Console is a tmux command center built around path-backed workspaces, live tmux state, and a ranked fzf popup. Instead of dumping static sections into one list, it merges open work, launchable projects, SSH bookmarks, and session snapshots into a single query-first picker.

![Da Vinci Console screenshot](assets/screenshot.png)

---

## What v1.1 changes

- **Path is truth**: project-backed workspaces are identified by absolute path, not basename, so duplicate repo names no longer collide.
- **Hybrid ranked view**: results are grouped as `Live`, `Projects`, and `Utilities`, but search ranking still drives what rises to the top.
- **Seeded discovery by default**: if `SESH_REPO_DIRS` is unset, the picker seeds candidates from the current directory, cached workspaces, tmux paths, `sesh`, and `zoxide` instead of crawling all of `~/`.
- **Typed actions**: `Enter` routes by item type, `Ctrl-F` toggles pins, and destructive actions ask for confirmation.
- **Utilities stay secondary**: SSH bookmarks and snapshots are included without taking over the main workflow.

---

## Features

- **Live tmux + workspace dedup**: an open repo path becomes one logical item instead of separate repo/session duplicates.
- **Persistent pins and usage history**: pinned items get a boost in the ranked view and workspace opens are recorded in local cache state.
- **Workspace launch and resume**: `Enter` switches to live work when it exists or opens the workspace in tmux when it does not.
- **SSH bookmarks**: reads `Host` entries from `~/.ssh/config` and opens them in a new tmux window.
- **Session snapshots**: lists saved snapshots from `~/.config/tmux/snapshots/` and restores them as tmux sessions.
- **Focused previews**: workspace previews show recent git history, live tmux items show pane output, and utility rows show relevant metadata.
- **Safer destructive actions**: kill actions require confirmation and attached sessions get a stronger prompt.

---

## Requirements

| Tool | Required | Notes |
| ---- | -------- | ----- |
| [tmux](https://github.com/tmux/tmux) | Yes | Popup host and session/window control |
| [fzf](https://github.com/junegunn/fzf) | Yes, `0.58+` | Uses bordered input/list/preview labels |
| [sesh](https://github.com/joshmedeski/sesh) | Optional | Adds extra seeded workspace candidates |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Optional | Adds frecent directory candidates |
| [Nerd Font](https://www.nerdfonts.com/) | Optional | For icons |

---

## Install

```bash
git clone https://github.com/purehate/Da_Vinci_Console
cd Da_Vinci_Console
./install.sh
```

The installer copies `da-vinci-console.sh` to `~/.config/tmux/sesh_picker.sh`, prints the popup bind, and shows optional shell configuration for `SESH_REPO_DIRS`.

---

## Tmux binding

Add this to your `tmux.conf`:

```tmux
bind s display-popup -B -x C -y C -w 72% -h 72% -s "bg=default" -E "~/.config/tmux/sesh_picker.sh"
```

Or use [extras/tmux.conf](extras/tmux.conf).

---

## Keybindings

| Key | Action |
| --- | ------ |
| `Enter` | Open or switch to the selected item |
| `Tab` / `Shift-Tab` | Select and move down / up |
| `Ctrl-F` | Toggle pin on the selected item |
| `Ctrl-X` / `Ctrl-D` | Kill the selected window or session with confirmation |
| `Ctrl-A` | Reset back to the default query state |
| `Ctrl-/` | Toggle preview |
| `Alt-↑` / `Alt-↓` | Scroll preview |
| `Esc` / `Ctrl-C` | Exit |

Selecting multiple rows with `Tab` and pressing `Enter` opens all selected items in sequence.

---

## Configuration

### Workspace roots

If you want explicit workspace discovery, set `SESH_REPO_DIRS`:

```bash
# bash / zsh
export SESH_REPO_DIRS="$HOME/DEVELOPMENT:$HOME/work:$HOME/personal"

# fish
set -gx SESH_REPO_DIRS "$HOME/DEVELOPMENT:$HOME/work:$HOME/personal"
```

If `SESH_REPO_DIRS` is unset, the picker uses seeded discovery from the current directory, cached workspaces, tmux paths, `sesh`, and `zoxide`.

### Snapshots

Snapshots live under `~/.config/tmux/snapshots/` and use a simple text format:

```text
session=my-session
window|editor|/path/to/repo|nvim
window|server|/path/to/repo|zsh
```

### Cache state

Local state is stored under:

```text
~/.cache/da-vinci-console/
```

This includes workspace cache, usage history, and pin state.

---

## Notes

- `SESH_WORK_DIRS`, Docker rows, and session tags are not part of the v1.1 command-center scope.
- The codebase is still Bash-first, but the runtime now routes through focused library files under `lib/dvc/`.

---

## Acknowledgements

- [tmux](https://github.com/tmux/tmux)
- [fzf](https://github.com/junegunn/fzf)
- [sesh](https://github.com/joshmedeski/sesh)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
