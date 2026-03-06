# fish_jj_prompt.fish

A [Fish](https://fishshell.com) prompt segment for [Jujutsu (jj)](https://github.com/jj-vcs/jj) repositories.

Displays the current working-copy change ID, bookmarks, commit ID, ahead/behind counts, and status flags (conflict, divergent, hidden, immutable, empty) — all with ANSI color via jj's built-in coloring.

## Features

- Shows change ID and commit ID (shortest unique prefix)
- Displays bookmarks at `@` and ancestor commits, with depth indicators (↑N)
- Shows ahead count (commits above nearest bookmark) and behind count (commits behind trunk)
- Labels for conflict (×), divergent (??), hidden, immutable (◆), empty/(merged)
- Returns early (exit 1) if jj is not installed or a `.disable-jj-prompt` file exists at the repo root

## Requirements

- [Fish](https://fishshell.com) 3.0+
- [jj](https://github.com/jj-vcs/jj) installed and on `$PATH`

## Installation

### Via [Fisher](https://github.com/jorgebucaran/fisher)

```fish
fisher install nertzy/fish_jj_prompt.fish
```

### Manually

Copy `functions/fish_jj_prompt.fish` into `~/.config/fish/functions/`.

## Usage

Call `fish_jj_prompt` from your `fish_prompt` or `fish_right_prompt` function:

```fish
function fish_prompt
    # ... your existing prompt pieces ...
    fish_jj_prompt
    echo -n '> '
end
```

Or as a right prompt:

```fish
function fish_right_prompt
    fish_jj_prompt
end
```

### Disabling per-repo

Create a `.disable-jj-prompt` file at the root of any jj repo to suppress the prompt in that repo:

```sh
touch .disable-jj-prompt
```

## Prompt Output Examples

```
(@ abc1 main def2)           # on bookmark "main"
(@ abc1 * def2 main↑1 ↑2)   # 3 commits ahead of main bookmark
(@ abc1 * def2 ↑3 ↓1)       # 3 ahead of trunk, 1 behind
(@ abc1 × def2)              # conflict
```

## License

MIT
