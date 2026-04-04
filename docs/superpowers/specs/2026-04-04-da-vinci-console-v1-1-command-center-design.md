# Da Vinci Console v1.1 Command Center Refactor

Date: 2026-04-04
Status: Approved design
Scope: v1.1 redesign and implementation plan input

## Summary

Da Vinci Console should evolve from a static multi-section tmux picker into a path-backed workspace command center.

The current script already mixes tmux state, repos, current-directory entries, SSH hosts, snapshots, and optional Docker state. The redesign keeps the mixed-purpose identity, but changes the internal model so the tool is fast, collision-safe, and predictable.

The key design decision is that filesystem path is the canonical identity for project-backed workspaces. Session names, row labels, and source-specific entries become presentation and routing metadata rather than the primary truth.

## Goals

- Preserve the "single popup command center" feel.
- Keep sessions, project launches, and directory jumps as equal first-class workflows.
- Make the default view query-first while still showing type identity clearly.
- Remove basename-based collisions and incorrect dedup behavior.
- Make destructive actions safe and explicit.
- Reduce startup and preview latency through persistent local cache/state.
- Leave room for optional providers without letting them distort the core workflow.

## Non-Goals

- Preserving exact row layout or exact key behavior where it conflicts with the redesign.
- Rebuilding tmux persistence beyond simple session snapshots.
- Treating Docker as a core v1.1 workflow.
- Adding remote sync, cloud state, or multi-machine coordination.
- Preserving every existing secondary feature during the first refactor pass.

## Product Decisions

### Core mental model

The primary object is a normalized `item`, not a raw tmux row, repo path, SSH host, or snapshot file.

Each item has:

- a canonical `id`
- a `kind`
- a display label
- searchable text
- score metadata
- action metadata
- preview metadata

The default screen remains visually grouped, but groups are now rank-aware rather than rigid source buckets.

### Item classes

v1.1 uses three logical classes:

- `Live`: tmux sessions, windows, and pane-addressable live work
- `Projects`: path-backed workspaces, current-directory folders, and jump targets
- `Utilities`: SSH bookmarks and snapshots

### Docker

Docker is removed from the v1.1 default experience.

Reason:

- it is not a core user workflow for this project
- it complicates the action and preview model
- it can return later as an optional provider once the provider boundary is stable

The architecture should still leave a clear provider hook for Docker to return later without reshaping the main item model.

### Tags

Session tags are not part of v1.1.

Reason:

- the redesign centers path-backed workspace identity
- the current tag model is session-name-based and conflicts with that direction
- favorites/pins and usage history provide most of the value with less complexity

If tags return later, they should be implemented as item metadata on canonical workspace IDs, not as loose session-name mappings.

## Canonical Identity Model

### Rule

Path is truth for project-backed workspaces.

Examples:

- repo path: `workspace:/home/smiley/DEVELOPMENT/foo`
- open tmux session associated with that repo: same logical workspace item, with live state attached
- non-project scratch session: `session:<tmux-session-name>`
- window: `window:<session-name>:<window-index>`
- ssh host: `ssh:<host>`
- snapshot: `snapshot:<snapshot-name>`

### Consequences

- Two repos with the same basename but different paths must never collide.
- A project already open in tmux should not appear as a separate repo and session entry if both resolve to the same workspace path.
- Session names remain user-visible but are no longer the canonical identity for project-backed work.
- Scratch sessions that are not path-backed remain valid first-class live items.

### Path-to-session association

The system should maintain a lightweight mapping between canonical workspace path and its most relevant tmux session/window target.

This mapping is derived from tmux live state and cached hints. It allows:

- opening a closed workspace as a new session
- switching to an already-open workspace
- preferring the most relevant live target when multiple windows exist

## Default Interaction Model

### Empty-query view

When the query is empty, render a hybrid dashboard with visible groups:

- `Live`
- `Projects`
- `Utilities`

These are not hardcoded source sections. They are grouped ranked items.

### Query view

When the user types a query:

- all items participate in one ranked search result set
- type identity stays visible through badges, labels, or prefixes
- group boundaries may remain lightly visible, but ranking takes precedence over static section ordering

### Scoring

Ranking is query-first with smart boosts.

Base ordering should follow:

1. text match quality
2. live/attached tmux state boost
3. recent usage and frecency boost
4. current-directory proximity boost
5. favorite/pin boost
6. stable tie-breakers

This keeps search intuitive while still making active work and habitual targets easy to reach.

## Architecture

The redesign remains in Bash, but the current monolithic script should be reorganized into clear layers inside the same repository.

Logical modules:

- `main`: startup, dependency checks, fzf wiring, reload hooks
- `providers`: tmux, workspaces, current-dir, jump targets, ssh, snapshots
- `model`: normalize provider output into canonical items
- `state`: cache, usage history, favorites, path-to-session hints
- `rank`: scoring and group assignment
- `actions`: single and multi-select action dispatch
- `preview`: preview routing and expensive preview isolation

This is a separation-of-responsibilities design, not necessarily a mandate for many tiny files on day one. The implementation can still be staged inside Bash files as long as those boundaries are real.

## Provider Model

### Live provider

Inputs:

- tmux sessions
- tmux windows
- pane metadata when needed

Outputs:

- live session items
- live window items
- workspace live-state attachments for path-backed workspaces

### Workspace provider

Inputs:

- configured repo roots
- current directory
- jump targets from `sesh` and `zoxide`
- cache state

Rules:

- default repo scanning must prefer configured roots over a blind `$HOME` crawl
- if configured roots are absent, v1.1 should seed workspaces from cache, current directory, tmux paths, `sesh`, and `zoxide` instead of crawling all of `$HOME` on every launch
- full-home scans, if retained at all, must be explicit refresh actions rather than default launch behavior
- current-directory folders participate as candidate workspaces, not as special dead-end rows

### Utility providers

Included in v1.1:

- SSH bookmarks
- snapshots

Deferred:

- Docker
- tags

Utility providers must not dominate the default screen unless the query strongly matches them.

## Action Model

Actions are item-type-driven, not row-shape-driven.

### Primary action by item kind

- `workspace`
  - if live: switch to best live target
  - if not live: open or create session for the workspace path
- `window`
  - switch to the window's active pane
  - pane drill-down is a secondary action, not the default `Enter` behavior
- `session`
  - switch to session
- `ssh`
  - open a new tmux window running `ssh <host>`
- `snapshot`
  - restore snapshot

### Secondary actions

- `rename`
  - allowed for session and window
- `kill`
  - allowed for session and window
- `move-window`
  - allowed for window
- `snapshot-save`
  - allowed for session and workspace-backed live targets
- `favorite/pin`
  - allowed for workspace, ssh, and snapshot

Every action must be validated against item type before execution.

### Multi-select

Multi-select remains supported, but action routing must be explicit.

- `multi-open` may accept mixed launchable/openable types
- `multi-kill` only runs on killable types
- invalid mixed selections must fail predictably instead of partially guessing

## Safety Rules

- destructive actions require confirmation
- killing the currently attached session requires stronger confirmation than killing another session
- actions unavailable for the selected item must be blocked before execution
- current-directory files should not appear as inert selectable rows
- session/window actions should target canonical normalized items, not parse raw row text ad hoc

## Preview Model

Previews must be fast by default and richer on focus.

### Workspace preview

Default:

- cached branch
- cached dirty state
- language/type hint
- path

Focused enrichment:

- recent commits
- optional deeper git details

### Live tmux preview

- session/window metadata
- recent pane output

### SSH preview

- parsed host config summary

### Snapshot preview

- stored windows and paths summary

### Performance rule

Expensive preview work must be localized to the focused item. No expensive provider should block the entire list render.

## Cache And State

Persistent state is required for v1.1.

Recommended location:

- `~/.cache/da-vinci-console/`

State files should include:

- workspace cache
- usage history / frecency
- favorites / pins
- path-to-session hints

Cached workspace metadata should include:

- canonical path
- display label
- repo root
- branch
- dirty count or dirty flag
- language/type hint
- last scan timestamp

Usage history should include:

- last opened timestamp
- open count or frecency score
- optional pin/favorite state

Live tmux state is always fresh. Repo and git state may be slightly stale if that keeps the picker responsive.

## Snapshot Scope

Snapshots remain in v1.1, but their scope is intentionally limited.

Supported:

- session name
- window names
- working directories
- launch commands where available

Not guaranteed:

- exact pane topology recreation
- exact pane history
- full tmux state restoration fidelity

The feature should be reliable at the "restore a useful working shell layout" level, not marketed as full tmux serialization.

## UX Changes Expected In v1.1

- the default view becomes hybrid and ranked rather than rigidly section-ordered
- workspace items dedupe against open tmux state by canonical path
- current-directory folders become real workspace candidates
- destructive actions prompt before execution
- Docker disappears from the default command center
- tags disappear from v1.1
- favorites/pins and usage history become the main personalization mechanisms

## Rollout Plan

Implementation order:

1. introduce normalized item schema and canonical IDs
2. add persistent cache and usage history
3. rebuild default list generation around normalized ranked items
4. replace action handling with a typed dispatcher and confirmations
5. reintroduce utility providers under the new model
6. add focused tests for identity, ranking, and action validation

## Testing Strategy

### Logic tests

Add shell-level tests for:

- canonical ID generation
- workspace/session dedup
- ranking/scoring behavior
- action validation
- multi-select routing

### Fixture-driven parsing tests

Add fixtures for:

- tmux list output
- ssh config parsing
- snapshot parsing

### Manual verification

Run targeted checks for:

- basename collision handling
- open workspace dedup
- empty-query hybrid dashboard behavior
- mixed query ranking behavior
- destructive action confirmations
- multi-open and multi-kill behavior
- preview latency sanity

## Risks And Mitigations

### Risk: Bash complexity grows again

Mitigation:

- enforce provider/model/action boundaries early
- add tests around normalized item behavior instead of only manual tmux checks

### Risk: cache becomes stale or confusing

Mitigation:

- prefer stale-but-fast rendering with clear refresh policy
- keep live tmux state uncached
- make cached workspace metadata refresh bounded and targeted

### Risk: secondary utilities crowd out core workflows

Mitigation:

- keep utility providers low priority in empty-query view
- let query matching surface them when relevant

## Definition Of Done For v1.1

v1.1 is complete when:

- project-backed identity is canonical-path-based
- default view is a hybrid ranked command center
- open/live work dedupes correctly with project items
- actions are dispatched by item type with confirmations for destructive behavior
- cache/state exists and meaningfully improves responsiveness
- SSH and snapshots work under the new model
- Docker and tags are not part of the default v1.1 scope
