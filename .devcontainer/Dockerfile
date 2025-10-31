FROM node:alpine

LABEL maintainer="Andre Dreyer"

ARG PRODUCT=terraform
ARG VERSION=1.13.4

RUN apk add --update --no-cache fish starship stow git github-cli gum font-fira-code-nerd

RUN apk add --update --virtual .deps --no-cache gnupg && \
    cd /tmp && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    rm -f /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS ${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    apk del .deps

RUN apk add --no-cache aws-cli

# Install Docker CLI (for Docker-outside-of-Docker)
RUN apk add --no-cache docker-cli docker-cli-compose

# BASH is needed for setting up docker-outside-of-docker as per devcontainer.json
RUN apk add --no-cache bash

# Install LocalStack CLI (requires build dependencies for psutil)
#RUN apk add --no-cache --virtual .build-deps gcc musl-dev python3-dev linux-headers && \
#    pip3 install --no-cache-dir --break-system-packages localstack awscli-local && \
#    apk del .build-deps

RUN npm install -g @anthropic-ai/claude-code

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
