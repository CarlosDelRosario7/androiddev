#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Diagnóstico del entorno.

cmd_doctor() {
    local failures=0
    local node_version node_major npm_version
    local jdk sdk sdkmanager arch

    printf '%sandroiddev doctor%s\n' "$C_BOLD" "$C_RESET"
    printf '  Sistema:  %s\n' "$OS_NAME"
    printf '  Familia:  %s\n' "$(pm_family "$PM")"
    printf '  Gestor:   %s\n' "$PM"
    printf '  Arch:     %s\n' "$(uname -m)"
    if is_wsl; then
        warn "WSL detectado. El soporte es de mejor esfuerzo."
    fi
    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) ;;
        aarch64 | arm64)
            warn "ARM64 detectado: algunos paquetes de cmdline-tools pueden no estar disponibles."
            ;;
        *)
            warn "Arquitectura $arch no probada; el soporte es de mejor esfuerzo."
            ;;
    esac
    if [ "$OS_ID" = alpine ]; then
        warn "Alpine usa musl; las herramientas del SDK pueden requerir gcompat."
    fi
    printf '\n'

    if have node; then
        node_version="$(node -v 2>/dev/null || true)"
        node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
        if [ -n "$node_major" ] && [ "$node_major" -ge 20 ]; then
            ok "Node.js $node_version"
        else
            err "Node.js $node_version es demasiado antiguo (se requiere >= 20)."
            printf '    %s\n' "$(tool_install_hint "$PM" node)" >&2
            failures=$((failures + 1))
        fi
    else
        err "Node.js no está instalado."
        printf '    %s\n' "$(tool_install_hint "$PM" node)" >&2
        failures=$((failures + 1))
    fi

    if have npm; then
        npm_version="$(npm -v 2>/dev/null || true)"
        ok "npm $npm_version"
    else
        err "npm no está instalado."
        printf '    %s\n' "$(tool_install_hint "$PM" node)" >&2
        failures=$((failures + 1))
    fi

    if jdk="$(find_jdk21)"; then
        ok "JDK 21: $jdk"
    else
        err "No se encontró JDK 21."
        printf '    %s\n' "$(jdk21_install_hint)" >&2
        failures=$((failures + 1))
    fi

    if sdk="$(find_android_sdk)"; then
        ok "Android SDK: $sdk"
        sdkmanager="$(find_sdkmanager "$sdk" 2>/dev/null || true)"
        if [ -n "$sdkmanager" ]; then
            ok "sdkmanager: $sdkmanager"
        else
            err "Falta cmdline-tools/sdkmanager."
            failures=$((failures + 1))
        fi
        if sdk_has_licenses "$sdk"; then
            ok "Licencias del SDK aceptadas"
        else
            err "Licencias del SDK sin aceptar."
            printf '    %s\n' "$(licenses_hint "$sdk")" >&2
            failures=$((failures + 1))
        fi
        printf '  Componentes: %s\n' "$(sdk_metadata_json "$sdk")"
        printf '    %s\n' "$(sdkmanager_hint "$sdk")"
    else
        err "No se encontró el SDK de Android."
        printf '    Define ANDROID_HOME/ANDROID_SDK_ROOT o instala cmdline-tools.\n' >&2
        failures=$((failures + 1))
    fi

    if have adb; then
        ok "adb: $(command -v adb)"
    elif [ -n "${sdk:-}" ] && [ -x "$sdk/platform-tools/adb" ]; then
        warn "adb existe pero no está en PATH."
        # shellcheck disable=SC2016
        printf '    export PATH="%s/platform-tools:$PATH"\n' "$sdk" >&2
    else
        warn "adb no está disponible (no es imprescindible para compilar)."
    fi

    if have curl; then
        ok "curl disponible"
    else
        warn "curl no está instalado (opcional)."
    fi
    if have unzip; then
        ok "unzip disponible"
    else
        warn "unzip no está instalado (opcional)."
    fi

    printf '\n'
    if [ "$failures" -eq 0 ]; then
        ok "Todo listo para crear y compilar proyectos."
        return 0
    fi
    err "$failures comprobación(es) pendiente(s)."
    return 1
}
