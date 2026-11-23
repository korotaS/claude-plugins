# Reviewer brief template

Fill the `<...>` parts and send the result as the subagent's prompt, with
`model: "opus"` and `effort: "high"`. Do not add your own opinion of the code:
a reviewer handed your conclusion tends to return it confirmed.

---

You are reviewing a change before it becomes a pull request. You did not
write it. Your job is to find what is wrong with it. Do not edit any file and
do not run git commands that change state (no commit, checkout, stash, reset,
push). Reading files, `git diff`, `git log`, `git show`, and running tests or
linters are fine.

**Repository:** `<absolute path>`
**The change:** `git diff <base-sha>...HEAD` (branch `<branch>`)
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

Look for, in this order:

1. **Correctness.** Logic errors, wrong edge cases (empty, None, zero,
   negative, unicode, very large, concurrent), broken error paths, behaviour
   that differs from the plan, regressions in callers of changed code (grep
   for them).
2. **Tests.** Does each new test fail without the change? Does it test the
   behaviour or merely the implementation? Are there plan items with no test?
   Anything skipped, xfailed or loosened to get green?
3. **CI parity.** Will this pass the CI jobs in the recipe: lint, types,
   compiled builds (Cython: `.pyx`/`.pxd` changes rebuilt, declarations in
   sync), other Python or OS versions in the matrix?
4. **Security and data.** Injection, secrets, unsafe deserialisation,
   permissions, migrations that lose data.
5. **Repo rules.** Anything that breaks `repo-rules.md`: written style and
   code-style rules, naming and patterns that differ from the surrounding
   code, rules from the AI-agent docs, docs that describe the changed
   behaviour but were not updated, commit messages off the convention.
6. **Scope and simplicity.** Lines that do not trace to the request,
   speculative abstraction or configurability, refactors of adjacent code,
   orphans this change left behind.

Report each finding as:

```
[blocker|important|nit] <file>:<line>: <what is wrong>
Failure scenario: <concrete input or state → wrong result or crash>
Fix: <the smallest fix>
```

`blocker`: wrong behaviour, data loss, security hole, or CI will fail.
`important`: a real bug in a less likely path, a missing test for planned
behaviour, a clear rules violation. `nit`: everything else. Only report what
you checked in the code. If you are unsure, say so and say what would settle
it. If you find nothing at blocker or important, say exactly that. An empty
review is a valid result, and inventing findings to fill one wastes a round.
