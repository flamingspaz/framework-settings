# Building from source

Framework settings includes a KDE/Qt 6 System Settings module, a standalone
Qt Quick application, and a Rust system service. By default all three are
built. The standalone application does not depend on the KCM or Plasma, but
uses ECM at build time and KDE Frameworks I18n at build and runtime for shared
translations.

## Requirements

- CMake 3.22 or newer and a C++20 compiler
- Qt 6.6 or newer (Core, DBus, Qml and Quick) for either UI; add Quick
  Controls 2 for the standalone application
- Extra CMake Modules (ECM) and KF6 I18n for either UI; KF6 CoreAddons and
  KCMUtils are additionally required for the KCM
- Rust and Cargo (the service is built with `cargo build --release --locked`)
- The native development libraries used by `framework_lib` (including hidapi,
  libusb and systemd)

On Fedora, install the build dependencies with:

```sh
sudo dnf install cmake extra-cmake-modules gcc-c++ cargo rust git pkgconf-pkg-config \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  kf6-kcmutils-devel kf6-kcoreaddons-devel kf6-ki18n-devel \
  hidapi-devel libusb1-devel systemd-devel
```

On Arch Linux:

```sh
sudo pacman -S --needed cmake extra-cmake-modules gcc rust git \
  qt6-base qt6-declarative kcmutils kcoreaddons ki18n kirigami \
  hidapi libusb systemd-libs
```

## Build Fedora RPMs locally with Anda

From the repository root, run the Git RPM build with Anda:

```sh
anda build -c terra-44-x86_64 framework-settings-git
```

The `framework-settings-git` project in `anda.hcl` uses
`packaging/fedora/framework-settings-git.spec` and packages the current Git source.
For the versioned RPM spec, use `anda build -c terra-44-x86_64 framework-settings`; that spec
builds the tagged source matching its `Version`. See
[Packaging](packaging.md) for the distro packaging overview.

The first daemon build downloads Rust crates and the `framework_lib` Git
repository, so it needs network access. Subsequent builds use Cargo's cache.

## Native build with CMake

Run these commands from the repository root. They use CMake directly; no
project-specific build wrapper is required.

```sh
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build build --parallel
```

To install into a temporary staging directory instead of the live system:

```sh
DESTDIR="$PWD/stage" cmake --install build
```

The staged files are under `stage/usr/`. To install directly to the system,
use `sudo cmake --install build` instead. If you install directly, reload the
service and D-Bus configuration and enable the daemon:

```sh
sudo systemctl daemon-reload
sudo systemctl reload dbus
sudo systemctl enable --now frameworkd
```

`KDE_INSTALL_USE_QT_SYS_PATHS=ON` installs the module under Qt's plugin
path, which is where Plasma 6 searches for KCMs. On Fedora this should place
the plugin at `/usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_framework.so`.

For UI-only work, configure with `-DBUILD_DAEMON=OFF`; that build will not
produce or install `frameworkd`, so skip the service commands above.

To build just the standalone Qt application on a system without KDE Plasma or
KCM libraries, turn off the KCM explicitly:

```sh
cmake -S . -B build-qt \
  -DBUILD_KCM=OFF -DBUILD_GUI=ON -DBUILD_DAEMON=OFF
cmake --build build-qt --target framework-settings
./build-qt/bin/framework-settings
```

The app uses the same `frameworkd` system service as the KCM, so that
service must be installed and running for hardware controls to work. With
`BUILD_KCM=OFF`, CPack names the standalone package `framework-gui`.

## Development shortcuts with just

The top-level `justfile` wraps the UI-only builds above for day-to-day work.
Run `just` to list the recipes:

- `just format` formats all tracked and untracked (non-ignored) `*.cpp`,
  `*.h` and `*.hpp` files with the repository's `.clang-format`;
  `just format-check` checks them without changing anything, as CI does. CI
  uses clang-format 22, so `clang-format-22` is used when installed; set
  `CLANG_FORMAT` to override.
- `just configure-kcm`, `just build-kcm`, `just run-kcm` and
  `just install-kcm` work on the KCM alone (`-DBUILD_KCM=ON -DBUILD_GUI=OFF
  -DBUILD_DAEMON=OFF`) in `build-kcm/`. `run-kcm` puts `build-kcm/bin` first in
  `QT_PLUGIN_PATH`, so `kcmshell6` loads the freshly built plugin even if
  another copy is installed.
- `just configure-gui`, `just build-gui`, `just run-gui` and
  `just install-gui` do the same for the standalone application
  (`-DBUILD_KCM=OFF -DBUILD_GUI=ON -DBUILD_DAEMON=OFF`) in `build-gui/`.
- `just release X.Y.Z` runs `scripts/release.sh X.Y.Z` to bump the version;
  see [releasing.md](releasing.md).

Build recipes configure first and run recipes build first. The run recipes
set `FRAMEWORK_KCM_FIXTURE=1`, so no daemon or hardware is needed, and take
an optional fixture model for `FRAMEWORK_KCM_FIXTURE_MODEL`, for example
`just run-gui framework-12`.

The builds default to `CMAKE_BUILD_TYPE=Debug` and
`CMAKE_INSTALL_PREFIX=/usr` with `CMAKE_EXPORT_COMPILE_COMMANDS=ON`; set the
`CMAKE_BUILD_TYPE` or `CMAKE_INSTALL_PREFIX` environment variables to change
them, for example `CMAKE_INSTALL_PREFIX="$HOME/.local" just install-gui`.
`KDE_INSTALL_USE_QT_SYS_PATHS` is left for ECM to choose on every configure:
it is on only when the prefix is Qt's own prefix (`/usr` on most
distributions), so the KCM plugin goes to Qt's system plugin directory, such
as `/usr/lib64/qt6/plugins`. With any other prefix every file, including the
plugin, stays under that prefix. Add the prefix's plugin directory (for
example `$HOME/.local/lib64/plugins`) to `QT_PLUGIN_PATH` to load a KCM
installed there.

The install recipes run `cmake --install`. They use `sudo` only if one of the
real install destinations (under `DESTDIR`, if set) is not writable; a
directory that does not exist yet is judged by its nearest existing parent,
so a new prefix in your home directory does not need `sudo`. A relative
`DESTDIR` is resolved from the directory `just` was run in, for example
`DESTDIR=stage just install-gui` stages into `./stage`.
With `BUILD_DAEMON=OFF` they still install the service's D-Bus, polkit and
systemd files, but not `frameworkd` itself.

## With Docker

`build.sh` is an optional wrapper that builds inside an Arch-based container,
so a host Rust toolchain is not needed. It uses the same CMake configure and
build steps and leaves the build directory mounted at the same path:

```sh
./build.sh
sudo cmake --install build
```

Pass CMake options through to the script, for example `./build.sh
-DBUILD_DAEMON=OFF`. The resulting binaries link against the libraries in the
container, so use a container matching the target distribution for packages
intended for distribution.

## Useful options

- `-DBUILD_KCM=OFF`: omit the KDE System Settings module; the standalone GUI
  still requires ECM at build time and KF6 I18n at build and runtime for shared
  translations. Use with `-DBUILD_GUI=ON` to build the desktop app without the
  KCM or Plasma libraries.
- `-DBUILD_GUI=OFF`: omit the standalone Qt desktop application.
- `-DBUILD_DAEMON=OFF`: do not build the system service, for example while
  working on either UI.
- `-DCMAKE_BUILD_TYPE=Debug`: make a debug build; `Release` or
  `RelWithDebInfo` are suitable for packaging.
- The daemon uses `cargo build --release --locked`. After changing Rust
  dependencies, run `cargo update` in `daemon/` to refresh `Cargo.lock`.

## Debugging the service

Talk to it directly:

```sh
busctl introspect io.github.frameworkkcm.Daemon1 /io/github/frameworkkcm/Daemon1
busctl call io.github.frameworkkcm.Daemon1 /io/github/frameworkkcm/Daemon1 \
    io.github.frameworkkcm.Daemon1 GetThermal
busctl call io.github.frameworkkcm.Daemon1 /io/github/frameworkkcm/Daemon1 \
    io.github.frameworkkcm.Daemon1 SetChargeLimit i 80
journalctl -u frameworkd
```

Run it in the foreground with more logging (stop the service first):

```sh
sudo systemctl stop frameworkd
sudo RUST_LOG=debug build/cargo/release/frameworkd
```

See [architecture.md](architecture.md) for the full D-Bus API.
