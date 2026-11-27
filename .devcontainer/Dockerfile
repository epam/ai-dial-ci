FROM node:26-slim

RUN apt-get update && \
    apt-get install -y -o APT::Install-Recommends=false bats ca-certificates git gh shellcheck wget && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/

RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

RUN npm install -g semver @anthropic-ai/claude-code

RUN wget -qO /tmp/actionlint.tar.gz https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz && \
    tar -xf /tmp/actionlint.tar.gz -C /tmp actionlint && \
    install -o root -m 755 /tmp/actionlint /usr/local/bin/actionlint && \
    rm /tmp/actionlint.tar.gz /tmp/actionlint

USER node

RUN gh auth setup-git -f --hostname github.com
