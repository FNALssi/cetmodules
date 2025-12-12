# Cetmodules Development Container

This directory contains a `Dockerfile` to create a containerized development environment for `cetmodules`.

## Building the Image

To build the image, run the following command from the root of the repository:

```bash
# For Docker or Podman
docker build -t cetmodules-dev dev/container
```

## Running the Container

The command to run the container differs between Docker and Podman due to differences in how they handle user namespaces.

First, create a local `build` directory if it does not already exist:

```bash
mkdir -p build
```

### For Docker Users

Docker users should map their host user ID directly to the container to ensure correct file ownership on mounted volumes.

```bash
docker run -it --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):/source" \
  -v "$(pwd)/build:/build" \
  cetmodules-dev
```

### For Podman Users (Rootless)

Rootless Podman uses user namespaces to map your host user to the `root` user (UID 0) inside the container. To ensure you have permission to write to mounted volumes, you should run as `root` inside the container. Any files created in the mounted volumes will be correctly owned by your user on the host.

```bash
podman run -it --rm \
  -v "$(pwd):/source" \
  -v "$(pwd)/build:/build" \
  cetmodules-dev
```
*(Note: Running as `root` is the intended usage for rootless Podman and is safe because you are in an unprivileged user namespace.)*


### Usage

Once inside the container, you can perform an out-of-source build like this:

```bash
cmake -S /source -B . -DBUILD_DOCS=ON
cmake --build .
ctest
```
