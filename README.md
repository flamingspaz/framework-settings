# Framework Settings

Framework laptop settings, in KDE System Settings or as a standalone app:
battery charge limits, fans and temperatures, fingerprint LED and haptic
touchpad settings, and firmware and USB-C port information.

| Battery                          | Thermals                           |
| -------------------------------- | ---------------------------------- |
| ![Battery tab](docs/battery.png) | ![Thermals tab](docs/thermals.png) |
| **Input**                        | **System**                         |
| ![Input tab](docs/touchpad.png)  | ![System tab](docs/system.png)     |

## Features

- **Overview:** a read-only summary of battery, temperatures, fans,
  throttling and firmware, with hardware controls kept on their dedicated tabs.
- **Battery:** set a charge limit, charge to 100% once with _Override Charge
  Limit_ (the limit comes back after the next restart), and slow down
  charging to reduce heat and battery wear.
- **Schedule:** apply different charge limits on selected weekdays and times
  using user systemd timers. Scheduling requires the Framework System
  command-line tools.
- **Thermals:** live temperatures, fan speed and throttling status.
  Leave the fans on automatic, or fix their speed.
- **Input:** fingerprint reader LED brightness, and haptic touchpad
  feedback strength and click force.
- **System:** model, BIOS, EC and PD controller firmware versions, camera and
  microphone privacy switches, and what's connected to each USB-C port.

It's built on Framework's own
[`framework_lib`](https://github.com/FrameworkComputer/framework-system).

## Supported hardware

Developed and tested on the **Framework Laptop 13 Pro (Intel Core Ultra
Series 3)**. Other Framework laptops use the same embedded controller
interface, so most features should work there too, but they haven't been
tested.

The System Settings module requires KDE Plasma 6. A separate desktop app,
`framework-settings`, is also provided for other desktop environments. It shows
the same pages as the module, so it uses Qt Quick Controls, KDE Frameworks
Kirigami and I18n, but does not need KCMUtils or Plasma.
It follows Qt Quick Controls' configured style (including KDE's); on Linux
with no style configured, Qt defaults to the desktop-oriented Fusion style.

## Install

Download the packages for your distribution from the
[latest release](https://github.com/flamingspaz/framework-settings/releases/latest).

### Which packages

The Arch, Ubuntu and Fedora releases are split into several packages (the
tarball and NixOS installs below cover everything). Every install needs the
two base packages, plus at least one of the interfaces:

| Package                           | What it is                                                     |
| --------------------------------- | -------------------------------------------------------------- |
| `frameworkd`                      | **Base.** The system service that talks to the hardware        |
| `framework-settings-translations` | **Base.** Translations shared by both interfaces               |
| `framework-kcm`                   | The KDE System Settings module, for Plasma                     |
| `framework-gui`                   | The standalone **Framework Settings** app, for other desktops  |
| `framework-settings`              | Meta-package that installs all of the above                    |

So install the base packages with `framework-kcm` on KDE Plasma, or with
`framework-gui` on other desktops (or both, or just `framework-settings`).
From a repository, installing `framework-kcm` or `framework-gui` pulls in the
base packages for you; when installing downloaded package files, include the
base packages' files too, as in the commands below.

### Tarball (other distributions)

For distributions without a package, each release also has a
`framework-kcm-<version>-x86_64.tar.gz` holding a prebuilt `usr/` tree. It
needs glibc 2.39 or newer, Qt 6.10 or newer, KF6 (KCMUtils, Kirigami,
CoreAddons, I18n), polkit, D-Bus and systemd.

```bash
$ sudo tar -C / --no-same-owner -xzf framework-kcm-<version>-x86_64.tar.gz
$ sudo systemctl daemon-reload
```

The KCM is installed to `/usr/lib/qt6/plugins`. If
`qtpaths6 --query QT_INSTALL_PLUGINS` prints a different directory (for
example `/usr/lib64/qt6/plugins`), move `plasma/kcms/systemsettings/kcm_framework.so`
there.

To uninstall, stop the service and remove the files the tarball installed:

```bash
$ sudo systemctl disable --now frameworkd
$ tar -tzf framework-kcm-<version>-x86_64.tar.gz | grep -v '/$' | sed 's|^|/|' | sudo xargs rm -f
```

### NixOS (Flakes)

This project can be used by adding this repository as a flakes input
and using the provided NixOS module. The `stable` branch tracks the latest
release; use `main` instead for development builds. Below is a basic
`flake.nix` example:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    framework-settings = {
      url = "github:flamingspaz/framework-settings/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, framework-settings, ... }: {
    nixosConfigurations = {
      yourHost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hardware-configuration.nix
          framework-settings.nixosModules.framework-settings
          { programs.framework-settings.enable = true; }
          # rest of your system configuration here.
        ];
      };
    };
  };
}
```

To install only the standalone GUI without the KCM, add a module function to
the Flake example's `modules` list and override the package with
`withKcm = false`:

```nix
{ pkgs, ... }:
let
  packages = framework-settings.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.framework-settings.package = packages.framework-settings.override {
    withGui = true;
    withKcm = false;
  };
}
```

### NixOS (nix-channel)

For non-Flake configs, you can add this repository as a channel on your system.

```bash
$ sudo nix-channel --add https://github.com/flamingspaz/framework-settings/archive/stable.tar.gz framework-settings
$ sudo nix-channel --update
```

After adding the channel, you can add the following to your `configuration.nix`:

```nix
{ config, pkgs, ...}:
let
  framework-settings = import <framework-settings> { inherit pkgs; };
in
{
  imports = [
    ./hardware-configuration.nix
    framework-settings.nixosModules.framework-settings
  ];
  programs.framework-settings.enable = true;
  # rest of your system configuration here.
}
```

To install only the standalone GUI without the KCM, override the
`framework-settings` package in your `configuration.nix` with
`withKcm = false`:

```nix
programs.framework-settings.package = framework-settings.packages.framework-settings.override {
  withGui = true;
  withKcm = false;
};
```

### Arch Linux

```sh
# KDE Plasma: base packages + System Settings module
sudo pacman -U frameworkd-*.pkg.tar.zst framework-settings-translations-*.pkg.tar.zst framework-kcm-*.pkg.tar.zst

# Other desktops: base packages + standalone app
sudo pacman -U frameworkd-*.pkg.tar.zst framework-settings-translations-*.pkg.tar.zst framework-gui-*.pkg.tar.zst

# Everything, including the framework-settings meta-package
sudo pacman -U framework-*.pkg.tar.zst frameworkd-*.pkg.tar.zst
```

Then enable the service so settings are re-applied at boot:

```sh
sudo systemctl enable --now frameworkd
```

### Ubuntu 26.04

```sh
# KDE Plasma: base packages + System Settings module
sudo apt install ./frameworkd_*.deb ./framework-settings-translations_*.deb ./framework-kcm_*.deb

# Other desktops: base packages + standalone app
sudo apt install ./frameworkd_*.deb ./framework-settings-translations_*.deb ./framework-gui_*.deb

# Everything, including the framework-settings meta-package
sudo apt install ./framework-*.deb ./frameworkd_*.deb
```

The `frameworkd` package configures and enables the background service.

### Fedora

The packages are available in [Terra](https://terrapkg.com). dnf pulls in the
base packages automatically:

```sh
# KDE Plasma: System Settings module
sudo dnf install framework-kcm

# Other desktops: standalone app
sudo dnf install framework-gui

# Everything
sudo dnf install framework-settings
```

Then open **System Settings → System → Framework Laptop**, or run
`kcmshell6 kcm_framework`. On non-KDE desktops, launch **Framework Settings**
or run `framework-settings`.

The `frameworkd` service starts on its own when you open the settings
page. Enabling it also starts it at boot, so settings the hardware forgets
(touchpad feedback, click force, charge speed) are applied again after a
restart.

For a repository-managed installation, remove only the package you
explicitly installed (`framework-settings` for the full suite, or
`framework-kcm` or `framework-gui` for a single interface). Let the package manager remove
unneeded dependencies with `sudo pacman -Rns <package>` on Arch or
`sudo apt remove <package> && sudo apt autoremove` on Debian-based systems.

When installing the release files directly with `pacman -U` or from local
`.deb` files using `apt install`, every package you listed may be marked as
explicitly installed. Remove all of them; for the full suite:

```sh
# Arch Linux
sudo pacman -Rns framework-settings framework-gui framework-kcm framework-settings-translations frameworkd

# Debian-based systems
sudo apt remove framework-settings framework-gui framework-kcm framework-settings-translations frameworkd
```

Removing `frameworkd` also deletes the settings it re-applies at boot
(`/var/lib/frameworkd`) on Arch and Fedora. Debian-based systems keep them
until you purge the package (`sudo apt purge frameworkd`). Charge schedules
live in your home directory, so turn them off on the **Schedule** tab before
uninstalling, or they keep running.

## Fixture mode

To preview either UI without Framework hardware or the daemon, launch it with
fixture mode enabled. Readings are simulated, setting changes stay in memory,
and scheduling does not create systemd units:

```sh
FRAMEWORK_KCM_FIXTURE=1 kcmshell6 kcm_framework
FRAMEWORK_KCM_FIXTURE=1 ./build-qt/bin/framework-settings
```

The Overview tab lets you choose a hardware profile for testing model-specific
controls. You can also pick a profile at launch:

```sh
FRAMEWORK_KCM_FIXTURE=1 FRAMEWORK_KCM_FIXTURE_MODEL=framework-12 kcmshell6 kcm_framework
FRAMEWORK_KCM_FIXTURE=1 FRAMEWORK_KCM_FIXTURE_MODEL=framework-12-gen2 kcmshell6 kcm_framework
FRAMEWORK_KCM_FIXTURE=1 FRAMEWORK_KCM_FIXTURE_MODEL=framework-13 kcmshell6 kcm_framework
FRAMEWORK_KCM_FIXTURE=1 FRAMEWORK_KCM_FIXTURE_MODEL=framework-13-pro kcmshell6 kcm_framework
```

The same `FRAMEWORK_KCM_FIXTURE_MODEL` values work with the standalone GUI.

## Permissions

Changing hardware settings needs root, so a small system service does it on
the settings page's behalf. Whether you're asked for a password:

| Setting                      | Password?                              |
| ---------------------------- | -------------------------------------- |
| Battery charging             | No                                     |
| Touchpad and fingerprint LED | No                                     |
| Fan control                  | Yes, then remembered for a few minutes |

Fan control asks because a fixed fan speed can let the laptop run hot. The
embedded controller still shuts the laptop down before it overheats, and the
fans go back to automatic when the service stops or the laptop restarts.

When you're logged in remotely (over SSH, for example), every change asks
for an administrator password.

## Things to know

- **The charge limit slider is temporary.** Plasma's Power Management page
  doesn't expose the Framework 13 Pro charge limit correctly yet, so this
  module provides one for now. Once Plasma does, the slider will be removed
  from here. Until then, both write the same EC setting, so set the limit in
  only one place.
- Haptic and click force settings only apply to the haptic touchpads found
  on the 13 Pro Input Cover.
- Keyboard backlight is left to Plasma, which drives it through `cros_kbd_led_backlight`.
- USB-C port names follow `framework_tool --pdports`.

## Languages

The KCM and standalone `framework-settings` app use the same KI18n catalogs,
so their UI follows your language and is available in English, Dutch, German,
Spanish and French. The non-English translations were machine-generated and
haven't been reviewed by native speakers yet, so corrections are welcome.
See [docs/translations.md](docs/translations.md).

## Documentation

- [How it works](docs/architecture.md): the settings page, the system
  service, and its D-Bus API
- [Building from source](docs/building.md), and debugging the service
- [Packaging](docs/packaging.md): local RPM builds with Anda and distro
  packaging workflows
- [Releasing](docs/releasing.md): CI and cutting a release
- [Translations](docs/translations.md): updating or adding a language

## License

Framework Settings is free software, licensed under the GNU General Public
License version 3 or (at your option) any later version. See
[LICENSE](LICENSE).

It uses [`framework_lib`](https://github.com/FrameworkComputer/framework-system),
which is BSD-3-Clause licensed. The icon is the cog from the Framework
Computer logo. The logo itself is in the public domain, but "Framework" is a
trademark of Framework Computer Inc., and this project isn't affiliated with
them.
