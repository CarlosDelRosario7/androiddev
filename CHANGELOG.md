# Changelog

Todas las versiones notables de este proyecto se documentan aquí.

## [1.0.0] - 2026-11-02

### Añadido

- CLI `androiddev` con menú interactivo.
- Comandos `doctor`, `new`, `build`, `shell`, `config` y `env`.
- Detección de distro y gestor de paquetes: apt, dnf/yum, pacman, zypper, apk,
  xbps, emerge y nix.
- Detección de JDK 21 por validación, sin rutas hardcodeadas.
- Detección de Android SDK, `local.properties` y licencias.
- Creación de proyectos Capacitor 7 con slugify y App ID validado.
- Compilación debug con JDK 21 aislado y copia del APK al escritorio.
- Integración idempotente con `.bashrc`/`.zshrc`, con `ZDOTDIR` y symlinks.
- Instalador y desinstalador sin `sudo`.
- README en español e inglés, pruebas en Bash puro y CI con ShellCheck.

[1.0.0]: https://github.com/CarlosDelRosario7/androiddev/releases/tag/v1.0.0
