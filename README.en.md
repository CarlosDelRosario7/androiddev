# androiddev

**English** · [Español](README.md)

[![CI](https://github.com/CarlosDelRosario7/androiddev/actions/workflows/ci.yml/badge.svg)](https://github.com/CarlosDelRosario7/androiddev/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

A command-line tool to create and build Android apps with
[Capacitor](https://capacitorjs.com/) on any Linux distribution. It includes an
interactive menu, environment detection and optional `.bashrc`/`.zshrc`
integration.

```text
androiddev
  1) Diagnose the system
  2) Create a Capacitor project
  3) Build a debug APK
  4) Install into .bashrc / .zshrc
  5) Remove from .bashrc / .zshrc
  6) Show detected configuration
  7) Help
  0) Exit
```

## Requirements

- Linux (native; WSL is experimental).
- Bash 4 or newer.
- Node.js 20 or newer and npm.
- JDK 21.
- Android SDK with `cmdline-tools`, `platform-tools`, `platforms;android-35`
  and `build-tools;35.0.0`.
- `curl` and `unzip` are optional.

`androiddev` **does not install dependencies automatically and never uses
`sudo`**. `doctor` detects what is missing and prints the right command for your
distribution.

## Installation

```bash
git clone https://github.com/CarlosDelRosario7/androiddev.git
cd androiddev
./install.sh
```

The installer asks whether to add shell integration to `.bashrc`, `.zshrc`,
both, or neither. It installs into `~/.local/share/androiddev` and creates the
`~/.local/bin/androiddev` symlink.

If `~/.local/bin` is not in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Installer options:

```bash
./install.sh --prefix "$HOME/.local" --shell both
./install.sh --shell none
./install.sh --yes
```

Uninstall:

```bash
./uninstall.sh
./uninstall.sh --remove-config --yes
```

## Quick start

```bash
androiddev                    # interactive menu
androiddev doctor             # environment check
androiddev new my-app         # create a project
cd my-app
androiddev build              # build a debug APK
```

The APK is copied to the desktop directory reported by
`xdg-user-dir DESKTOP` (for example `~/Desktop` or `~/Escritorio`). Existing
files are not overwritten silently; a timestamp is added instead.

### Create a project

```bash
androiddev new my-app
androiddev new "My App" --dir ./projects/my-app
androiddev new my-app --app-id com.example.myapp
androiddev new my-app --no-install
```

`new` creates `package.json`, `capacitor.config.json`, `www/index.html`,
installs Capacitor 7 and adds the Android platform. The default app ID is
`com.example.<slug>`; change it before publishing.

### Build

```bash
androiddev build
androiddev build --project ./my-app
androiddev build --out ~/Downloads
androiddev build --no-copy
androiddev build --force
```

The build always uses JDK 21, even if the system `java` is a different version.
It does not modify `gradle.properties`; it only sets `JAVA_HOME` for the Gradle
process. If `android/local.properties` is missing, it writes `sdk.dir` from the
detected SDK.

### Diagnostics

```bash
androiddev doctor
```

Checks the distribution, package manager, Node, npm, JDK 21, SDK, `sdkmanager`,
licenses, `adb`, `curl` and `unzip`. It exits with status 1 if something
essential is missing.

### Shell integration

```bash
androiddev shell install --shell bash
androiddev shell install --shell zsh
androiddev shell install --shell both
androiddev shell status
androiddev shell remove --shell bash
```

The managed block is idempotent and delimited by markers:

```bash
# >>> androiddev >>>
...
# <<< androiddev <<<
```

It exports `ANDROID_HOME`, `ANDROID_SDK_ROOT`, adds `platform-tools` to `PATH`
and defines the `crear_apk` and `compila_apk` aliases:

```bash
crear_apk my-app
cd my-app
compila_apk
```

It respects `ZDOTDIR` and symlinked shell configuration files.

### Configuration

```bash
androiddev config show
androiddev config set sdk ~/Android/Sdk
androiddev config set java ~/jdk-21
androiddev config set output ~/Downloads
androiddev config unset output
```

Configuration lives in `~/.config/androiddev/config` (or
`$XDG_CONFIG_HOME/androiddev/config`).

Useful variables:

| Variable | Purpose |
|---|---|
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | Android SDK path |
| `ANDROIDDEV_SDK_DIR` | androiddev-specific SDK path |
| `ANDROIDDEV_JAVA_HOME` | Explicit JDK 21 path |
| `ANDROIDDEV_OUTPUT_DIR` | APK output directory |
| `ANDROIDDEV_CAPACITOR_VERSION` | Only `7` is supported for now |
| `NO_COLOR` | Disable colors |

## Distributions

`doctor` recognizes the most common package managers and prints the right
command:

| Family | Manager | Example |
|---|---|---|
| Debian/Ubuntu/Kali | `apt` | `sudo apt install openjdk-21-jdk nodejs npm` |
| Fedora/RHEL | `dnf` / `yum` | `sudo dnf install java-21-openjdk-devel nodejs npm` |
| Arch/Manjaro | `pacman` | `sudo pacman -S jdk21-openjdk nodejs npm` |
| openSUSE | `zypper` | `sudo zypper install java-21-openjdk-devel nodejs npm` |
| Alpine | `apk` | `sudo apk add openjdk21 nodejs npm` |
| Void | `xbps` | `sudo xbps-install openjdk21 nodejs npm` |
| Gentoo | `emerge` | `sudo emerge dev-java/openjdk-bin:21 net-libs/nodejs` |
| NixOS | `nix-env` | `nix-env -iA nixpkgs.jdk21 nixpkgs.nodejs_22` |

Notes:

- **Alpine/musl**: Android SDK tools are glibc binaries; `gcompat` may be
  required and support is not guaranteed.
- **ARM64**: some `cmdline-tools` packages are not available for ARM. `doctor`
  warns when it detects an unsupported architecture.
- **NixOS**: FHS paths do not exist; set `ANDROID_HOME` and use a Nix JDK.
- **WSL**: experimental; native Linux is the supported target.

## Troubleshooting

### JDK 21 not found

```bash
sudo apt install openjdk-21-jdk          # Debian/Ubuntu/Kali
sudo dnf install java-21-openjdk-devel   # Fedora
sudo pacman -S jdk21-openjdk             # Arch
```

Or point androiddev to a custom JDK:

```bash
export ANDROIDDEV_JAVA_HOME=/path/to/jdk-21
```

### SDK licenses

```bash
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses
```

### Missing `platforms;android-35` or `build-tools;35.0.0`

```bash
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

Gradle can also download them automatically when licenses are accepted.

### `androiddev: command not found`

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add it to your shell configuration or run `androiddev shell install`.

### The first build is slow

Gradle downloads its wrapper, the Android Gradle Plugin and Capacitor
dependencies on the first build. Later builds are incremental.

## Development

```bash
./tests/run-tests.sh
shellcheck -x -S warning bin/androiddev install.sh uninstall.sh lib/*.sh tests/run-tests.sh
```

Layout:

```text
bin/androiddev        Entry point
lib/                  System, Java, SDK, project, build, shell and menu modules
templates/            Initial web template
tests/                Plain Bash tests
legacy/setup-android.sh  Original script, kept for reference
```

CI runs ShellCheck, the test suite and a distribution-detection smoke test in
Debian, Fedora, Arch and openSUSE containers.

## License

Copyright (C) 2026 Carlos Del Rosario.

Released under the **GNU General Public License v3.0 or later**. See
[LICENSE](LICENSE).
