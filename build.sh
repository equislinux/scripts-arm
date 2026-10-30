#!/usr/bin/env bash
# build.sh — build the x-scripts-arm package: the pinned equislinux/scripts
# tree plus the aarch64 delta in patch/. The result provides/replaces
# x-scripts on aarch64 systems only; equislinux/scripts is never modified.
#
# Usage:
#   ./build.sh                 # vendor/scripts at vendor/scripts.sha + patch
#   PKGDEST=/path ./build.sh   # output directory (default: ./out)
#
# Requires a native aarch64 host with makepkg (or the x-arm Docker builder):
#   ../x-arm/docker/run.sh bash -lc 'cd /workspace/scripts-arm && ./build.sh'
set -Eeuo pipefail
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_URL="${X_ARM_SCRIPTS_URL:-https://github.com/equislinux/scripts.git}"
SCRIPTS_DIR="$SELF_DIR/vendor/scripts"
OUT="${PKGDEST:-$SELF_DIR/out}"
PIN="$(grep -v '^#' "$SELF_DIR/vendor/scripts.sha" | head -n1 | tr -d '[:space:]')"

[[ -n "$PIN" ]] || { echo "missing pin in vendor/scripts.sha" >&2; exit 1; }
[[ "${EUID:-0}" -ne 0 ]] || { echo "makepkg refuses to run as root" >&2; exit 1; }

rm -rf -- "$SCRIPTS_DIR" "$OUT"
mkdir -p "$OUT"
echo "cloning equislinux/scripts at $PIN"
git clone -q --filter=blob:none --no-checkout "$SCRIPTS_URL" "$SCRIPTS_DIR"
git -C "$SCRIPTS_DIR" checkout -q --detach "$PIN"

echo "applying the aarch64 delta"
patch --batch --forward --silent -p1 -d "$SCRIPTS_DIR" \
    -i "$SELF_DIR/patch/generations-aarch64.patch"

# Derive the ARM package definition from the upstream one (same content,
# new identity: it replaces x-scripts on aarch64 installs).
sed -e 's/^pkgname=x-scripts$/pkgname=x-scripts-arm/' \
    -e 's#^url="https://github.com/equislinux/scripts"#url="https://github.com/equislinux/scripts-arm"#' \
    -e 's/^pkgdesc=.*/pkgdesc="x provisioning payload and CLI (reboot) with the aarch64 generations delta"/' \
    "$SCRIPTS_DIR/packaging/PKGBUILD" >"$SCRIPTS_DIR/packaging/PKGBUILD.arm"
printf '\nprovides=("x-scripts")\nconflicts=("x-scripts")\nreplaces=("x-scripts")\n' \
    >>"$SCRIPTS_DIR/packaging/PKGBUILD.arm"
mv "$SCRIPTS_DIR/packaging/PKGBUILD.arm" "$SCRIPTS_DIR/packaging/PKGBUILD"

( cd "$SCRIPTS_DIR/packaging" && PKGDEST="$OUT" \
    makepkg -f --nodeps --noconfirm --nocheck --cleanbuild >/dev/null )
echo "built:"
ls -lh "$OUT"
