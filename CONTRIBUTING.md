# Contributing Guidelines

- [Contributing Guidelines](#contributing-guidelines)
  - [Contributors Workflow](#contributors-workflow)
    - [Configure pre-commit](#configure-pre-commit)
    - [Creating a Feature Branch](#creating-a-feature-branch)
    - [Creating a Pull Request (PR)](#creating-a-pull-request-pr)
  - [Maintainers Workflow](#maintainers-workflow)
    - [Checking a Pull Request (PR)](#checking-a-pull-request-pr)
    - [Updating Self-Dependencies](#updating-self-dependencies)
    - [Creating a new release](#creating-a-new-release)
  - [Code Style](#code-style)
    - [General](#general)
    - [Typed Values](#typed-values)
    - [File Structure](#file-structure)
      - [Actions](#actions)
      - [Workflows](#workflows)
    - [Naming Conventions](#naming-conventions)
    - [Shell code](#shell-code)
    - [Action Security](#action-security)
    - [Tips \& Hacks](#tips--hacks)

Thank you for your interest in contributing to our project. The following is a set of guidelines for contributing to this project.

## Contributors Workflow

### Configure pre-commit

We use pre-commit to ensure code quality. We kindly ask you to use it before creating a pull request.

1. Install pre-commit using pip (if you haven't already):

    ```bash
    pip install pre-commit
    ```

1. Then install the git hook scripts:

    ```bash
    pre-commit install
    ```

Pre-commit will now run on every commit. If you want to run pre-commit checks manually, you can use:

```bash
pre-commit run
```

### Creating a Feature Branch

Before you start working, please create a new, "feature" branch from the repo's default one. This will ensure your ongoing work does not affect the main branch and makes it easier to merge your changes later.

To create a new branch:

```bash
git checkout -b your-new-branch
```

### Creating a Pull Request (PR)

Once ready, you can create a PR back from your feature branch to a repo's default branch.

We require pull request titles to follow the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/). Make sure to prefix the title with one of the following: `fix:`, `feat:`, `feature:`, `chore:`, `hotfix:`. Breaking change pull requests may include `!` after the type/scope, e.g. `<type>!: <description>`.

## Maintainers Workflow

### Checking a Pull Request (PR)

After a PR is created, it needs to be checked and reviewed before merging.

Review the changes in the PR and ensure they adhere to the code quality standards and are aligned with the project's objectives.

### Updating Self-Dependencies

Once PR checked, ensure the self-dependencies (occurrences of `uses: epam/ai-dial-ci`) in it are updated. We don't update self-dependencies automatically, e.g. with Dependabot, so it must be done in the PR manually. You may use `update-self-dependencies.sh` script for your convenience.

```console
$ ./update-self-dependencies.sh
Enter the next (predicted) version tag (e.g., 1.0.1): 1.9.3
Updated all occurrences of 'epam/ai-dial-ci/' with version '1.9.3'.
$
```

After updating self-dependencies, commit the changes and push them to the PR branch. Approve the PR and merge it.

### Creating a new release

Follow the steps below to create a new release on GitHub:

1. Navigate to your repository homepage.
1. Click on the "Releases" tab which is next to the "About" section on the right side of the page.
1. Click on "Draft a new release" button which is toward the right side of the screen.
1. Hit "Choose a tag" and enter a unique tag for the new version following [semver](https://semver.org/) rules. This tag must match the tag used in [Updating Self-Dependencies](#updating-self-dependencies) step. Hit "Create new tag".
1. Click "Generate Release Notes". GitHub will automatically include a changelog of all commit messages since last release.
1. Once all the details are finalized, click on the "Publish release" button.

## Code Style

### General

- Use 2-space indentation
- No trailing whitespace
- Files end with a single newline
- LF line endings
- Keep YAML keys unquoted; quote string values only when required by the YAML spec
- Separate all top-level sections with a single blank line; no blank lines between entries within a section
- All `description` & similar plain text fields: start with a capital letter, no trailing period

### Typed Values

- [GitHub Actions (`action.yml`) specification](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax) defines `inputs.<id>.default` as a plain string - always quote default values in `action.yml` (`default: "false"`, `default: "17"`)
- As opposite, [GitHub Workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax) inputs have an explicit `type:` field - use that for `default`: (`type: string` --> `default: "17"`, `type: number` --> `default: 17`, `type: string` --> `default: "Hello world"`)

### File Structure

#### Actions

- Top-level key order: `name` → `description` → `inputs` → `outputs` → `runs`
- Per-input key order: `description` → `required` → `default`; never combine `required: true` with `default`
- Per-output key order: `description` → `value`
- For composite actions, the `runs` defines as `using: "composite"`

#### Workflows

- Top-level key order: `name` → `on` → `permissions` (if needed) → `env` (if needed) → `jobs`
- Reusable workflow input key order: `type` → `description` → `required` → `default`

### Naming Conventions

Names must be consistent, even after case conversion. See the table below for examples

| Element                                   | Case             | Example                                                     |
| ----------------------------------------- | ---------------- | ----------------------------------------------------------- |
| Workflow file name [^1] / action dir name | snake_case       | `generic_docker_test.yml`, `semantic_versioning/action.yml` |
| Workflow /action `name`                   | Title Case       | `Generic Docker Test`, `Semantic Versioning`                |
| Input / output ID                         | kebab-case       | `style-checks-enabled`, `next-version-without-hyphens`      |
| Job ID                                    | snake_case       | `style_checks`                                              |
| Step `name`                               | Sentence case    | `Run style checks`, `Calculate version`                     |
| Step `id`                                 | kebab-case       | `run-style-checks`, `calculate-version`                     |
| `env` variable name                       | UPPER_SNAKE_CASE | `IMAGE_NAME`, `CURRENT_BRANCH`                              |

[^1]: Exception. For workflows used as [slash commands](https://github.com/peter-evans/slash-command-dispatch/), file name must be `<command-name>-command.yml`, where `command-name` also equals `repository_dispatch.type`. E.g. `deploy-review-command.yml` for `/deploy-review` slash command

### Shell code

- Use YAML multiline string syntax (`|`) for `run` blocks to improve readability
- Use shebangs for shell scripts, e.g. `#!/bin/bash`, `#!/bin/sh`, if any of the following applies:
  - the script uses non-POSIX features, e.g. Bash arrays, `[[` conditional expressions, etc.
  - the script is more than 10 lines long
- Use `snake_case` for variable names
- Quote variable expansions to prevent word splitting and globbing, e.g. `"${variable}"`, `"$variable"`, unless explicitly intended
- Linting shell code with [ShellCheck](https://github.com/koalaman/shellcheck/) is highly recommended
- Specify `shell: <name>` parameter, e.g. `shell: bash`, `shell: pwsh` after `run` parameter if any of the following applies:
  - the script needs a non-default shell (not `bash` with fallback to `sh` on Linux/macOS and not `pwsh` on Windows)
  - the script contains a shebang
  - it's a composite action

### Action Security

- Pin external third-party actions to a full commit SHA with the version tag as a comment: `uses: actions/checkout@abc123... # v6.0.2`. Exception: self-references (to `epam/ai-dial-ci`) should use tag
- Pass action inputs via the `env:` block; do not reference `${{ inputs.* }}` inside the script body

### Tips & Hacks

- Composite action inputs are always strings - use `fromJSON(inputs.my-bool-input)` to coerce a string boolean to an actual boolean in `if:` conditions or boolean `with:` parameters
