# AI DIAL workflows

## Overview

Continuous Integration instrumentation for [AI DIAL](https://epam-rail.com) components.

Contains reusable workflows for AI-DIAL group of repositories under EPAM GitHub organization.

## Usage

These workflows could be imported to any repository under EPAM GitHub organization as standard `.github/workflows` files. See examples below (replace `@main` with specific version tag).

### PR tests (NodeJS docker)

```yml
name: Code checks - tests

on:
  pull_request:
    branches: [ development, release-* ]

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/test_yarn_docker.yml@main
    secrets: inherit
    with:
      bypass_ort: false
```

### Release (Python package)

```yml
name: Release version

on:
  push:
    branches: [ development, release-* ]

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/publish_python_package.yml@main
    secrets: inherit
    with:
      bypass_checks: false
      python_version: 3.8
```

### Release (Python docker)

```yml
name: Release version

on:
  push:
    branches: [ development, release-* ]

env:
  IMAGE_NAME: ${{ github.repository }}

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/publish_python_docker.yml@main
    secrets: inherit
```

### Validate PR title

```yml
name: "Validate PR title"

on:
  pull_request_target:
    types:
      - opened
      - edited
      - synchronize

jobs:
  pr-title-check:
    uses: epam/ai-dial-ci/.github/workflows/pr-title-check.yml@main
    secrets:
      ACTIONS_BOT_TOKEN: ${{ secrets.ACTIONS_BOT_TOKEN }}
```

## Deploy review environment

```yml
name: Slash Command Dispatch
on:
  issue_comment:
    types: [created]
jobs:
  slashCommandDispatch:
    runs-on: ubuntu-latest
    steps:
      - name: Slash Command Dispatch
        id: scd
        uses: peter-evans/slash-command-dispatch@a28ee6cd74d5200f99e247ebc7b365c03ae0ef3c # v3.0.1
        with:
          token: ${{ secrets.ACTIONS_BOT_TOKEN }}
          reaction-token: ${{ secrets.ACTIONS_BOT_TOKEN }}
          config: >
            [
              {
                "command": "deploy-review",
                "permission": "write",
                "issue_type": "pull-request",
                "repository": "epam/ai-dial-ci",
                "static_args": [
                  "application=${{ github.event.repository.name }}"
                ]
              }
            ]
```

## Developer environment

This project contains reusable workflows under [`.github/workflows`](.github/workflows) directory, and composite actions under [`actions`](actions) directory.

pre-commit hook configured by [`.pre-commit-config.yaml`](.pre-commit-config.yaml) file forces yaml "code style".

To install and configure pre-commit hook run:

```bash
pip install pre-commit
pre-commit install
```

This will install and configure git pre-commit hook initiated automatically on `git commit` command and auto-fixing code style.
