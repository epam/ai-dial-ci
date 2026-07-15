#!/usr/bin/env bash
set -euo pipefail

# the /home/vscode volume can end up root-owned; hand it back to vscode
sudo chown -R vscode:vscode /home/vscode

sudo apt-get update
sudo apt-get install -y --no-install-recommends bats shellcheck

sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

npm install -g semver

# gh isn't logged in on first run (config lives in an empty named volume until `gh auth login`)
gh auth setup-git -f --hostname github.com
