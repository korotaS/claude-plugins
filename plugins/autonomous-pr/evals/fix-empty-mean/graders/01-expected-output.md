---
type: llm
focus: trace
weight: 1
---

The result matches this description: Asks how an empty input should behave instead of choosing silently, asks for the branch name and task slug with defaults in the repo's fix/ style, edits nothing, and writes a plan whose tests start with a failing reproduction and whose local checks mirror CI: ruff check and ruff format --check, the Cython build through pip install, both Python 3.10 and 3.12, tests run from outside the source tree, and the postgres integration job.
