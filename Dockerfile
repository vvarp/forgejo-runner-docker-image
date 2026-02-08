ARG DOCKER_VARIANT=dind
ARG NODE_VERSION=20

# Use Node.js Alpine image to get the specific Node version
FROM node:${NODE_VERSION}-alpine AS node-source

# Build final image based on Docker variant
FROM docker:${DOCKER_VARIANT}

ARG NODE_VERSION
ARG DOCKER_VARIANT

# Copy Node.js binaries and libraries from the node-source stage
COPY --from=node-source /usr/local/bin/node /usr/local/bin/node
COPY --from=node-source /usr/local/lib/node_modules/ /usr/local/lib/node_modules/

USER root

# Symlink npm and other tools to make them available in PATH
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack && \
    chmod +x /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    git-lfs \
    jq \
    yq \
    ca-certificates \
    openssl \
    gnupg \
    which \
    zip \
    unzip \
    xz \
    zstd \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    sudo \
    && corepack enable

# Install Helm and kubectl
ARG HELM_VERSION=v3.18.4
ARG KUBECTL_VERSION=v1.34.3
RUN set -eux; \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-amd64 && \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x /usr/local/bin/helm /usr/local/bin/kubectl && \
    helm version --short && \
    kubectl version --client --short

# Docker entrypoints and TLS defaults (align with official images)
COPY dockerd-entrypoint.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# TLS cert directory used by entrypoints (client/server certs)
ENV DOCKER_TLS_CERTDIR=/certs
RUN mkdir -p /certs /certs/client && chmod 1777 /certs /certs/client

# Select ENTRYPOINT by variant at build-time and use a stable path
RUN set -eux; \
    case "${DOCKER_VARIANT}" in \
      dind|dind-rootless) ln -sf /usr/local/bin/dockerd-entrypoint.sh /entrypoint.sh ;; \
      cli|*) ln -sf /usr/local/bin/docker-entrypoint.sh /entrypoint.sh ;; \
    esac

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD []
