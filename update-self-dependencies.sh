#!/bin/bash

read -p "Enter the next (predicted) version tag (e.g., 1.0.1): " next_version

# Define the search pattern
search_pattern="epam/ai-dial-ci/"

# Find all .yml and .yaml files and replace the version tag
find . -type f \( -name "*.yml" -o -name "*.yaml" \) -exec sed -i "s|\(${search_pattern}[^@]*@\)[^ ]*|\1${next_version}|g" {} +

echo "Updated all occurrences of '${search_pattern}' with version '${next_version}'."