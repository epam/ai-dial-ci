#!/bin/bash

# Get the latest tag, handling both v-prefixed and non-prefixed versions
latest_tag=$(git tag --sort=-v:refname | grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+$" | head -n1 | sed 's/^v//' )

if [ -z "$latest_tag" ]; then
    suggested_version="1.0.0"
else
    # Split version into parts
    IFS='.' read -r major minor patch <<< "$latest_tag"

    # Get the full tag name (with or without v prefix) for git log
    full_tag=$(git tag --sort=-v:refname | grep -E "^v?${latest_tag}$" | head -n1)

    # Analyze commits since last tag
    git_log=$(git log "${full_tag}..HEAD" --pretty=format:"%s" 2>/dev/null || echo "")

    # Check for keywords indicating feature additions
    if [ -n "$git_log" ] && echo "$git_log" | grep -iE "feat:|feature:" > /dev/null; then
        # Bump minor version for new features
        suggested_version="$major.$((minor + 1)).0"
    else
        # Bump patch version for fixes and minor changes
        suggested_version="$major.$minor.$((patch + 1))"
    fi
fi

# Prompt user with the suggested version
read -p "Enter the next version tag (suggested: $suggested_version): " next_version
next_version=${next_version:-$suggested_version}

# Define the search pattern
search_pattern="epam/ai-dial-ci/"

# Find all .yml and .yaml files and replace the version tag
find . -type f \( -name "*.yml" -o -name "*.yaml" \) -exec sed -i "s|\(${search_pattern}[^@]*@\)[^ ]*|\1${next_version}|g" {} +

echo "Updated all occurrences of '${search_pattern}' with version '${next_version}'."