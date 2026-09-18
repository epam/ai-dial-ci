FROM node:26-slim

RUN apt-get update && \
    apt-get install -y -o APT::Install-Recommends=false bats ca-certificates git gh shellcheck wget && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/

RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

RUN npm install -g semver @anthropic-ai/claude-code

USER node

RUN gh auth setup-git -f --hostname github.com
