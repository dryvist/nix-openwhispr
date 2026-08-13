#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

forbidden=$(printf '\\x73\\x63\\x72\\x65\\x65\\x6e\\x70\\x69\\x70\\x65')
if rg -n -i "$forbidden|private/dryvist|jacobpevans|\\.local\\.md|GH_PAT|DOPPLER" \
  --glob '!scripts/check-publication.sh' \
  --glob '!result/**' \
  .; then
  echo "forbidden private or secret-bearing publication content found" >&2
  exit 1
fi

test -f LICENSE
test -f README.md
test -f release.json
