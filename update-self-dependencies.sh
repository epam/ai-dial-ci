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

    # Store commits with their hashes for reference
    commit_log=$(git log "${full_tag}..HEAD" --pretty=format:"%h %s" 2>/dev/null || echo "")

    # Check for breaking changes according to Conventional Commits spec
    if [ -n "$commit_log" ]; then
        # Look for breaking changes with ! syntax
        breaking_change=$(echo "$commit_log" | grep -E "^[a-f0-9]+ [a-z]+(\([a-z0-9/-]+\))?!:" | head -1)
        if [ -n "$breaking_change" ]; then
            suggested_version="$((major + 1)).0.0"
            echo "Breaking change detected in commit: $breaking_change"
        # Look for feature commits
        elif echo "$commit_log" | grep -E "^[a-f0-9]+ feat(\([a-z0-9/-]+\))?:" > /dev/null; then
            suggested_version="$major.$((minor + 1)).0"
            feature_commit=$(echo "$commit_log" | grep -E "^[a-f0-9]+ feat(\([a-z0-9/-]+\))?:" | head -1)
            echo "New feature detected in commit: $feature_commit"
        # Default to patch bump
        else
            suggested_version="$major.$minor.$((patch + 1))"
            echo "No significant changes detected"
        fi
    else
        # No commits found since last tag
        echo "No commits found since the last tag (${full_tag}). Nothing to update."
        exit 0
    fi
fi

# Prompt user with the suggested version
read -p "Enter the next version tag or keep empty to apply suggested ($suggested_version): " next_version
next_version=${next_version:-$suggested_version}

# Define the search pattern
search_pattern="epam/ai-dial-ci/"

# Find all .yml and .yaml files and replace the version tag
find . -type f \( -name "*.yml" -o -name "*.yaml" \) -exec sed -i "s|\(${search_pattern}[^@]*@\)[^ ]*|\1${next_version}|g" {} +

echo "Updated all occurrences of '${search_pattern}' with version '${next_version}'."