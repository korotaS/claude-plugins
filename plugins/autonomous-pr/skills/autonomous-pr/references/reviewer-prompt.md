# Reviewer briefs

Each review round has two reviewers: a **code reviewer** that runs the
`code-review` skill and a **security reviewer** that runs the
`security-review` skill. Spawn both in the same message, so they run in
parallel and neither sees the other's findings, each with
`subagent_type: "general-purpose"` (it needs the Skill tool),
`model: "opus"` and `effort: "high"`.

Build each prompt from the shared part plus that reviewer's part, fill the
`<...>` slots, and add nothing else. In particular, give no opinion of the
code: a reviewer handed your conclusion tends to return it confirmed.

---

## Shared part (both reviewers)

You are reviewing a change before it becomes a pull request. You did not
write it. Your job is to find what is wrong with it. Do not edit any file and
do not run git commands that change state (no commit, checkout, stash, reset,
push). Reading files, `git diff`, `git log`, `git show`, and running tests or
linters are fine. Do not post anything anywhere: no PR comments, no issues.

**Repository:** `<absolute path>`, checked out on branch `<branch>`
**The change:** `git diff <base-sha>...HEAD` (base `<base>`)
**What it is meant to do:** read `<RUN>/plan.md`. The plan was approved by
the user; review the code against it, not the plan itself, unless the plan
contains a real flaw.
**Project rules:** `<RUN>/repo-rules.md` (the repo's docs, AI-agent docs,
style and code-style rules, commit and PR conventions, each with its source;
open the sources when a rule matters) and
`<skill dir>/references/karpathy-guidelines.md`.
**CI recipe:** `<RUN>/ci-recipe.md`.

<Round 2 and later only:>
**Already considered and declined** (raise again only with new evidence):
<finding, reason declined>

**Your final reply is the only thing the session that started you reads.**
If the skill reports its findings through a tool or a UI instead of text,
repeat every finding in your final reply anyway, in this format:

```
[blocker|important|nit] <file>:<line>: <what is wrong>
Failure scenario: <concrete input or state → wrong result, crash or exploit>
Fix: <the smallest fix>
Source: <skill | checklist>
```

`blocker`: wrong behaviour, data loss, an exploitable security hole, or CI
will fail. `important`: a real bug or vulnerability in a less likely path, a
missing test for planned behaviour, a clear rules violation. `nit`:
everything else. Only report what you checked in the code. If you are
unsure, say so and say what would settle it. If you find nothing at blocker
or important, say exactly that. An empty review is a valid result, and
inventing findings to fill one wastes a round.

If the skill you are told to run is not available, say so in the first line
of your reply and do the review from the checklist alone.

## Code reviewer

1. Run the `code-review` skill through the Skill tool with the arguments
   `high <branch>`. Do not pass `--fix`, `--comment` or `--post`, and do
   not use the `max` or `ultra` level: you review, and the session that
   started you decides what to change.
2. Then check what the skill does not know about, in this order:
   1. **The plan.** Behaviour that differs from `plan.md`; plan items with
      no code.
   2. **Tests.** Does each new test fail without the change? Does it test
      the behaviour or merely the implementation? Are there plan items with
      no test? Anything skipped, xfailed or loosened to get green?
   3. **CI parity.** Will this pass the CI jobs in the recipe: lint, types,
      compiled builds (Cython: `.pyx`/`.pxd` changes rebuilt, declarations
      in sync), other Python or OS versions in the matrix?
   4. **Repo rules.** Anything that breaks `repo-rules.md`: written style and
      code-style rules, naming and patterns that differ from the surrounding
      code, rules from the AI-agent docs, docs that describe the changed
      behaviour but were not updated, commit messages off the convention.
   5. **Scope and simplicity.** Lines that do not trace to the request,
      speculative abstraction or configurability, refactors of adjacent
      code, orphans this change left behind.

Leave security to the security reviewer, unless the skill itself reports it.

## Security reviewer

1. Run the `security-review` skill through the Skill tool. It reviews the
   pending changes on the current branch, which is `<branch>`.
2. Then check the diff for what a code-focused review tends to miss:
   - secrets, tokens, keys or credentials added anywhere, including tests,
     fixtures, docs and CI files;
   - new or upgraded dependencies: known vulnerabilities, unpinned versions,
     names that look like a typo of a popular package;
   - changes to CI, Dockerfiles and compose files: secrets in env or build
     args, `privileged` containers, new network exposure, `curl | sh`;
   - injection (SQL, shell, template, path), unsafe deserialisation, SSRF,
     missing authorisation checks, sensitive data in logs or error messages,
     weak or hand-rolled crypto.

Map the skill's severities to the format above: high to `blocker`, medium to
`important`, low to `nit`.
