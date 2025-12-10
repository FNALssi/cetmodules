# Base image
FROM ubuntu:latest

# Set non-interactive frontend to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    doxygen \
    graphviz \
    python3 \
    python3-pip \
    sudo && \
    rm -rf /var/lib/apt/lists/*

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

# Create a non-root user
RUN useradd -m -u 1000 -s /bin/bash developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create source and build directories
RUN mkdir /source && \
    chown developer:developer /source && \
    mkdir /build && \
    chown developer:developer /build

# Set user and working directory
USER developer
WORKDIR /build

# Set default command
CMD ["/bin/bash"]
