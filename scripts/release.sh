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

for required in appstreamcli cargo; do
    if ! command -v "$required" >/dev/null; then
        printf '%s is required (appstreamcli validates the metainfo file; cargo updates daemon/Cargo.lock)\n' "$required" >&2
        exit 1
    fi
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
release_date=$(date +%F)
metainfo=data/com.github.framework-settings.metainfo.xml
lockfile=daemon/Cargo.lock
# Files edit() will change, collected during the validate pass.
targets=()

# edit FILE PATTERN REPLACEMENT [PATTERN REPLACEMENT...]
#
# Each PATTERN is an extended regular expression that must match exactly one
# line in FILE; that line is replaced with REPLACEMENT (a sed replacement, so
# \1 and \n work). In the validate pass this only checks the patterns; in the
# apply pass it rewrites FILE with a single sed invocation.
edit() {
    local file=$1 path=$repo_root/$1 count
    local -a sed_args=()
    shift
    if [[ ! -f $path ]]; then
        printf 'Could not find %s\n' "$file" >&2
        exit 1
    fi
    if [[ $mode == validate ]]; then
        targets+=("$file")
    fi
    while [[ $# -gt 0 ]]; do
        if [[ $mode == validate ]]; then
            count=$(grep -Ec -- "$1" "$path" || true)
            if [[ $count -ne 1 ]]; then
                printf 'Expected one line matching %s in %s, found %s\n' "$1" "$file" "$count" >&2
                exit 1
            fi
        fi
        sed_args+=(-e "s|$1|$2|")
        shift 2
    done
    if [[ $mode == apply ]]; then
        sed -i -E "${sed_args[@]}" "$path"
    fi
}

# Every file the script edits, listed once with all of its edits. A new
# upstream version resets the distribution release counters to 1. Fixed
# references to older releases (for example, Breaks/Replaces on the
# monolithic framework-kcm package) are deliberately not listed.
edit_all() {
    edit CMakeLists.txt \
        '^project\(framework-kcm VERSION [0-9]+\.[0-9]+\.[0-9]+\)$' "project(framework-kcm VERSION $version)"
    edit daemon/Cargo.toml \
        '^version = "[0-9]+\.[0-9]+\.[0-9]+"$' "version = \"$version\""
    edit packaging/fedora/framework-settings.spec \
        '^Version:        [0-9]+\.[0-9]+\.[0-9]+$' "Version:        $version" \
        '^Release:        [0-9]+(\.[0-9]+)*%\{\?dist\}$' 'Release:        1%{?dist}'
    # Version derives from _version and Release is always 1.
    edit packaging/fedora/framework-settings-git.spec \
        '^%global _version [0-9]+\.[0-9]+\.[0-9]+$' "%global _version $version"
    edit packaging/arch/PKGBUILD \
        '^pkgver=[0-9]+\.[0-9]+\.[0-9]+$' "pkgver=$version" \
        '^pkgrel=[0-9]+(\.[0-9]+)?$' 'pkgrel=1'
    edit packaging/nix/packages/default.nix \
        '^  version = "[0-9]+\.[0-9]+\.[0-9]+";$' "  version = \"$version\";"
    # Newest release first, one level deeper than <releases>.
    edit "$metainfo" \
        '^( *)<releases>$' "\\1<releases>\\n\\1  <release version=\"$version\" date=\"$release_date\" />"
}

# version_gt A B: succeed if major.minor.patch A is strictly greater than B.
version_gt() {
    local -a a b
    local i
    IFS=. read -ra a <<<"$1"
    IFS=. read -ra b <<<"$2"
    for i in 0 1 2; do
        if ((10#${a[i]} != 10#${b[i]})); then
            ((10#${a[i]} > 10#${b[i]}))
            return
        fi
    done
    return 1
}

# Validate every expected declaration before changing any file.
mode=validate
edit_all
current=$(sed -nE 's/^project\(framework-kcm VERSION ([0-9]+\.[0-9]+\.[0-9]+)\)$/\1/p' "$repo_root/CMakeLists.txt")
if ! version_gt "$version" "$current"; then
    printf 'Version %s must be greater than the current version %s\n' "$version" "$current" >&2
    exit 1
fi
if grep -Fq -- "<release version=\"$version\"" "$repo_root/$metainfo"; then
    printf '%s already has a release entry for %s\n' "$metainfo" "$version" >&2
    exit 1
fi
if [[ ! -f $repo_root/$lockfile ]]; then
    printf 'Could not find %s\n' "$lockfile" >&2
    exit 1
fi
targets+=("$lockfile")

# Back up every file that will change, and restore them all unless the whole
# release update succeeds, so a failure or interruption changes nothing.
backup_dir=
editing=0
completed=0
cleanup() {
    local status=$? i
    local -a unrestored=()
    # A second interrupt must not abort the restore: bash does not re-run the
    # EXIT trap, so the tree would be left half-restored.
    trap '' INT TERM HUP
    if [[ $editing -eq 1 && $completed -ne 1 ]]; then
        # Keep going past a failed copy so the remaining files still get restored.
        for i in "${!targets[@]}"; do
            cp -p -- "$backup_dir/$i" "$repo_root/${targets[i]}" || unrestored+=("${targets[i]}")
        done
        if [[ ${#unrestored[@]} -eq 0 ]]; then
            printf 'Release update failed; restored all files.\n' >&2
        else
            printf 'Release update failed; could not restore:\n' >&2
            printf '  %s\n' "${unrestored[@]}" >&2
            if [[ $status -eq 0 ]]; then
                status=1
            fi
        fi
    fi
    if [[ -n $backup_dir ]]; then
        rm -rf -- "$backup_dir" || true
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/release.XXXXXX")
for i in "${!targets[@]}"; do
    cp -p -- "$repo_root/${targets[i]}" "$backup_dir/$i"
done
editing=1

mode=apply
edit_all

appstreamcli validate --no-net "$repo_root/$metainfo"

(cd "$repo_root/daemon" && cargo update --workspace)

completed=1
printf 'Updated project version to %s. Review the changes before committing.\n' "$version"
