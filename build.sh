#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./build.sh [options]

Build the highest versioned Docker image directory in this repository by default.
The build runs without Docker layer cache unless you explicitly opt in with --cache.

Options:
  -v, --version VERSION      Build a specific version directory instead
  -r, --repository REPO      Docker repository/name to tag (default: mvance/unbound)
      --cache                Allow Docker to reuse build cache
      --no-latest-tag        Do not also tag the build as :latest
      --pull                 Pass --pull to docker build
  -h, --help                 Show this help text

Examples:
  ./build.sh
  ./build.sh --repository unbound-local
  ./build.sh --version 1.24.2 --repository unbound-local --no-latest-tag
  ./build.sh --cache --repository unbound-local
EOF
}

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
default_repository="mvance/unbound"
repository="$default_repository"
version=""
no_cache=1
pull_flag=0
tag_latest=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
            version="$2"
            shift 2
            ;;
        -r|--repository)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
            repository="$2"
            shift 2
            ;;
        --cache)
            no_cache=0
            shift
            ;;
        --no-latest-tag)
            tag_latest=0
            shift
            ;;
        --pull)
            pull_flag=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

latest_version="$(
    find "$script_dir" -mindepth 1 -maxdepth 1 -type d \
        | sed "s#${script_dir}/##" \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n 1
)"

if [[ -z "$latest_version" ]]; then
    echo "No version directories found in $script_dir" >&2
    exit 1
fi

if [[ -z "$version" ]]; then
    version="$latest_version"
fi

build_dir="$script_dir/$version"

if [[ ! -d "$build_dir" ]]; then
    echo "Version directory not found: $build_dir" >&2
    exit 1
fi

if [[ "$version" != "$latest_version" ]]; then
    tag_latest=0
fi

build_args=(
    docker build
    -t "${repository}:${version}"
)

if [[ "$no_cache" -eq 1 ]]; then
    build_args+=(--no-cache)
fi

if [[ "$tag_latest" -eq 1 ]]; then
    build_args+=(-t "${repository}:latest")
fi

if [[ "$pull_flag" -eq 1 ]]; then
    build_args+=(--pull)
fi

build_args+=("$build_dir")

printf 'Building %s from %s\n' "${repository}:${version}" "$build_dir"
if [[ "$no_cache" -eq 1 ]]; then
    printf 'Docker build cache disabled\n'
fi
if [[ "$tag_latest" -eq 1 ]]; then
    printf 'Also tagging %s\n' "${repository}:latest"
fi

"${build_args[@]}"
