#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Pruebas básicas sin dependencias externas.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export ANDROIDDEV_ROOT="$ROOT"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
unset ANDROIDDEV_JAVA_HOME ANDROIDDEV_SDK_DIR ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME ZDOTDIR

# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"
# shellcheck source=../lib/os.sh
. "$ROOT/lib/os.sh"
# shellcheck source=../lib/java.sh
. "$ROOT/lib/java.sh"
# shellcheck source=../lib/sdk.sh
. "$ROOT/lib/sdk.sh"
# shellcheck source=../lib/project.sh
. "$ROOT/lib/project.sh"
# shellcheck source=../lib/shell.sh
. "$ROOT/lib/shell.sh"

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'not ok - %s\n' "$1"
}

assert_eq() {
    local description="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$description"
    else
        fail "$description (esperado: '$expected', obtenido: '$actual')"
    fi
}

assert_file() {
    if [ -f "$2" ]; then pass "$1"; else fail "$1 (falta $2)"; fi
}

assert_no_file() {
    if [ ! -e "$2" ]; then pass "$1"; else fail "$1 (existe $2)"; fi
}

assert_contains() {
    local description="$1" file="$2" text="$3"
    if grep -qF "$text" "$file"; then
        pass "$description"
    else
        fail "$description (no contiene '$text')"
    fi
}

# --- slugify y appId ---
assert_eq "slugify_pkg con acentos" "mi_app_nandu" "$(slugify_pkg 'Mi App Ñandú')"
assert_eq "slugify_file con acentos" "mi-app-nandu" "$(slugify_file 'Mi App Ñandú')"
assert_eq "slugify_pkg con número inicial" "app_3d" "$(slugify_pkg '3D')"
assert_eq "slugify_pkg con palabra reservada" "app_new" "$(slugify_pkg 'new')"
assert_eq "appId válido" "0" "$(validate_app_id 'com.example.mi_app' && echo 0 || echo 1)"
assert_eq "appId con mayúsculas inválido" "1" "$(validate_app_id 'Com.Example.App' && echo 0 || echo 1)"
assert_eq "appId de un solo segmento inválido" "1" "$(validate_app_id 'com' && echo 0 || echo 1)"
assert_eq "appId con palabra reservada inválido" "1" "$(validate_app_id 'com.example.new' && echo 0 || echo 1)"

# --- Java ---
fake21="$TMP/jdk21"
mkdir -p "$fake21/bin"
cat >"$fake21/bin/java" <<'EOF'
#!/bin/sh
echo 'openjdk version "21.0.5" 2024-10-15' >&2
EOF
chmod +x "$fake21/bin/java"

fake25="$TMP/jdk25"
mkdir -p "$fake25/bin"
cat >"$fake25/bin/java" <<'EOF'
#!/bin/sh
echo 'openjdk version "25.0.1" 2025-10-21' >&2
EOF
chmod +x "$fake25/bin/java"

assert_eq "java_version_of 21" "21" "$(java_version_of "$fake21/bin/java")"
assert_eq "java_version_of 25" "25" "$(java_version_of "$fake25/bin/java")"
assert_eq "find_jdk21 encuentra el JDK 21" "$fake21" "$(ANDROIDDEV_JAVA_HOME="$fake21" find_jdk21)"
result_25="$(ANDROIDDEV_JAVA_HOME="$fake25" find_jdk21 2>/dev/null || true)"
if [ "$result_25" != "$fake25" ]; then
    pass "find_jdk21 no devuelve el JDK 25"
else
    fail "find_jdk21 no devuelve el JDK 25"
fi

# --- SDK falso para pruebas de shell ---
fake_sdk="$TMP/android-sdk"
mkdir -p "$fake_sdk/platform-tools" "$fake_sdk/build-tools/35.0.0" "$fake_sdk/platforms/android-35" "$fake_sdk/licenses"
printf 'licencia\n' >"$fake_sdk/licenses/android-sdk-license"
touch "$fake_sdk/platform-tools/adb"
export ANDROIDDEV_SDK_DIR="$fake_sdk"
assert_eq "find_android_sdk encuentra el SDK falso" "$fake_sdk" "$(find_android_sdk)"
assert_eq "sdk_has_licenses" "0" "$(sdk_has_licenses "$fake_sdk" && echo 0 || echo 1)"

# --- Bloque de shell ---
printf 'sentinel-bash\n' >"$HOME/.bashrc"
cmd_shell_install --shell bash >/dev/null 2>&1
assert_eq "instala el bloque en bash" "1" "$(grep -c '^# >>> androiddev >>>' "$HOME/.bashrc")"
assert_contains "conserva el contenido previo" "$HOME/.bashrc" "sentinel-bash"

cmd_shell_install --shell bash >/dev/null 2>&1
assert_eq "no duplica el bloque" "1" "$(grep -c '^# >>> androiddev >>>' "$HOME/.bashrc")"

cmd_shell_remove --shell bash >/dev/null 2>&1
assert_eq "quita el bloque" "0" "$(grep -c '^# >>> androiddev >>>' "$HOME/.bashrc" || true)"
assert_contains "conserva el contenido al quitar" "$HOME/.bashrc" "sentinel-bash"

printf 'sentinel-real\n' >"$HOME/.zshrc.real"
ln -s .zshrc.real "$HOME/.zshrc"
cmd_shell_install --shell zsh >/dev/null 2>&1
if [ -L "$HOME/.zshrc" ]; then pass "respeta el symlink de .zshrc"; else fail "respeta el symlink de .zshrc"; fi
assert_contains "escribe en el destino del symlink" "$HOME/.zshrc.real" "# >>> androiddev >>>"
cmd_shell_remove --shell zsh >/dev/null 2>&1
assert_contains "conserva el destino del symlink" "$HOME/.zshrc.real" "sentinel-real"
rm -f "$HOME/.zshrc" "$HOME/.zshrc.real"

# --- Proyecto ---
mkdir -p "$TMP/proj/sub/dir"
touch "$TMP/proj/capacitor.config.json"
assert_eq "find_project_root desde subdirectorio" "$TMP/proj" "$(cd "$TMP/proj/sub/dir" && find_project_root)"
assert_eq "find_project_root fuera de proyecto" "1" "$(cd "$TMP" && find_project_root >/dev/null 2>&1 && echo 0 || echo 1)"

# --- CLI sin TTY ---
if "$ROOT/bin/androiddev" </dev/null >"$TMP/help.txt" 2>&1; then
    assert_contains "sin TTY muestra ayuda" "$TMP/help.txt" "Uso: androiddev"
else
    fail "sin TTY muestra ayuda"
fi

# --- Scaffold sin instalar dependencias ---
if have node; then
    "$ROOT/bin/androiddev" new "Demo Test" --no-install --dir "$TMP/scaffold" >/dev/null 2>&1
    assert_file "scaffold package.json" "$TMP/scaffold/package.json"
    assert_file "scaffold capacitor.config.json" "$TMP/scaffold/capacitor.config.json"
    assert_file "scaffold www/index.html" "$TMP/scaffold/www/index.html"
    assert_contains "scaffold appId" "$TMP/scaffold/capacitor.config.json" '"appId": "com.example.demo_test"'
    assert_contains "scaffold appName" "$TMP/scaffold/capacitor.config.json" '"appName": "Demo Test"'
else
    printf 'skip - scaffold (Node.js no disponible)\n'
fi

printf '\n%d prueba(s) correcta(s), %d fallida(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
