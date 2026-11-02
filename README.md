# androiddev

[English](README.en.md) · **Español**

[![CI](https://github.com/CarlosDelRosario7/androiddev/actions/workflows/ci.yml/badge.svg)](https://github.com/CarlosDelRosario7/androiddev/actions/workflows/ci.yml)
[![Licencia: GPL-3.0](https://img.shields.io/badge/licencia-GPL--3.0-blue.svg)](LICENSE)

Herramienta de línea de comandos para crear y compilar aplicaciones Android con
[Capacitor](https://capacitorjs.com/) en cualquier distribución de Linux. Incluye
un menú interactivo, detección del entorno y una integración opcional con
`.bashrc` y `.zshrc`.

```text
androiddev
  1) Diagnosticar el sistema
  2) Crear proyecto Capacitor
  3) Compilar APK debug
  4) Instalar en .bashrc / .zshrc
  5) Quitar de .bashrc / .zshrc
  6) Ver configuración detectada
  7) Ayuda
  0) Salir
```

## Requisitos

- Linux (nativo; WSL funciona de forma experimental).
- Bash 4 o superior.
- Node.js 20 o superior y npm.
- JDK 21.
- SDK de Android con `cmdline-tools`, `platform-tools`, `platforms;android-35`
  y `build-tools;35.0.0`.
- `curl` y `unzip` son opcionales; se usan para tareas de Android Studio y del SDK.

`androiddev` **no instala dependencias automáticamente ni usa `sudo`**. El comando
`doctor` detecta lo que falta y muestra el comando adecuado para tu distribución.

## Instalación

```bash
git clone https://github.com/CarlosDelRosario7/androiddev.git
cd androiddev
./install.sh
```

El instalador pregunta si quieres añadir la integración a `.bashrc`, `.zshrc`,
ambos o ninguno. Instala en `~/.local/share/androiddev` y crea el enlace
`~/.local/bin/androiddev`. No usa `sudo`.

Si `~/.local/bin` no está en tu `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Opciones del instalador:

```bash
./install.sh --prefix "$HOME/.local" --shell both
./install.sh --shell none          # no toca ningún archivo de shell
./install.sh --yes                 # sin preguntas
```

Para desinstalar:

```bash
./uninstall.sh
./uninstall.sh --remove-config --yes
```

## Uso rápido

```bash
androiddev                    # menú interactivo
androiddev doctor             # diagnóstico del entorno
androiddev new mi-app         # crear proyecto
cd mi-app
androiddev build              # compilar APK debug
```

El APK se copia al escritorio detectado por `xdg-user-dir DESKTOP` (por ejemplo
`~/Escritorio` o `~/Desktop`). Si ya existe un APK con ese nombre, se añade la
fecha y la hora para no sobrescribirlo.

### Crear un proyecto

```bash
androiddev new mi-app
androiddev new "Mi App" --dir ./proyectos/mi-app
androiddev new mi-app --app-id com.midominio.miapp
androiddev new mi-app --no-install
```

`new` crea `package.json`, `capacitor.config.json`, `www/index.html`, instala
Capacitor 7 y añade la plataforma Android. El App ID por defecto es
`com.example.<slug>`; cámbialo antes de publicar en Google Play.

### Compilar

```bash
androiddev build
androiddev build --project ./mi-app
androiddev build --out ~/Descargas
androiddev build --no-copy
androiddev build --force
```

El build usa JDK 21 aunque tu `java` del sistema sea otra versión. No modifica
`gradle.properties`; solo define `JAVA_HOME` para el proceso de Gradle. Si falta
`android/local.properties`, escribe `sdk.dir` con el SDK detectado.

### Diagnóstico

```bash
androiddev doctor
```

Comprueba distro, gestor de paquetes, Node, npm, JDK 21, SDK, `sdkmanager`,
licencias, `adb`, `curl` y `unzip`. Devuelve código de salida 1 si falta algo
imprescindible.

### Integración con el shell

```bash
androiddev shell install --shell bash
androiddev shell install --shell zsh
androiddev shell install --shell both
androiddev shell status
androiddev shell remove --shell bash
```

El bloque es idempotente y está delimitado por marcadores:

```bash
# >>> androiddev >>>
...
# <<< androiddev <<<
```

Añade `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `platform-tools` al `PATH` y define los
aliases `crear_apk` y `compila_apk`:

```bash
crear_apk mi-app
cd mi-app
compila_apk
```

El bloque también respeta `ZDOTDIR` y los enlaces simbólicos de los archivos de
configuración (útil si gestionas tus dotfiles con un repositorio).

### Configuración

```bash
androiddev config show
androiddev config set sdk ~/Android/Sdk
androiddev config set java ~/jdk-21
androiddev config set output ~/Descargas
androiddev config unset output
```

La configuración se guarda en `~/.config/androiddev/config` (o
`$XDG_CONFIG_HOME/androiddev/config`). Las variables de entorno y las opciones
de línea de comandos tienen prioridad.

Variables útiles:

| Variable | Uso |
|---|---|
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | Ruta del SDK |
| `ANDROIDDEV_SDK_DIR` | Ruta del SDK específica para androiddev |
| `ANDROIDDEV_JAVA_HOME` | Ruta explícita a un JDK 21 |
| `ANDROIDDEV_OUTPUT_DIR` | Carpeta de salida de los APK |
| `ANDROIDDEV_CAPACITOR_VERSION` | Solo se admite `7` por ahora |
| `NO_COLOR` | Desactiva colores |

## Distribuciones

`doctor` reconoce los gestores de paquetes más habituales y muestra el comando
correspondiente:

| Familia | Gestor | Ejemplos |
|---|---|---|
| Debian/Ubuntu/Kali | `apt` | `sudo apt install openjdk-21-jdk nodejs npm` |
| Fedora/RHEL | `dnf` / `yum` | `sudo dnf install java-21-openjdk-devel nodejs npm` |
| Arch/Manjaro | `pacman` | `sudo pacman -S jdk21-openjdk nodejs npm` |
| openSUSE | `zypper` | `sudo zypper install java-21-openjdk-devel nodejs npm` |
| Alpine | `apk` | `sudo apk add openjdk21 nodejs npm` |
| Void | `xbps` | `sudo xbps-install openjdk21 nodejs npm` |
| Gentoo | `emerge` | `sudo emerge dev-java/openjdk-bin:21 net-libs/nodejs` |
| NixOS | `nix-env` | `nix-env -iA nixpkgs.jdk21 nixpkgs.nodejs_22` |

Notas:

- **Alpine/musl**: las herramientas del SDK de Android son binarios glibc; puede
  hacer falta `gcompat` y el soporte no está garantizado.
- **ARM64**: algunos paquetes de `cmdline-tools` no están disponibles para ARM.
  `doctor` avisa si detecta una arquitectura no soportada.
- **NixOS**: las rutas FHS no existen; usa `ANDROID_HOME` y un JDK de Nix.
- **WSL**: funciona de forma experimental; el soporte oficial es Linux nativo.

## Solución de problemas

### No se encuentra JDK 21

```bash
sudo apt install openjdk-21-jdk       # Debian/Ubuntu/Kali
sudo dnf install java-21-openjdk-devel # Fedora
sudo pacman -S jdk21-openjdk          # Arch
```

Si lo tienes en una ruta no habitual:

```bash
export ANDROIDDEV_JAVA_HOME=/ruta/al/jdk-21
```

### Licencias del SDK

```bash
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses
```

### Falta `platforms;android-35` o `build-tools;35.0.0`

```bash
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

Gradle también puede descargarlos automáticamente si las licencias están
aceptadas.

### `androiddev: command not found`

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Añádelo a tu `.bashrc` o `.zshrc`, o instala la integración con
`androiddev shell install`.

### El primer build tarda mucho

Gradle descarga el wrapper, el Android Gradle Plugin y las dependencias de
Capacitor en la primera compilación. Los siguientes builds son incrementales.

### Quiero borrar todo

```bash
./uninstall.sh --remove-config --yes
```

## Desarrollo

```bash
./tests/run-tests.sh
shellcheck -x -S warning bin/androiddev install.sh uninstall.sh lib/*.sh tests/run-tests.sh
```

Estructura:

```text
bin/androiddev        Punto de entrada
lib/                  Módulos: sistema, Java, SDK, proyecto, build, shell, menú
templates/            Plantilla web inicial
tests/                Pruebas en Bash puro
legacy/setup-android.sh  Script original, conservado como referencia
```

La integración continua ejecuta ShellCheck, las pruebas y una comprobación de
detección de distro en contenedores Debian, Fedora, Arch y openSUSE.

## Licencia

Copyright (C) 2026 Carlos Del Rosario.

Este proyecto se distribuye bajo la **GNU General Public License v3.0 o
posterior**. Consulta [LICENSE](LICENSE).
