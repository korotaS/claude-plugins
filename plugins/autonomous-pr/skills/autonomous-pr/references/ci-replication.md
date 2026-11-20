# Replicating CI locally

The goal: when CI runs on the PR, nothing it does should be new to this
branch. Read the CI config as the source of truth. Makefiles and READMEs
drift; the CI config is what actually gates the merge.

## Where CI lives

| system | files |
| --- | --- |
| GitHub Actions | `.github/workflows/*.yml`, plus local actions in `.github/actions/*/action.yml` |
| GitLab | `.gitlab-ci.yml` and its `include:`s |
| CircleCI | `.circleci/config.yml` |
| Jenkins | `Jenkinsfile` |
| Azure | `azure-pipelines.yml` |
| Buildkite | `.buildkite/pipeline.yml` |
| Others | `tox.ini`, `noxfile.py`, `.pre-commit-config.yaml`, `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts: often what the CI steps call |

For each job that runs on pull requests (check the `on:` / `rules:` /
`workflow:` triggers; a job that only runs on tags or on main does not gate
the PR, but note it), record:

- the runner image or container, and the language versions (the matrix),
- setup steps: installs, caches, env vars, secrets it needs,
- the commands, in order,
- `services:` containers (databases, brokers) with image, env and ports.

A step that needs a secret you do not have is "cannot verify here"; list it.

## Where a laptop differs from CI

- **Versions.** Use the version CI uses (`pyenv`, `uv python`, `nvm`,
  `.python-version`, `.nvmrc`, `.tool-versions`). With a matrix, run at least
  the oldest and the newest version if both are installable; otherwise say
  which you ran.
- **Fresh environment.** CI installs from scratch. A long-lived local venv
  hides missing dependencies. Create a new venv (or `uv run --isolated`,
  `npm ci`, `poetry install --sync`) for the final pass.
- **Lockfiles.** CI uses the lock file. So should you: `uv sync --frozen`,
  `npm ci`, `poetry install`, `pip install -r requirements*.txt`.
- **Check mode.** CI runs formatters in check mode (`ruff format --check`,
  `black --check`, `prettier --check`). Running them in fix mode locally
  passes while CI fails if you forget to commit the result.
- **pre-commit.** If CI runs `pre-commit run --all-files`, run exactly that,
  not only on changed files.
- **Env vars.** Copy the non-secret `env:` of the job (`CI=true`, locale,
  timezone, feature flags). Tests sometimes branch on `CI`.

## Cython and other compiled extensions

Signs that a project has them: `*.pyx` / `*.pxd` files, `cythonize(` or
`ext_modules` in `setup.py`, `[tool.cython]`, a `build-system` that requires
`Cython`, `meson-python`, `scikit-build-core`, `setuptools-rust`/`maturin`,
`pybind11`, `cibuildwheel` in CI.

1. **Build the way CI builds.** If CI runs `pip install .` or builds a wheel
   (`python -m build`, `cibuildwheel`), do that, in a fresh venv, and test the
   installed package, not the source tree. If CI builds in place
   (`python setup.py build_ext --inplace`, `pip install -e . --no-build-isolation`),
   do that. Use the same build isolation setting as CI, because it decides
   which Cython version compiles the code.
2. **Delete stale builds first.** Old `.so` / `.c` files from an earlier
   build can mask a broken `.pyx`: `git clean -ndX` lists ignored build
   products; remove only build products (`build/`, `*.so`, generated `.c` /
   `.cpp` next to `.pyx`), never untracked source files.
3. **Prove the compiled module is what ran.** In the test environment:
   ```bash
   python -c "import pkg.mod as m; print(m.__file__)"   # must end in .so / .pyd
   ```
   If the package has a pure-Python fallback, make sure the tests did not
   silently use it.
4. **Warnings.** If CI compiles with `-Werror` or Cython's
   `warn.*`/`language_level` directives, keep them.
5. **Annotation.** For performance changes, `cython -a` shows remaining
   Python interaction; it helps the review but is not a test.

## Docker

- Prefer the repo's own compose file. Give it a unique project name
  (`docker compose -p ap-<slug> ...`) so you do not collide with or tear down
  anyone else's stack, and `down -v` that project only when done.
- For CI `services:` with no compose file, start the same images with the
  same env: `docker run -d --rm --name ap-<slug>-postgres --label autonomous-pr=<slug> -e ... -p ... postgres:16`.
  Wait for readiness (healthcheck, `pg_isready`, a retry loop), not a fixed sleep.
- Pick free host ports instead of assuming 5432 or 6379 are free.
- Build images with the same build args and target stage as CI.
- Run the tests inside the image when the image is what ships; run them
  from the host against the containers when that is what CI does.
- Testcontainers-based suites start their own containers; they need only a
  working Docker socket.
