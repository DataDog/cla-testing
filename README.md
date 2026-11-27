# cla-testing

Controlled test bench for validating the CLA Assistant GitHub Action used across
Datadog's CLA-gated repositories (datadog-agent, browser-sdk, vector).
Owned by the Datadog OSPO team.

This repository reproduces the production CLA setup at small scale: it carries
three CLA workflow variants mirroring the three production consumers, plus a
fleet of dummy workflows that grow the repository's workflow listing beyond a
single API page — the condition under which the legacy action's workflow-ID
lookup intermittently failed with "Unable to locate this workflow's ID in this
repository, can't trigger job."

Signatures are stored in DataDog/cla-signatures, branch `cla-testing`, files
`agent.json` / `browser-sdk.json` / `vector.json`, written via an Octo-STS
token (`self.write-signatures` policy) — the same credential path production uses.

Layout:

- `main` — the action currently under validation
- `baseline-old-action` — frozen copy of the legacy wiring, kept for re-runs
- `candidate-action` — the fork candidate (DataDog/contributor-assistant-github-action)

The `scripts/` directory carries the automation used to seed and drive the bench.
