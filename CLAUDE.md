# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Build the latest version (auto-detected by highest semver directory):

```bash
./build.sh
```

Build a specific version with a custom local tag:

```bash
./build.sh --version 1.24.2 --repository unbound-local --no-latest-tag
```

By default, `build.sh` disables Docker layer cache. Use `--cache` to enable it.

## Adding a new Unbound version

1. Create a new directory named after the version (e.g., `1.25.0/`)
2. Copy the `Dockerfile` and `data/` directory from the previous version
3. Update in the Dockerfile:
   - `UNBOUND_VERSION`, `UNBOUND_SHA256`, `UNBOUND_DOWNLOAD_URL` (in the `unbound` stage)
   - The `cd unbound-X.Y.Z` line in the build RUN command
   - `UNBOUND_VERSION` in the final stage ENV
   - OpenSSL version/SHA256 if updating that too
4. Update `README.md` supported tags list
5. Update `k8s/deployment.yml` image tag

## Architecture

**Multi-stage Dockerfile** (per version directory):
- Stage 1 (`openssl`): Builds OpenSSL from source with hardened flags (no-ssl3, no-weak-ssl-ciphers, static)
- Stage 2 (`unbound`): Builds Unbound from source, linking against the custom OpenSSL
- Stage 3 (final): Minimal runtime image copying only `/opt` from stage 2

**Runtime** (`data/unbound.sh`): Entrypoint script that generates `unbound.conf` dynamically at startup based on available memory and CPU count (cache sizes, thread count, and slab count are calculated at runtime). If `/opt/unbound/etc/unbound/unbound.conf` already exists (volume mount), it skips generation.

**Config files** (mounted as volumes at `/opt/unbound/etc/unbound/`):
- `forward-records.conf` — upstream forwarders (default: Cloudflare over TLS port 853)
- `a-records.conf` — local A/PTR records
- `srv-records.conf` — local SRV records

The `data/` directory is identical across versions — only the Dockerfile changes between versions.
