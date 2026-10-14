# Developer shortcuts for building, running and formatting the UIs.
# Run `just` to list the recipes. See docs/building.md for details.

set shell := ["bash", "-euo", "pipefail", "-c"]

# CI checks formatting with clang-format 22; prefer it when installed.
clang_format := env('CLANG_FORMAT', if `command -v clang-format-22 || true` != "" { "clang-format-22" } else { "clang-format" })
build_type := env('CMAKE_BUILD_TYPE', 'Debug')
prefix := env('CMAKE_INSTALL_PREFIX', '/usr')
# Like the shell, resolve a relative DESTDIR from the directory just was run in.
destdir := if env('DESTDIR', '') == '' { '' } else { join(invocation_directory(), env('DESTDIR')) }
kcm_build_dir := "build-kcm"
gui_build_dir := "build-gui"

# C++ sources checked by CI (tracked plus untracked, not ignored files).
cpp_files := "git ls-files -z --cached --others --exclude-standard -- '*.cpp' '*.h' '*.hpp'"

# List the available recipes
default:
    @{{ quote(just_executable()) }} --list --justfile {{ quote(justfile()) }}

# Format all C++ sources in place with the repository's .clang-format
format:
    {{ cpp_files }} | xargs -0 -r {{ quote(clang_format) }} --style=file -i

# Check C++ formatting without changing files (as CI does)
format-check:
    {{ cpp_files }} | xargs -0 -r {{ quote(clang_format) }} --style=file --dry-run --Werror

# Configure the KDE System Settings module only, in build-kcm/
configure-kcm:
    cmake -S . -B {{ quote(kcm_build_dir) }} \
        -DCMAKE_BUILD_TYPE={{ quote(build_type) }} \
        -DCMAKE_INSTALL_PREFIX={{ quote(prefix) }} \
        -UKDE_INSTALL_USE_QT_SYS_PATHS \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DBUILD_KCM=ON -DBUILD_GUI=OFF -DBUILD_DAEMON=OFF

# Build the KCM
build-kcm: configure-kcm
    cmake --build {{ quote(kcm_build_dir) }} --parallel

# Run the freshly built KCM in fixture mode, e.g. `just run-kcm framework-12`
run-kcm model="": build-kcm
    QT_PLUGIN_PATH="$PWD/"{{ quote(kcm_build_dir + "/bin") }}"${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
    FRAMEWORK_KCM_FIXTURE=1 \
    {{ if model != "" { "FRAMEWORK_KCM_FIXTURE_MODEL=" + quote(model) } else { "" } }} \
    kcmshell6 kcm_framework

# Install the KCM (uses sudo only if an install directory is not writable)
install-kcm: build-kcm (_install kcm_build_dir)

# Configure the standalone Qt application only, in build-gui/
configure-gui:
    cmake -S . -B {{ quote(gui_build_dir) }} \
        -DCMAKE_BUILD_TYPE={{ quote(build_type) }} \
        -DCMAKE_INSTALL_PREFIX={{ quote(prefix) }} \
        -UKDE_INSTALL_USE_QT_SYS_PATHS \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DBUILD_KCM=OFF -DBUILD_GUI=ON -DBUILD_DAEMON=OFF

# Build the standalone application
build-gui: configure-gui
    cmake --build {{ quote(gui_build_dir) }} --parallel

# Run the freshly built application in fixture mode, e.g. `just run-gui framework-12`
run-gui model="": build-gui
    FRAMEWORK_KCM_FIXTURE=1 \
    {{ if model != "" { "FRAMEWORK_KCM_FIXTURE_MODEL=" + quote(model) } else { "" } }} \
    {{ quote("./" + gui_build_dir + "/bin/framework-settings") }}

# Install the standalone application (uses sudo only if an install directory is not writable)
install-gui: build-gui (_install gui_build_dir)

# Run `cmake --install`, with sudo only if some destination (under DESTDIR, if
# set) is not writable. Missing directories are judged by their nearest
# existing ancestor, so a new prefix under $HOME does not need sudo.
_install build_dir:
    #!/usr/bin/env bash
    set -euo pipefail
    build_dir={{ quote(build_dir) }}
    export DESTDIR={{ quote(destdir) }}
    prefix=$(sed -n 's/^CMAKE_INSTALL_PREFIX:PATH=//p' "$build_dir/CMakeCache.txt")
    sudo=()
    while IFS= read -r dest; do
        # CMake prepends DESTDIR to the absolute install destination.
        dir=$DESTDIR${dest//'${CMAKE_INSTALL_PREFIX}'/$prefix}
        while [[ ! -e $dir ]]; do dir=$(dirname -- "$dir"); done
        if [[ ! -w $dir ]]; then
            echo "$dir is not writable; installing with sudo" >&2
            sudo=(sudo)
            break
        fi
    done < <(find "$build_dir" -name cmake_install.cmake -exec grep -ho 'DESTINATION "[^"]*"' {} + |
        sed 's/^DESTINATION "//; s/"$//' | sort -u)
    "${sudo[@]}" env DESTDIR="$DESTDIR" cmake --install "$build_dir"

# Bump the project version for a release (see docs/releasing.md)
release version:
    ./scripts/release.sh {{ quote(version) }}
