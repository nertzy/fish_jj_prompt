# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

A Fish shell plugin that provides an enhanced prompt for Jujutsu (jj) repositories. It replaces Fish's built-in minimal `fish_jj_prompt` with a rich prompt matching the default `jj log -r @` output: same fields, same order, same colors — but condensed for a prompt.

Installed via Fisher (`fisher install nertzy/fish_jj_prompt`) or by copying `functions/fish_jj_prompt.fish` to `~/.config/fish/functions/`.

## Architecture

The entire plugin is a single function in `functions/fish_jj_prompt.fish`. It works by:

1. **Single `jj log` call** with a complex template that outputs structured tab-delimited lines:
   - **@ line** (8 fields): `change_id \t author \t bookmarks \t working_copies \t commit_id \t status \t immutable \t description`
   - **Ancestor with bookmarks** (2 fields): `change_id \t bookmarks`
   - **Ancestor without bookmarks**: `.`
   - **Behind-trunk commit**: `B`

2. **Per-bookmark depth sub-queries** — for each ancestor bookmark, runs `jj log -r "$cid::@ ~ $cid"` to count the depth.

3. **Output assembly** — parses the raw lines, applies ANSI colors matching jj's defaults, and formats as `(@ change_id [author] [bookmarks] [workspace@] commit_id status [description] [ancestor_bookmarks↑N] ↑ahead ↓behind)`.

### Field order matches `jj log`

The prompt follows the default `format_short_commit_header` template order: change_id, author, bookmarks/tags, working_copies, commit_id, labels (conflict/divergent).

### Color matching

Colors use the exact ANSI 256-color codes from jj's default theme:
- `@` symbol: green (mutable), color 14/cyan (immutable), color 1/dark red (conflict)
- Change ID: bright magenta (normal), color 9 (divergent)
- Commit ID: bright blue
- Author: color 3/yellow
- Bookmarks at @: bright magenta
- Ancestor bookmarks: magenta with non-bold `↑N` depth
- Workspace: bright green
- Status: bright green (empty), yellow (modified), bright red (conflict/divergent)
- Description: inherits bold from prompt wrapper; placeholder uses status color
- Ahead/behind: gray (brblack), always non-bold

### Bold handling

Bold is applied as a single `\e[1m` at the start of the prompt output. Individual color changes use `\e[39m` (foreground reset) instead of `\e[0m` (full reset) to preserve bold state. Arrows (↑/↓) use `\e[22m` to turn off bold. Configurable via `fish_jj_prompt_bold`.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `fish_jj_prompt_bold` | `true` | Set to `false` to disable bold text |
| `fish_jj_prompt_show_description` | `true` | Set to `false` to hide description |
| `fish_jj_prompt_description_length` | `24` | Max chars for description. `0` = no truncation |

## Testing

Tests use [Fishtape](https://github.com/jorgebucaran/fishtape) (TAP-based test runner for Fish):

```fish
fisher install jorgebucaran/fishtape   # one-time setup
fishtape tests/test_fish_jj_prompt.fish
```

Fishtape does not support running individual tests — it always runs the entire file. To focus on a specific test, temporarily comment out other `@test` lines.

Tests create temporary jj repos and verify prompt output. Each test uses `setup_repo` which creates a fresh `jj git init` repo in a temp directory.

CI runs via GitHub Actions on push to main and pull requests, using [fish-shop/install-fish-shell](https://github.com/fish-shop/install-fish-shell) and [fish-shop/run-fishtape-tests](https://github.com/fish-shop/run-fishtape-tests) for fish + test infrastructure. There is no setup-jj GitHub Action; jj is installed via `gh release download` from [jj-vcs/jj](https://github.com/jj-vcs/jj) releases.

## Fish Shell Pitfalls

- `!` is escaped to `\!` even in single-quoted strings (fish 4.5+). Avoid `!` in templates passed to external commands; use positive conditions with if/else instead.
- `string match -rq` does NOT populate `$match` in fish 4.5. Use `string split` or `string match -r` (without `-q`) instead.
- `"$var"` escapes `!` in variable values when expanded in double quotes.
- `status` is a reserved variable in fish. Do not use it as a local variable name.

## jj Template Notes

- The revset `trunk()..@ | (::trunk() & ~::@)` captures both the ancestor chain and behind-trunk commits in one query.
- `self.contained_in("mine()")` checks authorship in templates (`mine()` is a revset function, not a template function).
- `local_bookmarks` is a list type — can use in `if()` but avoid with `&&`/`||`.
- `working_copies` outputs workspace names with `@` suffix (e.g., `default@`).
- `change_offset` gives the variant number for divergent changes (e.g., `/0`, `/1`).
- The template is stored in a fish variable (not inline) to avoid fish parser escaping issues.
- jj automatically appends `*` to bookmark names that are unpushed (no tracking remote or differ from tracked remote). This passes through in the template output and is displayed as-is.
