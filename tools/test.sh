#!/usr/bin/env bash
# Run the busted specs inside the Lua 5.1 Docker image (built on first use).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="wow-addon-lua"
if [[ ! -d "$REPO/spec" ]]; then
    echo "No spec/ folder, nothing to test."
    exit 0
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" -f "$REPO/tools/docker/Dockerfile" "$REPO/tools/docker"
fi
exec docker run --rm -v "$REPO":/work -w /work "$IMAGE" busted "$@"
