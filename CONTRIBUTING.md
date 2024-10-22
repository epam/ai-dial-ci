# Contributing Guidelines

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
