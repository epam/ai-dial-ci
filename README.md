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
    - [Trigger deployment of development environment in GitLab](#trigger-deployment-of-development-environment-in-gitlab)
    - [Trivy additional configuration](#trivy-additional-configuration)
  - [Contributing](#contributing)

## Overview

Continuous Integration instrumentation for [AI DIAL](https://epam-rail.com) components.

Contains reusable workflows for AI-DIAL group of repositories under EPAM GitHub organization.

## Usage

These workflows could be imported to any repository under EPAM GitHub organization as standard `.github/workflows` files. See examples below (replace `@main` with specific version tag).

### PR Workflow (NodeJS (npm), Docker)

`pr.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### Release Workflow (NodeJS (npm), Docker)

`release.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### PR Workflow (Java (gradle), Docker)

`pr.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### Release Workflow (Java (gradle), Docker)

`release.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### PR Workflow (Python (poetry), Docker)

`pr.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### Release Workflow (Python (poetry), Docker)

`release.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### PR Workflow (Python (poetry), package)

`pr.yml`

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

`release.yml`

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

`pr.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### Release Workflow (Generic, Docker)

`release.yml`

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
    # with:
    #   platforms: "linux/amd64,linux/arm64"
```

### Validate PR title

`pr-title-check.yml`

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

`slash-command-dispatch.yml`

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

If you need to disable E2E tests execution:

- for the **whole repository**: add `skip-e2e` argument to `static_args` list
  ```yml
                "static_args": [
                  "application=${{ github.event.repository.name }}",
                  "skip-e2e"
                ]
  ```
- for the **specific PR**: assign `skip-e2e` label to PR
- **once**: use `/deploy-review skip-e2e` command in PR comment

### Cleanup for untagged images in GHCR

`cleanup-untagged-images.yml`

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

`dependency-review.yml`

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

### Trigger deployment of development environment in GitLab

A common case is to trigger development environment(s) update from GitHub to GitLab, e.g. each time a `development` branch produces a new artifact. Also, it could be not single, but several environments, representing different configuration presets of a single app. To use the example below:

1. add a new [repository secret](https://docs.github.com/en/actions/security-guides/encrypted-secrets) with name `DEPLOY_HOST` and value of the gitlab host, e.g. `gitlab.example.com`
1. create a new [environment](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment#creating-an-environment), e.g. `development`
1. for the environment, add [environment secrets](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment#environment-secrets) with names `DEPLOY_ACCESS_TOKEN` and `DEPLOY_TRIGGER_TOKEN` and values of the gitlab access token and trigger token respectively.
1. use the example workflow file below

`deploy-development.yml`

```yml
name: Deploy development

on:
  workflow_dispatch:
  registry_package:

jobs:
  gitlab-dev-deploy:
    if: |
      github.event_name == 'workflow_dispatch' ||
      github.event.registry_package.package_version.container_metadata.tag.name == 'development'
    uses: epam/ai-dial-ci/.github/workflows/deploy-development.yml@main
    with:
      gitlab-project-id: "1487"
    secrets:
      DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
      DEPLOY_ACCESS_TOKEN: ${{ secrets.DEPLOY_ACCESS_TOKEN }}
      DEPLOY_TRIGGER_TOKEN: ${{ secrets.DEPLOY_TRIGGER_TOKEN }}
```

In case of multiple environments, continue creating multiple GitHub environments named after e.g. feature sets, each with its own secrets, then use matrix approach as shown below.

`deploy-development.yml`

```yml
name: Deploy development

on:
  workflow_dispatch:
  registry_package:

jobs:
  trigger:
    if: |
      github.event_name == 'workflow_dispatch' ||
      github.event.registry_package.package_version.container_metadata.tag.name == 'development'
    strategy:
      fail-fast: false
      matrix:
        include:
          - environment-name: "development"
            gitlab-project-id: "1487"
          - environment-name: "feature-1"
            gitlab-project-id: "1489"
          - environment-name: "feature-2"
            gitlab-project-id: "1984"
          - environment-name: "feature-3"
            gitlab-project-id: "1337"

    name: Deploy to ${{ matrix.environment-name }}
    uses: epam/ai-dial-ci/.github/workflows/deploy-development.yml@main
    with:
      gitlab-project-id: ${{ matrix.gitlab-project-id }}
      environment-name: ${{ matrix.environment-name }}
    secrets:
      DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
      DEPLOY_ACCESS_TOKEN: ${{ secrets.DEPLOY_ACCESS_TOKEN }}
      DEPLOY_TRIGGER_TOKEN: ${{ secrets.DEPLOY_TRIGGER_TOKEN }}
```

### Trivy additional configuration

To change predefined Trivy parameters or set up additional configuration options, create `trivy.yaml` file in root of your repository. Use example below to add fallback repositories for vulnerabilities and checks DB and thus mitigate rate limit issues.

`trivy.yaml`

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
