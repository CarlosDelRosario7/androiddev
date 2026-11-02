#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Utilidades comunes: salida, configuración y helpers.
# shellcheck disable=SC2034

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${ANDROIDDEV_NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
fi

info() { printf '%s==>%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok() { printf '%s[ok]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[aviso]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err() { printf '%s[error]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() {
    err "$*"
    exit 1
}

debug() {
    if [ "${ANDROIDDEV_DEBUG:-0}" = 1 ]; then
        printf '%s[debug]%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }
is_tty() { [ -t 0 ] && [ -t 1 ]; }

confirm() {
    local prompt="${1:-¿Continuar?}"
    local reply
    if [ "${ANDROIDDEV_YES:-0}" = 1 ]; then
        return 0
    fi
    if ! is_tty; then
        return 1
    fi
    read -r -p "$prompt [s/N] " reply || return 1
    case "$reply" in
        s | S | si | Si | sí | Sí | y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

pause() {
    if is_tty; then
        printf '\n%sPulsa Enter para continuar...%s' "$C_DIM" "$C_RESET"
        read -r _ || true
    fi
}

quote_sh() { printf '%q' "$1"; }

config_dir() { printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/androiddev"; }
config_file() { printf '%s\n' "$(config_dir)/config"; }

load_config() {
    local file
    file="$(config_file)"
    if [ -f "$file" ]; then
        # shellcheck source=/dev/null
        . "$file"
    fi
    ANDROIDDEV_CAPACITOR_VERSION="${ANDROIDDEV_CAPACITOR_VERSION:-7}"
    ANDROIDDEV_OUTPUT_DIR="${ANDROIDDEV_OUTPUT_DIR:-}"
    ANDROIDDEV_SDK_DIR="${ANDROIDDEV_SDK_DIR:-}"
    ANDROIDDEV_JAVA_HOME="${ANDROIDDEV_JAVA_HOME:-}"
}

save_config() {
    local dir file
    dir="$(config_dir)"
    file="$(config_file)"
    mkdir -p "$dir"
    {
        printf '# Configuración de androiddev\n'
        printf 'ANDROIDDEV_SDK_DIR=%s\n' "$(quote_sh "${ANDROIDDEV_SDK_DIR:-}")"
        printf 'ANDROIDDEV_JAVA_HOME=%s\n' "$(quote_sh "${ANDROIDDEV_JAVA_HOME:-}")"
        printf 'ANDROIDDEV_OUTPUT_DIR=%s\n' "$(quote_sh "${ANDROIDDEV_OUTPUT_DIR:-}")"
        printf 'ANDROIDDEV_CAPACITOR_VERSION=%s\n' "$(quote_sh "${ANDROIDDEV_CAPACITOR_VERSION:-7}")"
    } >"$file"
    ok "Configuración guardada en $file"
}

desktop_dir() {
    local dir="" candidate
    if have xdg-user-dir; then
        dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
        for candidate in "$HOME/Desktop" "$HOME/Escritorio" "$HOME/Bureau" "$HOME/Schreibtisch"; do
            if [ -d "$candidate" ]; then
                dir="$candidate"
                break
            fi
        done
    fi
    [ -n "$dir" ] || dir="$HOME"
    printf '%s\n' "$dir"
}

abs_dir() {
    (cd "$1" 2>/dev/null && pwd -P)
}

html_escape() {
    local s="$1"
    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\"/&quot;}
    s=${s//\'/&#39;}
    printf '%s' "$s"
}

timestamp() { date +%Y%m%d-%H%M%S; }

cleanup_path() {
    local path="${1:-}"
    if [ -n "$path" ] && [ -d "$path" ]; then
        rm -rf -- "$path"
    fi
}
