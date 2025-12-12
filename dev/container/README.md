# Cetmodules Development Container

This directory contains a `Dockerfile` to create a containerized development environment for `cetmodules`.

## Building the Image

To build the Docker or Podman image, run the following command from the root of the repository:

```bash
docker build -t cetmodules-dev dev/container
```

## Running the Container

To run the container, first create a local `build` directory if it does not already exist:

```bash
mkdir -p build
```

Then, execute the following command from the root of the repository to start an interactive shell inside the container:

```bash
docker run -it --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):/source" \
  -v "$(pwd)/build:/build" \
  cetmodules-dev
```

This command will start an interactive shell inside the container, with the `cetmodules` source code mounted at `/source` and your local `build` directory mounted at `/build`.

### Command Explanation:

*   `-it`: Runs the container in interactive mode with a TTY.
*   `--rm`: Automatically removes the container when it exits.
*   `--user "$(id -u):$(id -g)"`: Runs the container with your host user and group ID. This ensures that files created in the mounted volumes have the correct ownership on your host machine.
*   `-v "$(pwd):/source"`: Mounts the current directory (the `cetmodules` source) into the `/source` directory inside the container.
*   `-v "$(pwd)/build:/build"`: Mounts your local `build` directory into the `/build` directory inside the container.
*   `cetmodules-dev`: The name of the image to run.

Once inside the container, you can perform an out-of-source build like this:

```bash
cmake -S /source -B . -DBUILD_DOCS=ON
cmake --build .
ctest
```
