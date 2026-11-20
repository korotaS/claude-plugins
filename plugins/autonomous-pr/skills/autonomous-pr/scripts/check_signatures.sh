#!/usr/bin/env bash
# Check that every commit in <base>..HEAD is signed.
#
#   check_signatures.sh <base>            local check
#   check_signatures.sh <base> --github   also ask GitHub whether each commit is "Verified"
#                                         (only meaningful after the branch is pushed)
#
# Exit 0 if every commit passes, 1 otherwise. Prints one line per commit.
#
# Locally, %G? is G (good) or U (good, key validity unknown) for a valid
# signature. When git cannot verify (E: key missing, or N with gpg.format=ssh
# and no gpg.ssh.allowedSignersFile), the script falls back to checking that
# the commit object carries a signature, and says so. B (bad), R (revoked),
# X/Y (expired) fail. Only GitHub can say "Verified".
set -euo pipefail

base="${1:?usage: check_signatures.sh <base> [--github]}"
github="${2:-}"

commits=$(git rev-list --reverse "$base..HEAD")
if [ -z "$commits" ]; then
  echo "no commits in $base..HEAD"
  exit 0
fi

repo=""
if [ "$github" = "--github" ]; then
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

fail=0
for c in $commits; do
  short=$(git rev-parse --short "$c")
  status=$(git log -1 --format='%G?' "$c" 2>/dev/null)
  case "$status" in
    G|U) local_msg="signed, good ($status)" ;;
    N|E)
      if git cat-file commit "$c" | grep -q '^gpgsig'; then
        local_msg="signed, cannot verify locally (no allowed signers / key unknown)"
      else
        local_msg="UNSIGNED"; fail=1
      fi ;;
    *) local_msg="BAD SIGNATURE ($status)"; fail=1 ;;
  esac

  gh_msg=""
  if [ -n "$repo" ]; then
    v=$(gh api "repos/$repo/commits/$c" -q '.commit.verification | "\(.verified) \(.reason)"' 2>/dev/null || echo "unknown not-on-github")
    case "$v" in
      true*) gh_msg=" | github: verified" ;;
      *) gh_msg=" | github: NOT verified ($v)"; fail=1 ;;
    esac
  fi

  echo "$short $local_msg$gh_msg  $(git log -1 --format='%s' "$c")"
done

exit "$fail"
