# Contributing

Thanks for your interest in contributing to fish_jj_prompt!

## Development

The entire plugin is a single function in `functions/fish_jj_prompt.fish`. To test changes, source the function in a fish shell inside a jj repo:

```fish
source functions/fish_jj_prompt.fish
fish_jj_prompt
```

## Testing

Tests use [Fishtape](https://github.com/jorgebucaran/fishtape):

```fish
fisher install jorgebucaran/fishtape   # one-time setup
fishtape tests/test_fish_jj_prompt.fish
```

Please add tests for new features and ensure all existing tests pass before submitting a PR.

## Design Principles

- Match the default `jj log -r @` output: same fields, same order, same colors
- Use short forms where possible (shortest IDs, email local part, truncated description)
- Keep it as a single function with no external dependencies beyond jj

## Commits

- Use imperative mood in commit messages ("Add feature" not "Added feature")
- Keep the subject line under 50 characters
- Wrap the body at 72 characters

## Pull Requests

- One logical change per PR
- Include a brief description of what and why
- Ensure CI passes
