# CI and releases

See [Packaging](packaging.md) for local package build commands and an overview
of the Fedora, Arch, and Ubuntu packaging workflows.

GitHub Actions (`.github/workflows/build.yml`) builds and install-tests the
project in an Arch container on every push to `main` and on every pull
request. It also warns if `po/` is out of date with the source.

## Cutting a release

1. Run `scripts/release.sh <version>` (for example, `scripts/release.sh 0.2.0`),
   or the equivalent `just release <version>` (`just release 0.2.0`).
   It needs `appstreamcli` and `cargo`. Before changing anything, it checks
   that the version is greater than the current one, that every declaration
   it edits is present exactly once, and that the metainfo file has no entry
   for the version yet. It then updates:

   - `CMakeLists.txt` (`project(framework-kcm VERSION …)`) and
     `daemon/Cargo.toml`, the two versions CI checks against the tag;
   - `packaging/fedora/framework-settings.spec` (`Version:`), resetting
     `Release:` to `1`;
   - `packaging/fedora/framework-settings-git.spec` (`%global _version`);
   - `packaging/arch/PKGBUILD` (`pkgver`), resetting `pkgrel` to `1`;
   - `packaging/nix/packages/default.nix` (`version`);
   - `data/com.github.framework-settings.metainfo.xml`, adding
     `<release version="…" date="…" />` with today's date as the first entry
     in `<releases>`, then checking the file with
     `appstreamcli validate --no-net`;
   - `daemon/Cargo.lock`, through `cargo update --workspace`.

   The Debian packages take their version from CMake. The script backs up
   every file first, so if any step fails or you interrupt it, it restores
   them and leaves the files unchanged.

   The script doesn't write release notes. If you want release notes in
   software centres, add a `<description>` inside the new metainfo
   `<release>` entry by hand. Review the changes and commit.
2. Tag the commit and push the tag:

   ```sh
   git tag -a v0.2.0 -m "framework-kcm 0.2.0"
   git push origin v0.2.0
   ```

On a `v*` tag, the workflow:

1. Checks that the tag matches both versions, and stops if it doesn't.
2. Builds the packages in parallel:

   | Distribution | Packages                                                                                 | Built with                              |
   | ------------ | ---------------------------------------------------------------------------------------- | --------------------------------------- |
   | Arch Linux   | `framework-settings`, `framework-gui`, `framework-kcm`, `framework-settings-translations`, and `frameworkd` | `packaging/arch/PKGBUILD` and `makepkg` |
   | Ubuntu 26.04 | `framework-settings`, `framework-gui`, `framework-kcm`, `framework-settings-translations`, and `frameworkd` `.deb` packages | CPack (`packaging/cpack.cmake`) |

3. Creates a GitHub release for the tag, attaches all package files, and writes
   release notes from the commits since the last tag.

## Packaging notes

- **Arch:** CI builds the `PKGBUILD` from a `git archive` tarball and fills in
  `pkgver` and `url`. LTO is turned off (`options=('!lto')`) because GCC LTO
  objects from hidapi's bundled C code can't be read by the linker cargo
  uses. The `-debug` split package isn't attached to releases.
  `frameworkd.install` reminds the user to enable the service. The release
  contains the `framework-settings` meta-package and separate GUI, KCM,
  translations, and daemon packages.
- **Ubuntu:** `dpkg-shlibdeps` works out the library dependencies. The QML
  modules and services needed only at runtime are listed by hand in
  `packaging/cpack.cmake`. The maintainer scripts in `packaging/debian/`
  enable the service on install, disable it on removal, and delete
  `/var/lib/frameworkd` on purge.
