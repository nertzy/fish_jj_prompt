# fish_jj_prompt.fish

An enhanced [Fish](https://fishshell.com) prompt for [Jujutsu (jj)](https://github.com/jj-vcs/jj) repositories.

Fish ships with a built-in `fish_jj_prompt` that only shows a conflict marker. This plugin replaces it with a much richer prompt: change ID, commit ID, bookmarks, ahead/behind counts, and status flags — all with ANSI color via jj's built-in coloring.

## Features

- Shows change ID and commit ID (shortest unique prefix)
- Displays bookmarks at `@` and ancestor commits, with depth indicators (↑N)
- Shows ahead count (commits above nearest bookmark) and behind count (commits behind trunk)
- Labels for conflict (`×`), divergent (`??`), hidden, immutable (`◆`), empty/(merged)
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

## Prompt Output Examples

```
(@ abc1 def2 * my-feature main↑2 ↑3 ↓1)
 |  |    |   |     |        |    |   |
 |  |    |   |     |        |    |   └ behind trunk
 |  |    |   |     |        |    └ ahead of trunk
 |  |    |   |     |        └ ancestor bookmark (2 commits up)
 |  |    |   |     └ bookmark at @
 |  |    |   └ status: * modified, (empty), (merged), × conflict, ?? divergent, ◆ immutable
 |  |    └ commit ID (shortest unique prefix)
 |  └ change ID (shortest unique prefix)
 └ working copy marker
```

Tags on @ and ancestor commits between @ and trunk are shown alongside bookmarks. Tags on trunk itself are not shown.

```
(@ abc1 def2 my-feature)           # on bookmark "my-feature"
(@ abc1 def2 * my-feature↑2 ↑3)    # 3 ahead of trunk, my-feature is 2 up
(@ abc1 def2 * ↑3 ↓1)              # 3 ahead of trunk, 1 behind
(@ abc1 def2 ×)                    # conflict
```

## License

MIT
