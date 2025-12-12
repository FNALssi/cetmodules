#!/bin/bash
set -e

# Default UID and GID
UID=${HOST_UID:-1000}
GID=${HOST_GID:-1000}

# Update developer user and group
groupmod -o -g "$GID" developer
usermod -o -u "$UID" -g "$GID" developer

# Take ownership of directories
chown -R developer:developer /source /build

# Drop privileges and execute the main command
exec gosu developer "$@"
