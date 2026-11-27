#!/usr/bin/env bash
# Regenerates the dummy workflow fleet under .github/workflows/.
# The fleet exists solely to grow the repository's workflow listing beyond a
# single API results page, reproducing the pagination condition that made the
# legacy CLA action's workflow-ID lookup intermittently miss this workflow.
# The dummy workflows are never run (workflow_dispatch only).
set -euo pipefail

COUNT="${1:-75}"

for i in $(seq -f '%02g' 1 "$COUNT"); do
  cat > ".github/workflows/dummy-${i}.yml" <<EOF
name: "Dummy workflow ${i}"
on:
  workflow_dispatch:
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo "no-op placeholder to grow the workflow listing past one API page"
EOF
done

echo "generated ${COUNT} dummy workflows in .github/workflows/"
