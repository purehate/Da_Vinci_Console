# Da Vinci Console Sectional Hierarchy Refresh

Date: 2026-04-04
Status: Approved design
Scope: improve the classic sectional picker without changing its core mental model

## Summary

Da Vinci Console should keep the classic sectional popup rather than the command-center style unified list.

The next revision should make the screen read with clearer hierarchy:

- `Sessions & Windows` as the primary block
- `Repos` as the secondary block
- `Utilities` as a compact tertiary block for support tools

The tool must stay as one scrollable popup with global search. Search filters rows in place instead of collapsing everything into one mixed result set.

## Goals

- Preserve the existing sectional feel the user prefers.
- Make sessions and repos visually and behaviorally dominant.
- Add direct section navigation without introducing view modes.
- Improve startup and reload responsiveness in the existing model.
- Reduce bottom-of-screen noise from low-value rows and secondary sections.
- Keep the current broad repo discovery behavior.

## Non-Goals

- Returning to a unified ranked item model.
- Reframing Docker or other utilities as first-class workflows.
- Adding confirmation-heavy safety UX intended for multi-user distribution.
- Replacing the popup with multiple views or mode-driven navigation.
- Removing the current home-scan repo discovery behavior.

## Product Decisions

### Core mental model

The picker remains a single popup composed of visible sections.

Sections are real structural groups, not a temporary rendering of one mixed internal list. The user should always be able to tell where sessions end, where repos begin, and where support tools live.

### Section hierarchy

The default screen is reorganized into three tiers:

1. `Sessions & Windows`
2. `Repos`
3. `Utilities`

`Utilities` contains:

- `Current Dir`
- `SSH`
- `Docker`, only when Docker is available and has running containers

### Search behavior

Search is always global.

When the query changes:

- every section is filtered against the same query
- matching rows stay inside their original section
- non-matching rows disappear
- empty sections disappear for that query

The picker must never collapse into a single mixed result list during search.

### Discovery behavior

Keep the current repo discovery model:

- if `SESH_REPO_DIRS` is set, use those configured roots
- otherwise continue auto-scanning `~/` with the existing prune rules

This is intentionally not the fast-first provider model from the reverted command-center work.

## Layout

### Sessions & Windows

This is the anchor block at the top of the popup.

Requirements:

- strongest header treatment
- most vertical presence
- attached sessions first
- most recent sessions above older sessions
- session children remain visually grouped beneath the parent session

The section header should show a count, for example:

- `Sessions & Windows (8)`

### Repos

Repos remain a full section under sessions, but visually quieter than the top block.

Requirements:

- preserve existing repo rows and metadata style
- repos already open in tmux sort first
- remaining repos keep stable alphabetical ordering
- section header includes a count

Example:

- `Repos (24)`

### Utilities

Utilities becomes a compact support block rather than a peer to sessions and repos.

Requirements:

- one shared `Utilities` header with a count
- inside it, smaller labelled sub-blocks for `Current Dir`, `SSH`, and `Docker`
- tighter spacing than the two primary sections
- `Docker` omitted when empty

This block should read like “extra tools at hand,” not “another main dataset.”

## Row Rules

### Current Dir

Current directory entries should become more useful and less noisy.

Requirements:

- directories shown first
- directories remain selectable launch targets
- inert file rows should be hidden by default instead of rendered as dead-end items

### SSH

SSH hosts remain available, but they should live inside the utilities block and inherit its quieter presentation.

### Docker

Docker remains optional and low-priority.

Requirements:

- only render when Docker exists and there are running containers
- keep current open-shell behavior
- do not expand Docker preview or screen presence beyond the compact utilities area

## Navigation

### Standard movement

Normal up/down movement remains unchanged.

### Section jump keys

Add direct section navigation:

- `]` jumps to the next visible top-level section
- `[` jumps to the previous visible top-level section

Rules:

- these keys move the cursor only
- they do not change mode
- they do not change search scope
- they skip sections hidden by the current query

Existing keys such as `Ctrl-J`, `Ctrl-W`, and `Ctrl-G` keep their current behavior.

## Ranking Within Sections

### Sessions & Windows

Ordering rules:

1. attached session
2. most recently active sessions
3. each session’s windows underneath the owning session

### Repos

Ordering rules:

1. repos already mapped to a live tmux session
2. remaining repos in stable alphabetical order

### Utilities

Ordering rules:

1. Current Dir
2. SSH
3. Docker

## Performance

The classic picker should be made faster without changing its visible behavior too much.

Requirements:

- avoid recomputing repo branch and dirty-state metadata more than once per reload
- avoid expensive work for rows that are not currently selected
- keep preview computation lazy and row-driven
- preserve current repo scan behavior, but do not add extra redundant scans during one picker invocation

## Readability

The redesign should rely on hierarchy and spacing, not more ornament.

Requirements:

- stronger top header and separator treatment for `Sessions & Windows`
- medium emphasis for `Repos`
- compact, quieter treatment for `Utilities`
- per-section counts
- clearer spacing rhythm between major blocks and sub-blocks

## Architecture

This should remain an evolution of the classic script, not a return to the command-center module stack.

Refactoring is allowed, but only in support of clearer section rendering and navigation.

Preferred internal structure:

- one builder for `Sessions & Windows`
- one builder for `Repos`
- one builder for `Utilities`
- one small helper for section-jump navigation
- one shared filtering path used by all sections

Do not reintroduce a generic normalized item pipeline just to implement hierarchy.

## Testing

At minimum, implementation should verify:

- global search preserves section structure
- empty sections disappear while searching
- section counts reflect visible rows
- `[` and `]` jump between visible sections correctly
- current-dir files no longer appear as inert rows
- Docker remains hidden when unavailable or empty
- the popup still launches cleanly via the installed tmux binding

## Acceptance Criteria

- The popup still feels like the old Da Vinci Console, not a different product.
- Sessions and repos dominate the screen visually.
- Utilities are still available but no longer compete for attention.
- Search works across all sections without collapsing them into one list.
- Section jump keys make large result sets faster to navigate.
- The picker feels at least as responsive as the current rolled-back build.
