#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Consulta y edición de la configuración.

config_usage() {
    cat <<'EOF'
Uso: androiddev config [acción]

Acciones:
  show                 Muestra la configuración y lo detectado
  set <clave> <valor>  Cambia un valor
  unset <clave>        Borra un valor

Claves: sdk, java, output, capacitor
EOF
}

show_config() {
    local sdk jdk
    sdk="$(find_android_sdk 2>/dev/null || true)"
    jdk="$(find_jdk21 2>/dev/null || true)"
    printf '%sConfiguración%s\n' "$C_BOLD" "$C_RESET"
    printf '  Archivo:    %s\n' "$(config_file)"
    printf '  SDK:        %s\n' "${ANDROIDDEV_SDK_DIR:-${sdk:-no detectado}}"
    printf '  JDK 21:     %s\n' "${ANDROIDDEV_JAVA_HOME:-${jdk:-no detectado}}"
    printf '  Salida APK: %s\n' "${ANDROIDDEV_OUTPUT_DIR:-$(desktop_dir)}"
    printf '  Capacitor:  %s\n' "${ANDROIDDEV_CAPACITOR_VERSION:-7}"
}

cmd_config() {
    local action="${1:-show}" key="${2:-}" value="${3:-}"
    case "$action" in
        show | "")
            show_config
            ;;
        set)
            [ -n "$key" ] || die "Falta la clave. Usa: androiddev config set output /ruta"
            [ -n "$value" ] || die "Falta el valor. Usa: androiddev config set output /ruta"
            case "$key" in
                sdk)
                    [ -d "$value" ] || die "No existe el directorio: $value"
                    ANDROIDDEV_SDK_DIR="$(cd "$value" && pwd -P)"
                    ;;
                java)
                    [ -x "$value/bin/java" ] || die "No parece un JDK válido: $value"
                    ANDROIDDEV_JAVA_HOME="$(cd "$value" && pwd -P)"
                    ;;
                output)
                    mkdir -p "$value" || die "No se pudo crear: $value"
                    ANDROIDDEV_OUTPUT_DIR="$(cd "$value" && pwd -P)"
                    ;;
                capacitor)
                    [ "$value" = 7 ] || die "Solo se soporta Capacitor 7."
                    ANDROIDDEV_CAPACITOR_VERSION="$value"
                    ;;
                *) die "Clave desconocida: $key" ;;
            esac
            save_config
            ;;
        unset)
            [ -n "$key" ] || die "Falta la clave."
            case "$key" in
                sdk) ANDROIDDEV_SDK_DIR="" ;;
                java) ANDROIDDEV_JAVA_HOME="" ;;
                output) ANDROIDDEV_OUTPUT_DIR="" ;;
                capacitor) ANDROIDDEV_CAPACITOR_VERSION="7" ;;
                *) die "Clave desconocida: $key" ;;
            esac
            save_config
            ;;
        -h | --help)
            config_usage
            ;;
        *)
            die "Acción desconocida: $action"
            ;;
    esac
}
