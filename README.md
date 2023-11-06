# AI DIAL workflows

## Overview

Continuous Integration instrumentation for [AI DIAL](https://epam-rail.com) components.

Contains reusable workflows for AI-DIAL group of repositories under EPAM GitHub organization.

## Usage

These workflows could be imported to any repository under EPAM GitHub organization as standard `.github/workflows` files.

```yml
name: Release version

on:
  push:
    branches: [ development, release-* ]

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/publish_python_package.yml@1.0.1
    secrets: inherit
    with:
      bypass_checks: false
      python_version: 3.8
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
