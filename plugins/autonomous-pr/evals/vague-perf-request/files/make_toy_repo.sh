#!/usr/bin/env bash
# Builds the statkit toy repo used by the autonomous-pr test cases.
# Usage: make_toy_repo.sh <target-dir>   (creates <target-dir>/statkit and <target-dir>/origin.git)
set -euo pipefail
T="$(cd "${1:?target dir}" && pwd)"
R="$T/statkit"; mkdir -p "$R" && cd "$R"
git init -q -b main
git config user.name "Toy Dev"; git config user.email "toy@example.invalid"; git config commit.gpgsign false
mkdir -p statkit tests/integration .github/workflows
cat > pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools>=68", "Cython>=3.0"]
build-backend = "setuptools.build_meta"

[project]
name = "statkit"
version = "0.3.0"
requires-python = ">=3.10"
dependencies = ["psycopg[binary]>=3.1"]

[project.scripts]
statkit = "statkit.cli:main"

[project.optional-dependencies]
dev = ["pytest>=8", "ruff>=0.6"]

[tool.pytest.ini_options]
markers = ["integration: needs a postgres at STATKIT_DSN"]

[tool.ruff]
line-length = 100
EOF
cat > setup.py <<'EOF'
from Cython.Build import cythonize
from setuptools import setup

setup(ext_modules=cythonize(["statkit/_fast.pyx"], language_level=3))
EOF
cat > statkit/__init__.py <<'EOF'
from statkit.core import mean, median
from statkit._fast import moving_average

__all__ = ["mean", "median", "moving_average"]
EOF
cat > statkit/core.py <<'EOF'
def mean(values):
    return sum(values) / len(values)


def median(values):
    s = sorted(values)
    n = len(s)
    mid = n // 2
    return s[mid] if n % 2 else (s[mid - 1] + s[mid]) / 2
EOF
cat > statkit/_fast.pyx <<'EOF'
def moving_average(values, int window):
    cdef int i, j
    out = []
    for i in range(len(values) - window + 1):
        total = 0.0
        for j in range(i, i + window):
            total += values[j]
        out.append(total / window)
    return out
EOF
cat > statkit/cli.py <<'EOF'
import argparse

from statkit import mean, median


def main(argv=None):
    p = argparse.ArgumentParser(prog="statkit")
    p.add_argument("values", nargs="+", type=float)
    a = p.parse_args(argv)
    print(f"mean   {mean(a.values):.4f}")
    print(f"median {median(a.values):.4f}")


if __name__ == "__main__":
    main()
EOF
cat > statkit/db.py <<'EOF'
import psycopg


def save_summary(dsn, name, values):
    from statkit import mean, median

    with psycopg.connect(dsn) as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS summaries (name text primary key, mean float8, median float8)"
        )
        conn.execute(
            "INSERT INTO summaries VALUES (%s, %s, %s) ON CONFLICT (name) DO UPDATE "
            "SET mean = EXCLUDED.mean, median = EXCLUDED.median",
            (name, mean(values), median(values)),
        )
EOF
cat > tests/test_core.py <<'EOF'
from statkit import mean, median, moving_average


def test_mean():
    assert mean([1, 2, 3]) == 2


def test_median_even():
    assert median([4, 1, 3, 2]) == 2.5


def test_moving_average():
    assert moving_average([1, 2, 3, 4], 2) == [1.5, 2.5, 3.5]
EOF
cat > tests/integration/test_db.py <<'EOF'
import os

import psycopg
import pytest

from statkit.db import save_summary

pytestmark = pytest.mark.integration


def test_save_summary():
    dsn = os.environ["STATKIT_DSN"]
    save_summary(dsn, "t1", [1, 2, 3])
    with psycopg.connect(dsn) as conn:
        assert conn.execute("SELECT mean FROM summaries WHERE name='t1'").fetchone()[0] == 2
EOF
cat > .github/workflows/ci.yml <<'EOF'
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install ruff==0.6.9
      - run: ruff check .
      - run: ruff format --check .
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python: ["3.10", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "${{ matrix.python }}"}
      - run: pip install ".[dev]"
      - run: cd /tmp && python -m pytest "$GITHUB_WORKSPACE/tests" -m "not integration"
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: {POSTGRES_PASSWORD: statkit, POSTGRES_DB: statkit}
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 5s --health-retries 10
    env:
      STATKIT_DSN: postgresql://postgres:statkit@localhost:5432/statkit
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install ".[dev]"
      - run: cd /tmp && python -m pytest "$GITHUB_WORKSPACE/tests" -m integration
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker compose run --rm app
EOF
cat > Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /src
COPY . .
RUN pip install --no-cache-dir ".[dev]"
WORKDIR /
CMD ["python", "-m", "pytest", "/src/tests"]
EOF
cat > docker-compose.yml <<'EOF'
services:
  db:
    image: postgres:16
    environment: {POSTGRES_PASSWORD: statkit, POSTGRES_DB: statkit}
    healthcheck: {test: ["CMD", "pg_isready"], interval: 5s, retries: 10}
  app:
    build: .
    environment:
      STATKIT_DSN: postgresql://postgres:statkit@db:5432/statkit
    depends_on: {db: {condition: service_healthy}}
EOF
cat > AGENTS.md <<'EOF'
# statkit

- Public functions keep their signatures; statkit is used by the reporting dashboard.
- The Cython module is the fast path; there is no pure-Python fallback. Tests run from outside
  the source tree (see CI) so they exercise the installed, compiled package.
- Commit messages: `<type>(<area>): <summary>` (feat, fix, perf, chore, test).
EOF
printf 'build/\n*.so\nstatkit/_fast.c\n__pycache__/\n*.egg-info/\n' > .gitignore
printf '# statkit\n\nSmall stats helpers. `pip install .` builds the Cython extension.\n' > README.md
git add -A && git commit -qm "feat(core): mean, median and moving average"
git switch -qc feat/cli && git commit -q --allow-empty -m "feat(cli): statkit command" && git switch -q main && git merge -q --no-ff feat/cli -m "Merge branch 'feat/cli'"
git switch -qc fix/median-even && git commit -q --allow-empty -m "fix(core): median of even-length input" && git switch -q main && git merge -q --no-ff fix/median-even -m "Merge branch 'fix/median-even'"
git switch -qc feat/db && git commit -q --allow-empty -m "feat(db): save summaries to postgres" && git switch -q main && git merge -q --no-ff feat/db -m "Merge branch 'feat/db'"
git init -q --bare "$T/origin.git"
git remote add origin "$T/origin.git"
git push -q origin main feat/cli fix/median-even feat/db
git remote set-head origin main
git branch -q -D feat/cli fix/median-even feat/db
echo "toy repo at $R"
