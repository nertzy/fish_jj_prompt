# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

A Fish shell plugin that provides an enhanced prompt for Jujutsu (jj) repositories. It replaces Fish's built-in minimal `fish_jj_prompt` with a rich prompt showing change/commit IDs, bookmarks, ahead/behind counts, and status flags.

Installed via Fisher (`fisher install nertzy/fish_jj_prompt`) or by copying `functions/fish_jj_prompt.fish` to `~/.config/fish/functions/`.

## Architecture

The entire plugin is a single function in `functions/fish_jj_prompt.fish`. It works by:

1. **Single `jj log` call** with a complex template that outputs three line types:
   - **TAB lines** — the `@` (working copy) info + bookmark data, split by `\t`
   - **"B" lines** — commits behind trunk (counted for `↓N`)
   - **"." or "depth:bookmark" lines** — ancestor commits (counted for `↑N`); bookmarks get depth annotations like `main↑2`

2. **Dynamic depth expression** — built once and cached in `$__fish_jj_depth_expr`. Uses `coalesce(if(self.contained_in("@-"),"1"), if(self.contained_in("@--"),"2"), ...)` up to 20 generations to determine how far an ancestor bookmark is from `@`.

3. **Output assembly** — parses the raw lines, applies ANSI colors (bold magenta for `@` bookmarks, regular magenta with `↑N` for ancestor bookmarks), and formats as `(@ changeId commitId status bookmarks ↑ahead ↓behind)`.

## Testing

There is no test suite. Manual testing by sourcing the function in a fish shell inside a jj repo.

## Fish Shell Pitfalls

- `!` is escaped to `\!` even in single-quoted strings (fish 4.5+). Avoid `!` in templates passed to external commands; use positive conditions with if/else instead.
- `string match -rq` does NOT populate `$match` in fish 4.5. Use `string split` or `string match -r` (without `-q`) instead.
- `"$var"` escapes `!` in variable values when expanded in double quotes.

## jj Template Notes

- The revset `trunk()..@ | (::trunk() & ~::@)` captures both the ancestor chain and behind-trunk commits in one query.
- `self.contained_in("@-")` checks parent, `@--` grandparent, etc.
- `local_bookmarks` is a list type — can use in `if()` but avoid with `&&`/`||`.
- The template is stored in a fish variable (not inline) to avoid fish parser escaping issues.
