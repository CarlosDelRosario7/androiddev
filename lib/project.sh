#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Creación de proyectos Capacitor.

is_java_keyword() {
    case "$1" in
        abstract | assert | boolean | break | byte | case | catch | char | class | const | continue | default | do | double | else | enum | extends | final | finally | float | for | goto | if | implements | import | instanceof | int | interface | long | native | new | package | private | protected | public | return | short | static | strictfp | super | switch | synchronized | this | throw | throws | transient | try | void | volatile | while | true | false | null)
            return 0
            ;;
        *) return 1 ;;
    esac
}

slugify_ascii() {
    local value="$1"
    if have iconv; then
        value="$(printf '%s' "$value" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$value")"
    fi
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

slugify_pkg() {
    local value
    value="$(slugify_ascii "$1")"
    value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"
    [ -n "$value" ] || value="app"
    case "$value" in
        [0-9]*) value="app_$value" ;;
    esac
    if is_java_keyword "$value"; then
        value="app_$value"
    fi
    printf '%s\n' "$value"
}

slugify_file() {
    local value
    value="$(slugify_ascii "$1")"
    value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    [ -n "$value" ] || value="app"
    case "$value" in
        [0-9]*) value="app-$value" ;;
    esac
    printf '%s\n' "$value"
}

validate_app_id() {
    local app_id="$1" segment
    [[ "$app_id" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] || return 1
    IFS='.' read -r -a segments <<<"$app_id"
    for segment in "${segments[@]}"; do
        if is_java_keyword "$segment"; then
            return 1
        fi
    done
    return 0
}

check_node() {
    local major
    if ! have node; then
        err "Node.js no está instalado."
        printf '  Instálalo con:\n    %s\n' "$(tool_install_hint "${PM:-desconocido}" node)" >&2
        return 1
    fi
    major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
    if [ -z "$major" ] || [ "$major" -lt 20 ]; then
        err "Se requiere Node.js 20 o superior. Tienes: $(node -v 2>/dev/null || printf 'desconocido')"
        printf '  Instálalo con:\n    %s\n' "$(tool_install_hint "${PM:-desconocido}" node)" >&2
        return 1
    fi
    if ! have npm; then
        err "npm no está instalado."
        printf '  Instálalo con:\n    %s\n' "$(tool_install_hint "${PM:-desconocido}" node)" >&2
        return 1
    fi
}

new_usage() {
    cat <<'EOF'
Uso: androiddev new <nombre> [opciones]

Opciones:
  --app-id ID       App ID de Android (por defecto com.example.<slug>)
  --dir RUTA        Directorio destino (por defecto ./<nombre>)
  --no-install      Crea los archivos sin ejecutar npm ni cap add android
  -h, --help        Muestra esta ayuda
EOF
}

cmd_new() {
    local name="" app_id="" target_dir="" no_install=0
    local pkg_name parent tmp cap_version sdk=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --app-id)
                [ $# -ge 2 ] || die "Falta el valor de --app-id"
                app_id="$2"
                shift 2
                ;;
            --dir)
                [ $# -ge 2 ] || die "Falta el valor de --dir"
                target_dir="$2"
                shift 2
                ;;
            --no-install)
                no_install=1
                shift
                ;;
            -h | --help)
                new_usage
                return 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Opción desconocida: $1"
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                    shift
                else
                    die "Argumento sobrante: $1"
                fi
                ;;
        esac
    done

    [ -n "$name" ] || die "Falta el nombre del proyecto. Usa: androiddev new mi-app"
    case "$name" in
        */* | *\\*) die "El nombre no puede contener barras. Usa --dir para indicar una ruta." ;;
    esac
    if [ -z "$(printf '%s' "$name" | tr -d '[:space:]')" ]; then
        die "El nombre no puede estar vacío."
    fi

    check_node || exit 1

    cap_version="${ANDROIDDEV_CAPACITOR_VERSION:-7}"
    if [ "$cap_version" != 7 ]; then
        die "Esta versión de androiddev solo soporta Capacitor 7 (configurado: $cap_version)."
    fi

    pkg_name="$(slugify_pkg "$name")"
    if [ -z "$app_id" ]; then
        app_id="com.example.$pkg_name"
    fi
    if ! validate_app_id "$app_id"; then
        die "App ID inválido: $app_id. Usa minúsculas, letras/números/_, al menos dos segmentos (ej: com.ejemplo.app)."
    fi

    if [ -z "$target_dir" ]; then
        target_dir="$PWD/$name"
    else
        case "$target_dir" in
            /*) ;;
            *) target_dir="$PWD/$target_dir" ;;
        esac
    fi
    parent="$(dirname "$target_dir")"
    mkdir -p "$parent" || die "No se pudo crear el directorio padre: $parent"

    if [ -e "$target_dir" ]; then
        if [ ! -d "$target_dir" ]; then
            die "El destino existe y no es un directorio: $target_dir"
        fi
        if [ -n "$(find "$target_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            die "El destino ya existe y no está vacío: $target_dir"
        fi
    fi

    tmp="$(mktemp -d "$parent/.androiddev.XXXXXX")"
    ANDROIDDEV_CLEANUP_DIR="$tmp"
    trap 'cleanup_path "${ANDROIDDEV_CLEANUP_DIR:-}"; ANDROIDDEV_CLEANUP_DIR=""' EXIT

    info "Creando estructura web..."
    mkdir -p "$tmp/www"

    node -e '
const fs = require("fs");
const [file, name] = process.argv.slice(1);
const pkg = {
  name,
  version: "0.1.0",
  private: true,
  description: "Proyecto Capacitor creado con androiddev",
  scripts: { sync: "cap sync android", build: "cap build android" },
  dependencies: {
    "@capacitor/core": "^7.0.0",
    "@capacitor/android": "^7.0.0"
  },
  devDependencies: { "@capacitor/cli": "^7.0.0" }
};
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$tmp/package.json" "$pkg_name"

    node -e '
const fs = require("fs");
const [file, appId, appName] = process.argv.slice(1);
const config = { appId, appName, webDir: "www" };
fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
' "$tmp/capacitor.config.json" "$app_id" "$name"

    node -e '
const fs = require("fs");
const [template, output, appName] = process.argv.slice(1);
const escaped = appName
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;");
const html = fs.readFileSync(template, "utf8").replaceAll("__APP_NAME__", escaped);
fs.writeFileSync(output, html);
' "$ANDROIDDEV_ROOT/templates/index.html" "$tmp/www/index.html" "$name"

    if [ "$no_install" = 0 ]; then
        info "Instalando dependencias de Node..."
        if [ "${ANDROIDDEV_DRY_RUN:-0}" = 1 ]; then
            printf '%s[dry-run]%s (cd %s && npm install)\n' "$C_YELLOW" "$C_RESET" "$tmp"
        else
            (cd "$tmp" && npm install --no-audit --no-fund) || die "Falló npm install."
        fi

        if sdk="$(find_android_sdk || true)"; then
            info "Añadiendo plataforma Android (SDK: $sdk)..."
        else
            warn "No se encontró el SDK de Android; la plataforma se añadirá igualmente."
            info "Añadiendo plataforma Android..."
        fi

        if [ "${ANDROIDDEV_DRY_RUN:-0}" = 1 ]; then
            printf '%s[dry-run]%s (cd %s && ./node_modules/.bin/cap add android)\n' "$C_YELLOW" "$C_RESET" "$tmp"
        else
            if [ ! -x "$tmp/node_modules/.bin/cap" ]; then
                die "No se encontró @capacitor/cli en node_modules."
            fi
            (
                cd "$tmp"
                if [ -n "$sdk" ]; then
                    export ANDROID_HOME="$sdk"
                    export ANDROID_SDK_ROOT="$sdk"
                fi
                ./node_modules/.bin/cap add android
            ) || die "Falló cap add android."
        fi
    fi

    if [ -d "$target_dir" ]; then
        rmdir "$target_dir" || die "No se pudo preparar el destino: $target_dir"
    fi
    mv "$tmp" "$target_dir" || die "No se pudo mover el proyecto a $target_dir"
    ANDROIDDEV_CLEANUP_DIR=""
    trap - EXIT

    ok "Proyecto creado en $target_dir"
    if [ "$no_install" = 0 ]; then
        printf '\nSiguiente paso:\n  cd %s\n  androiddev build\n' "$target_dir"
    else
        printf '\nSiguiente paso:\n  cd %s\n  npm install\n  ./node_modules/.bin/cap add android\n  androiddev build\n' "$target_dir"
    fi
}

find_project_root() {
    local dir="${1:-$PWD}"
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/capacitor.config.json" ] || [ -f "$dir/capacitor.config.js" ] || [ -f "$dir/capacitor.config.ts" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

project_app_name() {
    local root="$1" config name
    for config in "$root/capacitor.config.json" "$root/capacitor.config.js" "$root/capacitor.config.ts"; do
        [ -f "$config" ] || continue
        if [ "${config##*.}" = json ]; then
            name="$(node -e 'const c=require(process.argv[1]); process.stdout.write(c.appName||"")' "$config" 2>/dev/null || true)"
            if [ -n "$name" ]; then
                printf '%s\n' "$name"
                return 0
            fi
        else
            name="$(sed -n "s/.*appName:[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$config" | head -n1)"
            if [ -n "$name" ]; then
                printf '%s\n' "$name"
                return 0
            fi
        fi
    done
    basename "$root"
}

project_app_id() {
    local root="$1" config app_id
    for config in "$root/capacitor.config.json" "$root/capacitor.config.js" "$root/capacitor.config.ts"; do
        [ -f "$config" ] || continue
        if [ "${config##*.}" = json ]; then
            app_id="$(node -e 'const c=require(process.argv[1]); process.stdout.write(c.appId||"")' "$config" 2>/dev/null || true)"
            if [ -n "$app_id" ]; then
                printf '%s\n' "$app_id"
                return 0
            fi
        fi
    done
    printf 'com.example.app\n'
}
