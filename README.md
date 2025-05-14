# AI DIAL workflows

- [AI DIAL workflows](#ai-dial-workflows)
  - [Overview](#overview)
  - [Usage](#usage)
    - [PR Workflow (NodeJS (npm), Docker)](#pr-workflow-nodejs-npm-docker)
    - [Release Workflow (NodeJS (npm), Docker)](#release-workflow-nodejs-npm-docker)
    - [PR Workflow (Java (gradle), Docker)](#pr-workflow-java-gradle-docker)
    - [Release Workflow (Java (gradle), Docker)](#release-workflow-java-gradle-docker)
    - [PR Workflow (Python (poetry), Docker)](#pr-workflow-python-poetry-docker)
    - [Release Workflow (Python (poetry), Docker)](#release-workflow-python-poetry-docker)
    - [PR Workflow (Python (poetry), package)](#pr-workflow-python-poetry-package)
    - [Release Workflow (Python (poetry), package)](#release-workflow-python-poetry-package)
    - [PR Workflow (Generic, Docker)](#pr-workflow-generic-docker)
    - [Release Workflow (Generic, Docker)](#release-workflow-generic-docker)
    - [Validate PR title](#validate-pr-title)
    - [Deploy review environment](#deploy-review-environment)
    - [Cleanup for untagged images in GHCR](#cleanup-for-untagged-images-in-ghcr)
    - [Dependency Review (Java (gradle))](#dependency-review-java-gradle)
    - [Trivy additional configuration](#trivy-additional-configuration)
  - [Contributing](#contributing)

## Overview

Continuous Integration instrumentation for [AI DIAL](https://epam-rail.com) components.

Contains reusable workflows for AI-DIAL group of repositories under EPAM GitHub organization.

## Usage

These workflows could be imported to any repository under EPAM GitHub organization as standard `.github/workflows` files. See examples below (replace `@main` with specific version tag).

### PR Workflow (NodeJS (npm), Docker)

```yml
name: PR Workflow

on:
  pull_request:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/node_pr.yml@main
    secrets: inherit
```

### Release Workflow (NodeJS (npm), Docker)

```yml
name: Release Workflow

on:
  push:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/node_release.yml@main
    secrets: inherit
```

### PR Workflow (Java (gradle), Docker)

```yml
name: PR Workflow

on:
  pull_request:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/java_pr.yml@main
    secrets: inherit
```

### Release Workflow (Java (gradle), Docker)

```yml
name: Release Workflow

on:
  push:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/java_release.yml@main
    secrets: inherit
```

### PR Workflow (Python (poetry), Docker)

```yml
name: PR Workflow

on:
  pull_request:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/python_docker_pr.yml@main
    secrets: inherit
```

### Release Workflow (Python (poetry), Docker)

```yml
name: Release Workflow

on:
  push:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/python_docker_release.yml@main
    secrets: inherit
```

### PR Workflow (Python (poetry), package)

```yml
name: PR Workflow

on:
  pull_request:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/python_package_pr.yml@main
    secrets: inherit
```

### Release Workflow (Python (poetry), package)

```yml
name: Release Workflow

on:
  push:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/python_package_release.yml@main
    secrets: inherit
```

### PR Workflow (Generic, Docker)

```yml
name: PR Workflow

on:
  pull_request:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  run_tests:
    uses: epam/ai-dial-ci/.github/workflows/generic_docker_pr.yml@main
    secrets: inherit
```

### Release Workflow (Generic, Docker)

```yml
name: Release Workflow

on:
  push:
    branches: [development, release-*]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    uses: epam/ai-dial-ci/.github/workflows/generic_docker_release.yml@main
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
      - reopened

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  pr-title-check:
    uses: epam/ai-dial-ci/.github/workflows/pr-title-check.yml@main
    secrets:
      ACTIONS_BOT_TOKEN: ${{ secrets.ACTIONS_BOT_TOKEN }}
```

### Deploy review environment

```yml
name: Slash Command Dispatch
on:
  issue_comment:
    types: [created]
jobs:
  slashCommandDispatch:
    runs-on: ubuntu-latest
    if: ${{ github.event.issue.pull_request }}
    steps:
      - name: Slash Command Dispatch
        id: scd
        uses: peter-evans/slash-command-dispatch@13bc09769d122a64f75aa5037256f6f2d78be8c4 # v4.0.0
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

### Cleanup for untagged images in GHCR

```yml
name: Cleanup untagged images

on:
  schedule:
    - cron: "0 0 * * *"

jobs:
  clean:
    name: Delete untagged images
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: dataaxiom/ghcr-cleanup-action@cd0cdb900b5dbf3a6f2cc869f0dbb0b8211f50c4 # v1.0.16
        with:
          delete-untagged: true
```

### Dependency Review (Java (gradle))

To support Dependabot security updates, GitHub requires uploading dependency graph data to GitHub's Dependency Graph API. To enable this feature, add the workflow from example below to your repository. You'll start getting review comments on PRs.

```yml
name: Dependency Review

on:
  pull_request_target:
    types:
      - opened
      - synchronize

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  dependency-review:
    uses: epam/ai-dial-ci/.github/workflows/java_dependency_review.yml@main
    secrets:
      ACTIONS_BOT_TOKEN: ${{ secrets.ACTIONS_BOT_TOKEN }}
```

### Trivy additional configuration

To change predefined Trivy parameters or set up additional configuration options, create `trivy.yaml` file in root of your repository. Use example below to add fallback repositories for vulnerabilities and checks DB and thus mitigate rate limit issues.

```yaml
# Trivy configuration file
# https://aquasecurity.github.io/trivy/latest/docs/references/configuration/config-file/
db:
  no-progress: true
  repository:
    - mirror.gcr.io/aquasec/trivy-db:2
    - public.ecr.aws/aquasecurity/trivy-db:2
    - ghcr.io/aquasecurity/trivy-db:2
  java-repository:
    - mirror.gcr.io/aquasec/trivy-java-db:1
    - public.ecr.aws/aquasecurity/trivy-java-db:1
    - ghcr.io/aquasecurity/trivy-java-db:1
misconfiguration:
  checks-bundle-repository: mirror.gcr.io/aquasec/trivy-checks:1
```

## Contributing

This project contains reusable workflows under [`.github/workflows`](.github/workflows) directory, and composite actions under [`actions`](actions) directory.

Check [contribution guidelines](CONTRIBUTING.md) for details.
