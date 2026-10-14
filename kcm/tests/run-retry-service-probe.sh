#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/framework-retry-service-probe.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM

cat >"$build_dir/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(FrameworkRetryServiceProbe LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Test)
find_package(KF6I18n REQUIRED)
add_executable(retry-service-probe
    "${PROJECT_ROOT}/kcm/frameworkkcm.cpp"
    "${PROJECT_ROOT}/kcm/tests/retry_service_probe.cpp"
)
target_compile_definitions(retry-service-probe PRIVATE FRAMEWORK_STANDALONE)
target_include_directories(retry-service-probe PRIVATE "${PROJECT_ROOT}/kcm")
target_link_libraries(retry-service-probe PRIVATE Qt6::Core Qt6::DBus Qt6::Test KF6::I18n)
CMAKE

cmake -S "$build_dir" -B "$build_dir/build" -DPROJECT_ROOT="$root"
cmake --build "$build_dir/build" --parallel

dbus-run-session -- sh -c '
    export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
    exec "$1" -v1
' sh "$build_dir/build/retry-service-probe"
