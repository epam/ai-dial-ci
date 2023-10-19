# Contributing Guidelines

Thank you for your interest in contributing to our project. The following is a set of guidelines for contributing to this project.

## Workflow

### 1. Installing pre-commit

We use pre-commit to ensure code quality. Please install it following the steps below:

Install pre-commit package globally:

```bash
pip install pre-commit
```

Then install the git hook scripts, run:

```bash
pre-commit install
```

Pre-commit will now run on every commit. If you want to run pre-commit manually, you can use:

```bash
pre-commit run
```

### 2. Creating a Feature Branch

Before you start working, please create a new feature branch. This will ensure your ongoing work does not affect the main branch and makes it easier to merge your changes later.

To create a new branch:

```bash
git checkout -b your-new-branch
```

**While doing changes, make sure to update self-dependencies in actions versions.**

### 3. Creating a Pull Request (PR)

Once ready, you can create a PR. Make sure to prefix the title with one of the following: "fix: ", "feat: ", "feature: ", "chore: ", "hotfix: "

This helps maintainers to categorize the PR and understand its purpose easier.

### For Maintainers

After a PR is created, it needs to be checked and reviewed before merging.

#### 1. Checking, Approving, and Merging with squash

Review the changes in the PR and ensure they adhere to the code quality standards and are aligned with the project's objectives. Once approved, merge the PR and squash the commits.

#### 2. Creating a new release

Follow the steps below to create a new release on GitHub:

1. Navigate to your repository homepage.
1. Click on the "Releases" tab which is next to the "About" section on the right side of the page.
1. Click on "Draft a new release" button which is toward the right side of the screen.
1. Select the main branch as the target for the release.
1. Enter a unique tag for the new version following your project's versioning system. This tag will be used to identify this specific release.
1. Under "Release title", give a short, meaningful name for the release.
1. Make sure "Generate Release Notes" option is selected.
*GitHub will automatically include a changelog of all commit messages since your last release.*
1. Once all the details are finalized, click on the "Publish release" button.
