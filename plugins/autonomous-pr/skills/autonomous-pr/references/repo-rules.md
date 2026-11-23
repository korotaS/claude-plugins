# Finding a repo's rules

Every repo has rules, written down or not, and a PR that breaks them gets
sent back however good the code is. Before planning, collect them into
`$RUN/repo-rules.md`. Cite each rule with its source: a file and line, or
the evidence for an unwritten one ("9 of the last 10 merged PRs").

Rules written in the repo beat the habits you see in its history. Habits
beat your own defaults. Rules closer to the code you change beat rules
further away (a `src/api/AGENTS.md` beats the root one for files under
`src/api/`). If two written rules really conflict, ask in phase 2 rather
than picking one.

## Where to look

**Docs.** `README*`, `CONTRIBUTING*`, `DEVELOPMENT*`, `HACKING*`,
`ARCHITECTURE*`, `STYLEGUIDE*`, `docs/` (look for development, testing, style
and architecture pages), and decision records (`docs/adr/`,
`docs/decisions/`, `adr/`). Also note which docs describe the behaviour you
are about to change: those need updating in the same PR (pages under
`docs/`, `CHANGELOG*`, API references, docstrings, CLI `--help` text).

**AI docs.** Instructions written for coding agents. Read every one that
exists, at the root and in each directory on the path to the files you will
touch:
`CLAUDE.md` (not `CLAUDE.local.md`, which is someone's personal file),
`AGENTS.md`, `.claude/` (rules, commands, skills, and the hooks in
`settings.json`, which will run on your tool calls), `.cursorrules`,
`.cursor/rules/`, `.github/copilot-instructions.md`,
`.github/instructions/*.instructions.md`, `.windsurfrules`, `.clinerules`,
`GEMINI.md`, `CONVENTIONS.md`, `llms.txt`.

**Branch names.** `git branch -r --sort=-committerdate | head -30` and
`gh pr list --state merged -L 30 --json headRefName`. Work out the pattern:
the prefixes in use (`feat/`, `fix/`, `<user>/`), ticket ids (`ABC-123-...`),
separators and case. A documented rule in `CONTRIBUTING*` overrides the
pattern.

**PR conventions.**
- Templates: `.github/pull_request_template.md`,
  `.github/PULL_REQUEST_TEMPLATE/`, `docs/pull_request_template.md`,
  `pull_request_template.md` at the root. A template's sections are required.
- Recent merged PRs: `gh pr list --state merged -L 20 --json number,title,labels,isDraft`,
  then read three to five bodies (`gh pr view <n> --json body`). Note the
  title format (conventional commit, ticket prefix, plain sentence), the body
  structure, labels, how issues are linked (`Closes #12`, a ticket URL), and
  whether PRs start as drafts.
- Enforcement: CI workflows that lint PR titles or bodies (semantic PR
  actions, Danger), required changelog entries (`.changeset/`,
  `newsfragments/` for towncrier, an "Unreleased" section in `CHANGELOG*`),
  `CODEOWNERS`.
- The merge style, if visible (squash vs merge commits in `git log` of the
  default branch). With squash merges the PR title becomes the commit
  subject, so it carries the commit convention too.

**Commit conventions.** commitlint config (`commitlint.config.*`,
`.commitlintrc*`), `.gitmessage`, rules in `CONTRIBUTING*`, and the pattern
in `git log --oneline -30` of the default branch. If the repo requires a
DCO sign-off (`Signed-off-by:`; look for `.github/dco.yml` or a DCO note in
`CONTRIBUTING*`), commit with `-s` as well as `-S`.

**Code style, written.** `.editorconfig`, pre-commit hooks, and the
formatter, linter and type-checker configs of each language: for Python,
`pyproject.toml` (`[tool.ruff]`, `black`, `isort`, `mypy`, `pyright`),
`setup.cfg`, `.flake8`, `tox.ini`, `.pylintrc`; for JS and TS,
`.prettierrc*`, `eslint.config.*` / `.eslintrc*`, `biome.json`, the
strictness in `tsconfig.json`; for Go, `.golangci.yml`; for Rust,
`rustfmt.toml`, `clippy.toml`; for C and C++, `.clang-format`,
`.clang-tidy`; for Java and Kotlin, checkstyle, spotless, ktlint; for shell,
`.shellcheckrc`; for Markdown and YAML, `.markdownlint*` and `.yamllint*`.
These tools also run in the CI recipe; here, note the rules a tool does not
check (line length in docs, import grouping, and so on).

**Code style, unwritten.** Read the code next to what you will change and
note how it names things, handles and reports errors, logs, orders imports,
writes docstrings and type hints, and lays out and names tests. New code
should read as if the same person wrote it.

**Other rules.** License or copyright headers on new files; generated files
that must not be edited by hand (`DO NOT EDIT` markers, `*_pb2.py`,
generated clients) and the command that regenerates them; vendored
directories; migration rules; dependency policy (pinned versions, lockfile
updates in the same PR, or a ban on new dependencies); a security policy.

## The file

```markdown
# Repo rules: <repo>
## Sources read          (every file read for this, with its path)
## Branch names           (pattern, 3 recent examples, proposed default for this task)
## Commits                (format, sign-off, 3 recent examples)
## PR                     (title format with examples, template path, body sections, labels, issue linking, changelog, draft or not)
## Code style             (tools and their configs; the unwritten conventions, with file references)
## Docs to update         (for this change)
## Agent rules            (from the AI docs, each with its path)
## Other
## Unclear or conflicting (these become phase 2 questions)
```

Keep it to rules that bear on this change. A rule about a part of the repo
you will not touch is noise.
