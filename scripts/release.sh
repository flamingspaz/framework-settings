#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s major.minor.patch\n' "$0" >&2
    exit 2
fi

version=$1
if [[ ! $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    printf 'Invalid version %q: expected major.minor.patch (for example, 1.2.3)\n' "$version" >&2
    exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

files=(
    CMakeLists.txt
    daemon/Cargo.toml
    packaging/fedora/framework-kcm.spec
    packaging/fedora/framework-kcm-git.spec
    packaging/arch/PKGBUILD
    packaging/nix/packages/default.nix
)

patterns=(
    '^project\(framework-kcm VERSION [0-9]+\.[0-9]+\.[0-9]+\)$'
    '^version = "[0-9]+\.[0-9]+\.[0-9]+"$'
    '^Version:        [0-9]+\.[0-9]+\.[0-9]+$'
    '^%global _version [0-9]+\.[0-9]+\.[0-9]+$'
    '^pkgver=[0-9]+\.[0-9]+\.[0-9]+$'
    '^  version = "[0-9]+\.[0-9]+\.[0-9]+";$'
)

replacements=(
    "project(framework-kcm VERSION $version)"
    "version = \"$version\""
    "Version:        $version"
    "%global _version $version"
    "pkgver=$version"
    "  version = \"$version\";"
)

# Validate every expected declaration before changing any file.
for i in "${!files[@]}"; do
    file="$repo_root/${files[$i]}"
    if [[ ! -f $file ]]; then
        printf 'Could not find %s\n' "${files[$i]}" >&2
        exit 1
    fi
    match_count=$(grep -Ec -- "${patterns[$i]}" "$file" || true)
    if [[ $match_count -ne 1 ]]; then
        printf 'Expected one version declaration in %s, found %s\n' "${files[$i]}" "$match_count" >&2
        exit 1
    fi
done

for i in "${!files[@]}"; do
    sed -i -E "s|${patterns[$i]}|${replacements[$i]}|" "$repo_root/${files[$i]}"
done

(cd "$repo_root/daemon" && cargo update --workspace)

printf 'Updated project version to %s. Review the changes before committing.\n' "$version"
