#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Integración gestionada con .bashrc y .zshrc.

SHELL_BLOCK_START='# >>> androiddev >>>'
SHELL_BLOCK_END='# <<< androiddev <<<'

current_shell_name() {
    local shell_name="${SHELL:-}"
    shell_name="${shell_name##*/}"
    printf '%s\n' "$shell_name"
}

rc_for_shell() {
    case "$1" in
        bash) printf '%s\n' "$HOME/.bashrc" ;;
        zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
        *) return 1 ;;
    esac
}

rc_target_file() {
    local rc="$1" target
    if [ -L "$rc" ]; then
        target="$(readlink -f "$rc" 2>/dev/null || true)"
        if [ -z "$target" ]; then
            target="$(readlink "$rc")"
            case "$target" in
                /*) ;;
                *) target="$(dirname "$rc")/$target" ;;
            esac
        fi
        printf '%s\n' "$target"
    else
        printf '%s\n' "$rc"
    fi
}

shell_block() {
    local sdk="${1:-$HOME/android-sdk}" sdk_line
    if [ "$sdk" = "$HOME/android-sdk" ]; then
        sdk_line='ANDROID_HOME="$HOME/android-sdk"'
    else
        sdk_line="ANDROID_HOME=$(quote_sh "$sdk")"
    fi

    cat <<EOF
$SHELL_BLOCK_START
# Bloque gestionado por androiddev. No editar a mano.
if [ -z "\${ANDROID_HOME:-}" ]; then
  $sdk_line
fi
export ANDROID_HOME
if [ -z "\${ANDROID_SDK_ROOT:-}" ]; then
  ANDROID_SDK_ROOT="\$ANDROID_HOME"
fi
export ANDROID_SDK_ROOT
case ":\$PATH:" in
  *":\$HOME/.local/bin:"*) ;;
  *) export PATH="\$HOME/.local/bin:\$PATH" ;;
esac
case ":\$PATH:" in
  *":\$ANDROID_HOME/platform-tools:"*) ;;
  *) export PATH="\$ANDROID_HOME/platform-tools:\$PATH" ;;
esac
crear_apk()  { command androiddev new "\$@"; }
compila_apk() { command androiddev build "\$@"; }
$SHELL_BLOCK_END
EOF
}

block_installed() {
    local file="$1"
    [ -f "$file" ] && grep -qF "$SHELL_BLOCK_START" "$file"
}

remove_block_from_file() {
    local file="$1" tmp
    tmp="$(mktemp "$file.androiddev.XXXXXX")"
    awk -v start="$SHELL_BLOCK_START" -v end="$SHELL_BLOCK_END" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$file" >"$tmp"
    chmod --reference="$file" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    mv "$tmp" "$file"
}

install_block_in_file() {
    local rc="$1" sdk="$2" file tmp
    file="$(rc_target_file "$rc")"
    if [ ! -e "$file" ]; then
        info "Creando $rc..."
        mkdir -p "$(dirname "$file")"
        : >"$file"
    fi
    [ -w "$file" ] || die "No se puede escribir en $file"

    tmp="$(mktemp "$file.androiddev.XXXXXX")"
    if [ -s "$file" ]; then
        awk -v start="$SHELL_BLOCK_START" -v end="$SHELL_BLOCK_END" '
            $0 == start { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$file" >"$tmp"
    fi
    printf '\n' >>"$tmp"
    shell_block "$sdk" >>"$tmp"
    chmod --reference="$file" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    mv "$tmp" "$file"
    ok "Integración instalada en $rc"
}

shell_selection() {
    local choice current installed_bash="no" installed_zsh="no"
    current="$(current_shell_name)"
    block_installed "$HOME/.bashrc" && installed_bash="sí"
    block_installed "${ZDOTDIR:-$HOME}/.zshrc" && installed_zsh="sí"

    printf '\n%sIntegración con el shell%s\n' "$C_BOLD" "$C_RESET" >&2
    printf '  1) ~/.bashrc (bash)  [instalado: %s]%s\n' "$installed_bash" "$([ "$current" = bash ] && printf '  <- shell actual')" >&2
    printf '  2) ~/.zshrc (zsh)    [instalado: %s]%s\n' "$installed_zsh" "$([ "$current" = zsh ] && printf '  <- shell actual')" >&2
    printf '  3) Ambos\n' >&2
    printf '  4) Ninguno\n' >&2
    printf '  0) Volver\n' >&2
    read -r -p "Elige una opción [0-4]: " choice || return 1
    case "$choice" in
        1) printf 'bash\n' ;;
        2) printf 'zsh\n' ;;
        3) printf 'both\n' ;;
        4) printf 'none\n' ;;
        0 | q | Q) return 1 ;;
        *)
            warn "Opción inválida."
            return 1
            ;;
    esac
}

cmd_shell_status() {
    local bash_rc zsh_rc
    bash_rc="$HOME/.bashrc"
    zsh_rc="${ZDOTDIR:-$HOME}/.zshrc"
    if block_installed "$bash_rc"; then
        ok "bash: $bash_rc (instalado)"
    else
        printf '  bash: %s (no instalado)\n' "$bash_rc"
    fi
    if block_installed "$zsh_rc"; then
        ok "zsh: $zsh_rc (instalado)"
    else
        printf '  zsh: %s (no instalado)\n' "$zsh_rc"
    fi
}

cmd_shell_install() {
    local selection="" sdk=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --shell)
                [ $# -ge 2 ] || die "Falta el valor de --shell"
                selection="$2"
                shift 2
                ;;
            -h | --help)
                printf 'Uso: androiddev shell install [--shell bash|zsh|both|none]\n'
                return 0
                ;;
            *)
                die "Opción desconocida: $1"
                ;;
        esac
    done

    if [ -z "$selection" ]; then
        if is_tty; then
            selection="$(shell_selection)" || return 0
        else
            die "Indica --shell bash|zsh|both|none en modo no interactivo."
        fi
    fi

    case "$selection" in
        bash | zsh | both | none) ;;
        *) die "Valor inválido para --shell: $selection" ;;
    esac

    if [ "$selection" = none ]; then
        info "No se modificó ningún archivo de shell."
        return 0
    fi

    sdk="$(find_android_sdk 2>/dev/null || true)"
    [ -n "$sdk" ] || sdk="$HOME/android-sdk"

    if [ "$selection" = bash ] || [ "$selection" = both ]; then
        install_block_in_file "$HOME/.bashrc" "$sdk"
    fi
    if [ "$selection" = zsh ] || [ "$selection" = both ]; then
        install_block_in_file "${ZDOTDIR:-$HOME}/.zshrc" "$sdk"
    fi

    printf '\nRecarga tu shell con:\n'
    case "$selection" in
        bash) printf '  source ~/.bashrc\n' ;;
        zsh) printf '  source ~/.zshrc\n' ;;
        both) printf '  source ~/.bashrc && source ~/.zshrc\n' ;;
    esac
    printf 'O abre una terminal nueva.\n'
}

cmd_shell_remove() {
    local selection="" rc file removed=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --shell)
                [ $# -ge 2 ] || die "Falta el valor de --shell"
                selection="$2"
                shift 2
                ;;
            -h | --help)
                printf 'Uso: androiddev shell remove [--shell bash|zsh|both]\n'
                return 0
                ;;
            *)
                die "Opción desconocida: $1"
                ;;
        esac
    done

    if [ -z "$selection" ]; then
        if is_tty; then
            selection="$(shell_selection)" || return 0
        else
            die "Indica --shell bash|zsh|both en modo no interactivo."
        fi
    fi

    case "$selection" in
        bash | zsh | both) ;;
        none)
            info "No se modificó ningún archivo de shell."
            return 0
            ;;
        *) die "Valor inválido para --shell: $selection" ;;
    esac

    for rc in "$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc"; do
        if { [ "$selection" = bash ] && [ "$rc" = "$HOME/.bashrc" ]; } ||
            { [ "$selection" = zsh ] && [ "$rc" = "${ZDOTDIR:-$HOME}/.zshrc" ]; } ||
            [ "$selection" = both ]; then
            file="$(rc_target_file "$rc")"
            if [ -f "$file" ] && block_installed "$file"; then
                if ! is_tty || confirm "¿Quitar la integración de $rc?"; then
                    remove_block_from_file "$file"
                    ok "Integración eliminada de $rc"
                    removed=1
                fi
            fi
        fi
    done

    if [ "$removed" = 0 ]; then
        info "No había integración que quitar."
    fi
}

cmd_shell() {
    local action="${1:-}"
    [ $# -gt 0 ] && shift
    case "$action" in
        install) cmd_shell_install "$@" ;;
        remove) cmd_shell_remove "$@" ;;
        status) cmd_shell_status ;;
        "" | -h | --help)
            cat <<'EOF'
Uso: androiddev shell <acción> [opciones]

Acciones:
  install    Instala aliases y variables en .bashrc y/o .zshrc
  remove     Quita el bloque gestionado por androiddev
  status     Muestra dónde está instalado

Opciones de install/remove:
  --shell bash|zsh|both|none
EOF
            ;;
        *) die "Acción desconocida: $action" ;;
    esac
}
