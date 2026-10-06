# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, and others) working in this repo.

This repo is a demo app for teaching middle and high school students how deployment works. See [README.md](README.md) for the layout.

## Language: English by default

Everything written into this repository must be in English. This includes:

- Code: identifiers, comments, and docstrings
- Text users see: UI text, error messages, and log or terminal output from scripts
- Docs: README, everything under `docs/`, and file names
- Config: comments in YAML, Dockerfile, compose files, and `.env.example` files
- Tests: test names and test data
- CI: workflow and step names
- Git: commit messages, branch names, and PR titles and descriptions

Chat replies may follow the language the user writes in. Only what goes into the repo has to be English.

If you find non-English text while working on a file, translate it as part of your change.

To check for leftover Korean text before committing:

```bash
git grep -nP --untracked '(*UTF)[\x{AC00}-\x{D7A3}]'
```

It should print nothing. `--untracked` also checks new files that are not committed yet.
