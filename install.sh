#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Instalador de androiddev.
# shellcheck disable=SC2088

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"

PREFIX="${HOME}/.local"
SHELL_CHOICE=""
ASSUME_YES=0

usage() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --prefix DIR        Prefijo de instalación (por defecto ~/.local)
  --shell SHELL       bash, zsh, both o none (si se omite, pregunta)
  --yes, -y           No pedir confirmación
  -h, --help          Muestra esta ayuda

Instala en <prefijo>/share/androiddev y crea <prefijo>/bin/androiddev.
No usa sudo.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            [ $# -ge 2 ] || die "Falta el valor de --prefix"
            PREFIX="$2"
            shift 2
            ;;
        --shell)
            [ $# -ge 2 ] || die "Falta el valor de --shell"
            SHELL_CHOICE="$2"
            shift 2
            ;;
        --yes | -y)
            ASSUME_YES=1
            export ANDROIDDEV_YES=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "Opción desconocida: $1"
            ;;
    esac
done

case "$PREFIX" in
    "~/"*) PREFIX="$HOME/${PREFIX#~/}" ;;
esac
case "$PREFIX" in
    /*) ;;
    *) PREFIX="$PWD/$PREFIX" ;;
esac

DATA_DIR="$PREFIX/share/androiddev"
BIN_DIR="$PREFIX/bin"
BIN_LINK="$BIN_DIR/androiddev"

ask_shell() {
    local current choice
    current="$(basename "${SHELL:-desconocido}")"
    printf '\n¿Dónde instalo la integración?\n' >&2
    printf '  1) ~/.bashrc (bash)%s\n' "$([ "$current" = bash ] && printf '  <- shell actual')" >&2
    printf '  2) ~/.zshrc (zsh)%s\n' "$([ "$current" = zsh ] && printf '  <- shell actual')" >&2
    printf '  3) Ambos\n' >&2
    printf '  4) Ninguno\n' >&2
    read -r -p "Elige una opción [1-4]: " choice || {
        printf 'none\n'
        return 0
    }
    case "$choice" in
        1) printf 'bash\n' ;;
        2) printf 'zsh\n' ;;
        3) printf 'both\n' ;;
        4 | "") printf 'none\n' ;;
        *)
            warn "Opción inválida; no se modificará el shell."
            printf 'none\n'
            ;;
    esac
}

if [ -z "$SHELL_CHOICE" ]; then
    if [ -t 0 ] && [ "$ASSUME_YES" = 0 ]; then
        SHELL_CHOICE="$(ask_shell)"
    else
        SHELL_CHOICE="none"
    fi
fi

case "$SHELL_CHOICE" in
    bash | zsh | both | none) ;;
    *) die "Valor inválido para --shell: $SHELL_CHOICE" ;;
esac

mkdir -p "$DATA_DIR" "$BIN_DIR" || die "No se pudo crear $PREFIX"
rm -rf "${DATA_DIR:?}/bin" "${DATA_DIR:?}/lib" "${DATA_DIR:?}/templates"
cp -a "$ROOT/bin" "$ROOT/lib" "$ROOT/templates" "$DATA_DIR/" || die "No se pudo copiar la instalación."
chmod +x "$DATA_DIR/bin/androiddev"

if [ -e "$BIN_LINK" ] && [ ! -L "$BIN_LINK" ]; then
    die "Ya existe $BIN_LINK y no es un enlace simbólico. Muévelo o usa --prefix."
fi
ln -sfn "$DATA_DIR/bin/androiddev" "$BIN_LINK"

ok "androiddev instalado en $DATA_DIR"
ok "Enlace creado: $BIN_LINK"

if [ "$SHELL_CHOICE" != none ]; then
    ANDROIDDEV_YES=1 "$DATA_DIR/bin/androiddev" shell install --shell "$SHELL_CHOICE"
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        printf '\nAñade %s a tu PATH:\n' "$BIN_DIR"
        # shellcheck disable=SC2016
        printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
        ;;
esac

printf '\nPrueba con:\n  androiddev doctor\n  androiddev\n'
