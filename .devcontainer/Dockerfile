# Use Ubuntu Noble (24.04 LTS) for a lower CVE surface area than Debian Bookworm
FROM ubuntu:24.04

LABEL maintainer="André Dreyer"

# Avoid prompts from apt during build only (ARG scopes it to build time, not the running container)
ARG DEBIAN_FRONTEND=noninteractive

ARG PRODUCT=terraform
ARG VERSION=1.14.0

# Install base dependencies in a single layer
# apt-get upgrade ensures any base image CVEs are patched at build time.
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    # Essential build tools (required for psutil/checkov)
    build-essential \
    # Networking and download tools
    curl \
    ca-certificates \
    gnupg \
    wget \
    # Version control
    git \
    # Useful utilities
    unzip \
    less \
    sudo \
    # Required for AWS CLI v2
    groff \
    # Required for LocalStack CLI / checkov
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 via the official NodeSource apt repository.
# Using the keyring/sources.list approach avoids piping a remote script directly into bash,
# which removes the supply-chain risk of the setup_22.x installer method.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Update npm to the latest version
RUN npm install -g npm@latest

# Install Terraform
RUN ARCH=$(dpkg --print-architecture) && \
    cd /tmp && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_${ARCH}.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VERSION}_linux_${ARCH}.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VERSION}_linux_${ARCH}.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    rm -f /tmp/${PRODUCT}_${VERSION}_linux_${ARCH}.zip ${PRODUCT}_${VERSION}_SHA256SUMS ${PRODUCT}_${VERSION}_SHA256SUMS.sig

# Install AWS CLI v2
# AWS CLI v2 is distributed as a pre-built binary package
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
       elif [ "$ARCH" = "arm64" ]; then AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"; \
       else echo "Unsupported arch: $ARCH" && exit 1; fi \
    && curl -fsSL "$AWS_URL" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install Docker CLI (for Docker-outside-of-Docker)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install LocalStack CLI and other Python tools
# --break-system-packages is required on Ubuntu 24.04 due to PEP 668
RUN pip3 install --no-cache-dir --break-system-packages localstack awscli-local checkov

# Install TFLint
ARG TFLINT_VERSION=v0.53.0
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" \
       -o /tmp/tflint.zip \
    && unzip /tmp/tflint.zip -d /usr/local/bin \
    && rm /tmp/tflint.zip \
    && chmod +x /usr/local/bin/tflint

# Install 1Password CLI
RUN curl -sS https://downloads.1password.com/linux/keys/1password.asc \
       | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
       | tee /etc/apt/sources.list.d/1password.list \
    && apt-get update && apt-get install -y --no-install-recommends 1password-cli \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh) — PR/issue management and AI-assisted workflows
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for development (following devcontainer best practices)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Configure git user
# Note: git config is also set via postCreateCommand in devcontainer.json at container start.
# The step here ensures git works correctly during the image build (e.g. for any RUN steps that use git).
RUN git config --global user.name "André Dreyer" && \
    git config --global user.email "github@andredreyer.com"

# Install Claude Code CLI using the official Anthropic native installer.
# This is the vendor-recommended install method: https://docs.anthropic.com/en/docs/claude-code/setup
# Note: npm installation is deprecated by Anthropic. Native installer auto-updates in background.
# Risk acknowledged: supply-chain trust is delegated to Anthropic's claude.ai domain.
# No checksummed or versioned alternative is currently provided by Anthropic.
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add ~/.local/bin to PATH so the `claude` binary is accessible
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"

# Default command
CMD ["/bin/bash"]
