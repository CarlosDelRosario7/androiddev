#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Desinstalador de androiddev.
# shellcheck disable=SC2088

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"

PREFIX="${HOME}/.local"
SHELL_CHOICE=""
ASSUME_YES=0
REMOVE_CONFIG=0

usage() {
    cat <<'EOF'
Uso: ./uninstall.sh [opciones]

Opciones:
  --prefix DIR        Prefijo usado en la instalación (por defecto ~/.local)
  --shell SHELL       bash, zsh, both o none (si se omite, pregunta)
  --yes, -y           No pedir confirmación
  --remove-config     Borra ~/.config/androiddev
  -h, --help          Muestra esta ayuda
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
        --remove-config)
            REMOVE_CONFIG=1
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
BIN_LINK="$PREFIX/bin/androiddev"

if [ -z "$SHELL_CHOICE" ]; then
    if [ -t 0 ] && [ "$ASSUME_YES" = 0 ]; then
        printf '\n¿Quitar la integración de .bashrc/.zshrc?\n'
        printf '  1) Sí, de ambos\n'
        printf '  2) No\n'
        read -r -p "Elige una opción [1-2]: " answer || answer="2"
        case "$answer" in
            1) SHELL_CHOICE="both" ;;
            *) SHELL_CHOICE="none" ;;
        esac
    else
        SHELL_CHOICE="none"
    fi
fi

case "$SHELL_CHOICE" in
    bash | zsh | both | none) ;;
    *) die "Valor inválido para --shell: $SHELL_CHOICE" ;;
esac

if [ "$SHELL_CHOICE" != none ]; then
    if [ -x "$DATA_DIR/bin/androiddev" ]; then
        ANDROIDDEV_YES=1 "$DATA_DIR/bin/androiddev" shell remove --shell "$SHELL_CHOICE" || true
    else
        warn "No se encontró la instalación en $DATA_DIR; no se pudo quitar el bloque del shell."
        warn "Puedes eliminarlo a mano entre '# >>> androiddev >>>' y '# <<< androiddev <<<'."
    fi
fi

if [ -L "$BIN_LINK" ]; then
    target="$(readlink -f "$BIN_LINK" 2>/dev/null || true)"
    if [ "$target" = "$(readlink -f "$DATA_DIR/bin/androiddev" 2>/dev/null || true)" ] || [ -z "$target" ]; then
        rm -f "$BIN_LINK"
        ok "Enlace eliminado: $BIN_LINK"
    else
        warn "No se eliminó $BIN_LINK porque apunta a otro sitio: $target"
    fi
fi

if [ -d "$DATA_DIR" ]; then
    if [ "$ASSUME_YES" = 1 ] || confirm "¿Borrar $DATA_DIR?"; then
        case "$DATA_DIR" in
            */androiddev) rm -rf -- "$DATA_DIR" ;;
            *) die "Ruta inesperada, no se borra: $DATA_DIR" ;;
        esac
        ok "Instalación eliminada: $DATA_DIR"
    fi
fi

if [ "$REMOVE_CONFIG" = 1 ]; then
    CONFIG_DIR="$(config_dir)"
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf -- "$CONFIG_DIR"
        ok "Configuración eliminada: $CONFIG_DIR"
    fi
else
    printf '\nLa configuración se conserva en %s\n' "$(config_dir)"
    printf 'Para borrarla: %s --remove-config\n' "$0"
fi
