#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Menú interactivo.

menu_header() {
    printf '\n%s╭─────────────────────────────────────────────╮%s\n' "$C_BOLD" "$C_RESET"
    printf '%s│  androiddev                                 │%s\n' "$C_BOLD" "$C_RESET"
    printf '%s├─────────────────────────────────────────────┤%s\n' "$C_BOLD" "$C_RESET"
    printf '│  1) Diagnosticar el sistema                 │\n'
    printf '│  2) Crear proyecto Capacitor                │\n'
    printf '│  3) Compilar APK debug                      │\n'
    printf '│  4) Instalar en .bashrc / .zshrc            │\n'
    printf '│  5) Quitar de .bashrc / .zshrc              │\n'
    printf '│  6) Ver configuración detectada             │\n'
    printf '│  7) Ayuda                                   │\n'
    printf '│  0) Salir                                   │\n'
    printf '%s╰─────────────────────────────────────────────╯%s\n' "$C_BOLD" "$C_RESET"
}

menu_new() {
    local name app_id dir
    read -r -p "Nombre del proyecto: " name || return 0
    [ -n "$name" ] || {
        warn "Nombre vacío."
        return 0
    }
    read -r -p "App ID [com.example.<slug>]: " app_id || true
    read -r -p "Directorio [./$name]: " dir || true

    local args=(new "$name")
    [ -n "$app_id" ] && args+=(--app-id "$app_id")
    [ -n "$dir" ] && args+=(--dir "$dir")
    cmd_new "${args[@]}" || true
}

menu_build() {
    local project
    read -r -p "Ruta del proyecto [.]: " project || true
    project="${project:-.}"
    cmd_build --project "$project" || true
}

menu_shell_install() {
    local selection
    selection="$(shell_selection)" || return 0
    cmd_shell_install --shell "$selection" || true
}

menu_shell_remove() {
    local selection
    selection="$(shell_selection)" || return 0
    cmd_shell_remove --shell "$selection" || true
}

menu_config() {
    show_config
    printf '\nPara cambiar un valor:\n'
    printf '  androiddev config set output /ruta\n'
    printf '  androiddev config set sdk /ruta/al/sdk\n'
    printf '  androiddev config set java /ruta/al/jdk-21\n'
}

menu_help() {
    usage
}

menu_main() {
    local option
    while true; do
        menu_header
        read -r -p "Elige una opción [0-7]: " option || {
            printf '\n'
            return 0
        }
        case "$option" in
            1)
                (cmd_doctor) || true
                pause
                ;;
            2)
                (menu_new) || true
                pause
                ;;
            3)
                (menu_build) || true
                pause
                ;;
            4)
                (menu_shell_install) || true
                pause
                ;;
            5)
                (menu_shell_remove) || true
                pause
                ;;
            6)
                (menu_config) || true
                pause
                ;;
            7)
                menu_help
                pause
                ;;
            0 | q | Q)
                return 0
                ;;
            *)
                warn "Opción inválida."
                ;;
        esac
    done
}
