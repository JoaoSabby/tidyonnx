#!/bin/sh
# The host resolves metadata and starts Docker; package validation stays inside Fedora.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
command -v docker >/dev/null 2>&1 || {
  echo "Docker is required; no host test fallback is permitted." >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "curl is required to resolve the current official Fedora release." >&2
  exit 1
}
test "$(docker info --format '{{.OSType}}')" = linux || {
  echo "A running Docker Linux-container engine is required." >&2
  exit 1
}
metadata=$(curl --fail --show-error --silent --location \
  https://fedoraproject.org/releases.json)
fedora_version=$(printf '%s\n' "$metadata" |
  grep -oE '"version"[[:space:]]*:[[:space:]]*("[0-9]+"|[0-9]+)[[:space:]]*[,}]' |
  sed -E 's/[^0-9]//g' | sort -n | tail -1)
test -n "$fedora_version" || {
  echo "Official Fedora metadata has no stable release." >&2
  exit 1
}
fedora_image="registry.fedoraproject.org/fedora:$fedora_version"
run_dir="validation-results/fedora/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$run_dir"
printf '%s\n' "$fedora_image" > "$run_dir/selected-fedora-image.txt"
docker version > "$run_dir/docker-version.txt"
if ! docker build --pull --no-cache --file tools/docker/Dockerfile \
  --build-arg "FEDORA_IMAGE=$fedora_image" \
  --iidfile "$run_dir/image-id.txt" --tag tidyonnx-fedora-tests . \
  > "$run_dir/image-build.log" 2>&1; then
  tail -80 "$run_dir/image-build.log" >&2
  exit 1
fi
image_id=$(cat "$run_dir/image-id.txt")
docker image inspect "$image_id" > "$run_dir/image-inspect.json"
docker image inspect "$fedora_image" > "$run_dir/base-image-inspect.json"
git rev-parse HEAD > "$run_dir/git-head.txt"
git diff --binary > "$run_dir/worktree.patch"
container_id=$(docker create "$image_id")
# Copying evidence through Docker also works when the daemon runs on a remote host.
set +e
docker start --attach "$container_id"
start_status=$?
state=$(docker inspect --format '{{.State.Status}}' "$container_id")
run_status=$(docker inspect --format '{{.State.ExitCode}}' "$container_id")
docker logs "$container_id" > "$run_dir/container.log" 2>&1
docker inspect "$container_id" > "$run_dir/container-inspect.json"
docker cp "$container_id:/evidence/." "$run_dir/"
copy_status=$?
docker rm "$container_id" >/dev/null
set -e
test "$start_status" -eq 0 && test "$copy_status" -eq 0 &&
  test "$state" = exited && test "$run_status" = 0 || exit 1
