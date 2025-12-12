# Dockerfile for building Cetmodules development image.

# Podman instructions for building and uploading tagged images:
#   $ DATE="$(date +"%Y-%m-%d")"
#   $ podman build --tag cetmodules-dev:$DATE .
#   $ podman login ghcr.io --username <username> -p $(gh auth token)
#   $ podman push cetmodules-dev:$DATE ghcr.io/fnalssi/cetmodules-dev:$DATE
# ... and optionally push with destination tag "latest"

# Base image
FROM ubuntu:latest

# Set non-interactive frontend to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    git \
    doxygen \
    graphviz \
    m4 \
    ninja-build \
    python3 \
    python3-pip \
    sudo \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Install gosu for privilege dropping
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(dpkg --print-architecture)" && \
    chmod +x /usr/local/bin/gosu

# Install Python packages
RUN pip3 install --no-cache-dir --break-system-packages \
    cmake \
    sphinx \
    sphinxcontrib-moderncmakedomain \
    sphinx-design \
    sphinx-toolbox \
    sphinxcontrib-jquery

# Install Catch2
RUN git clone https://github.com/catchorg/Catch2.git /tmp/Catch2 && \
    cmake -S /tmp/Catch2 -B /tmp/Catch2/build -DBUILD_TESTING=OFF && \
    cmake --build /tmp/Catch2/build --target install && \
    rm -rf /tmp/Catch2

# Create a non-root user and directories.
# The user's UID/GID will be adjusted at runtime by the entrypoint.
RUN useradd -m -u 5000 -s /bin/bash developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir /source && \
    mkdir /build

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory and entrypoint
WORKDIR /build
ENTRYPOINT ["entrypoint.sh"]

# Set default command
CMD ["/bin/bash"]
