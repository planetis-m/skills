#!/bin/sh
# Installs the <app> binary from GitHub Releases on Linux and macOS.
#
#   curl -fsSL https://github.com/<owner>/<repo>/releases/latest/download/install.sh | sh
#
# <APP>_VERSION      release tag to install (default: the latest release)
# <APP>_INSTALL_DIR  where to put <app> (default: ~/.local/bin)
set -eu

repo="<owner>/<repo>"
version="${<APP>_VERSION:-latest}"
dir="${<APP>_INSTALL_DIR:-$HOME/.local/bin}"

die() { echo "<app> install: $*" >&2; exit 1; }

case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=macos ;;
  *) die "unsupported OS: $(uname -s); on Windows use install.ps1" ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac
# A shell running under Rosetta reports x86_64 on Apple silicon.
if [ "$os" = macos ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then
  arch=arm64
fi
if [ "$os-$arch" = macos-amd64 ]; then
  die "no Intel macOS build is published; build from source"
fi

if [ "$version" = latest ]; then
  base="https://github.com/$repo/releases/latest/download"
else
  base="https://github.com/$repo/releases/download/$version"
fi
asset="<app>-$os-$arch.tar.gz"

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  die "curl or wget is required"
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  die "sha256sum or shasum is required"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Downloading $asset ($version)"
fetch "$base/$asset" "$tmp/$asset" || die "cannot download $base/$asset"
fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || die "cannot download $base/SHA256SUMS"

expected="$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS")"
[ -n "$expected" ] || die "$asset is not listed in SHA256SUMS"
[ "$(sha256 "$tmp/$asset")" = "$expected" ] || die "checksum mismatch for $asset"

tar -xzf "$tmp/$asset" -C "$tmp" <app>
mkdir -p "$dir"
# Replace rather than overwrite in place, so a running <app> is not disturbed.
cp "$tmp/<app>" "$dir/<app>.new"
chmod 755 "$dir/<app>.new"
mv -f "$dir/<app>.new" "$dir/<app>"

"$dir/<app>" -h >/dev/null 2>&1 || die "installed $dir/<app> but it does not run"
echo "Installed <app> to $dir/<app>"

case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "Add $dir to your PATH, e.g.: export PATH=\"$dir:\$PATH\"" ;;
esac
