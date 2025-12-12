#!/bin/bash
set -e

# Default UID and GID
TARGET_UID=${HOST_UID:-1000}
TARGET_GID=${HOST_GID:-1000}

# Update developer user and group
groupmod -o -g "$TARGET_GID" developer
usermod -o -u "$TARGET_UID" -g "$TARGET_GID" developer

# Take ownership of directories
chown -R developer:developer /source /build

# Drop privileges and execute the main command
exec gosu developer "$@"
