# fish_jj_prompt.fish

An enhanced [Fish](https://fishshell.com) prompt for [Jujutsu (jj)](https://github.com/jj-vcs/jj) repositories.

Fish ships with a built-in `fish_jj_prompt` that only shows a conflict marker. This plugin replaces it with a much richer prompt: change ID, commit ID, bookmarks, ahead/behind counts, and status flags — all with ANSI color via jj's built-in coloring.

## Design Goals

- Match the default `jj log -r @` output: same fields, same order, same colors
- Use short forms: shortest unique change/commit IDs, email local part only, description truncated to 24 chars
- Omit the date
- Omit your own email (only show author for others' commits via `mine()`)
- Add ahead/behind counts (↑N/↓N) and ancestor bookmark depth indicators

## Features

- Shows change ID and commit ID (shortest unique prefix)
- Displays bookmarks at `@` and ancestor commits, with depth indicators (↑N)
- Shows ahead count (commits above nearest bookmark) and behind count (commits behind trunk)
- Shows description (truncated to 24 characters)
- Labels for conflict (`(conflict)`), divergent (`(divergent)` with change offset), hidden, empty
- Immutable working copy indicated by `@` color (cyan instead of green), matching jj log
- Shows author (email local part) when the commit is not yours (`mine()`)
- Shows workspace name when multiple workspaces exist
- Returns early (exit 1) if jj is not installed or a `.disable-jj-prompt` file exists at the repo root

## Requirements

- [Fish](https://fishshell.com) 3.0+
- [jj](https://github.com/jj-vcs/jj) installed and on `$PATH`

## Installation

### Via [Fisher](https://github.com/jorgebucaran/fisher)

```fish
fisher install nertzy/fish_jj_prompt
```

### Manually

Copy `functions/fish_jj_prompt.fish` into `~/.config/fish/functions/`.

## How it works

Fish's default prompt calls `fish_vcs_prompt`, which tries VCS prompts in order:

```fish
fish_jj_prompt $argv
or fish_git_prompt $argv
or fish_hg_prompt $argv
```

When this plugin is installed, Fish's autoloader picks up the plugin's `fish_jj_prompt` from `~/.config/fish/functions/` before the built-in version in Fish's `share/functions/` directory. **No prompt configuration is needed** — the default prompt automatically gets the enhanced jj info.

Because jj repos contain a `.git` directory, `fish_git_prompt` would also match. The `or` chain ensures that when `fish_jj_prompt` succeeds (returns 0), `fish_git_prompt` is skipped, avoiding duplicate VCS info. If jj is not installed or the prompt is disabled, `fish_jj_prompt` returns 1 and Fish falls through to `fish_git_prompt` as usual.

### Custom prompts

You can also call `fish_jj_prompt` directly from a custom prompt:

```fish
function fish_prompt
    # ... your existing prompt pieces ...
    fish_jj_prompt
    # or use fish_vcs_prompt to include git/hg fallback
    echo -n '> '
end
```

### Disabling per-repo

Create a `.disable-jj-prompt` file at the root of any jj repo to suppress the prompt in that repo. This causes `fish_jj_prompt` to return 1, so `fish_vcs_prompt` will fall back to `fish_git_prompt`.

```sh
touch .disable-jj-prompt
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `fish_jj_prompt_bold` | `true` | Set to `false` to disable bold text. |
| `fish_jj_prompt_show_description` | `true` | Set to `false` to hide the commit description. |
| `fish_jj_prompt_description_length` | `24` | Max characters for commit description. `0` for no truncation. |

```fish
# In config.fish or interactively:
set -g fish_jj_prompt_bold false              # disable bold text
set -g fish_jj_prompt_description_length 40   # longer descriptions
set -g fish_jj_prompt_description_length 0    # full description, no truncation
set -g fish_jj_prompt_show_description false   # hide description entirely
```

## Prompt Output Examples

```
(@ abc1 jdoe my-feature default@ def2 * Add foo feature ↑3 ↓1)
 |  |    |       |         |      |  |       |            |   |
 |  |    |       |         |      |  |       |            |   └ behind trunk
 |  |    |       |         |      |  |       |            └ ahead of trunk
 |  |    |       |         |      |  |       └ description (truncated to 24 chars)
 |  |    |       |         |      |  └ status: * modified, (empty), (conflict), (divergent)
 |  |    |       |         |      └ commit ID (shortest unique prefix)
 |  |    |       |         └ workspace (only shown with multiple workspaces)
 |  |    |       └ bookmark at @
 |  |    └ author (only shown when not mine())
 |  └ change ID (shortest unique prefix, with /N variant on divergent changes)
 └ working copy marker (green = mutable, cyan = immutable, red = conflict)
```

Bookmarks that need to be pushed (no tracking remote, or differ from their tracked remote) are shown with a trailing `*` by jj — this passes through automatically into the prompt.

Tags on @ and ancestor commits between @ and trunk are shown alongside bookmarks. Tags on trunk itself are not shown.

```
(@ abc1 def2 (empty) (no description set) ↑1)     # new empty commit
(@ abc1 def2 * Add user validation ↑1)            # modified, 1 ahead of trunk
(@ abc1 my-feature def2 * Fix login bug ↑1)       # on bookmark, 1 ahead
(@ abc1 my-feature def2 (empty) ↑1)               # on bookmark, no changes yet
(@ abc1 my-feature* def2 * Add search ↑3)         # unpushed bookmark, 3 ahead
(@ abc1 def2 * Refactor auth… api↑1 ui↑3 ↑4)     # stacked branches at different depths
(@ abc1 def2 (empty) api↑1 ui↑1 ↑2)               # merge commit, empty, each branch 1 up
(@ abc1 def2 * Update deps ↑3 ↓1)                 # 3 ahead, 1 behind trunk
(@ abc1 def2 (conflict) (empty) ↑2)                # conflict, 2 ahead
(@ abc1 def2 * Release v2.0)                       # on trunk (immutable, cyan @)
(@ abc1/0 def2 * Fix auth (divergent) ↑1)         # divergent change, variant 0
(@ abc1 default@ def2 * Add caching ↑1)            # workspace shown (multi-workspace repo)
(@ abc1 jdoe my-feature def2 * Fix login ↑1)      # someone else's commit
```

## Testing

Tests use [Fishtape](https://github.com/jorgebucaran/fishtape), a TAP-based test runner for Fish.

```fish
fisher install jorgebucaran/fishtape   # one-time setup
fishtape tests/test_fish_jj_prompt.fish
```

## License

MIT
