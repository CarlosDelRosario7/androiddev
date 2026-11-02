#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compilación de APK debug.

build_usage() {
    cat <<'EOF'
Uso: androiddev build [opciones]

Opciones:
  --project RUTA    Raíz del proyecto (por defecto el directorio actual)
  --out DIR         Carpeta de salida del APK (por defecto el escritorio)
  --no-copy         No copiar el APK; solo mostrarlo
  --force           Sobrescribir el APK de destino si ya existe
  -h, --help        Muestra esta ayuda
EOF
}

cmd_build() {
    local project="$PWD" out="" no_copy=0 force=0
    local root jdk sdk cap_bin gradlew apk dest_dir app_name base target

    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                [ $# -ge 2 ] || die "Falta el valor de --project"
                project="$2"
                shift 2
                ;;
            --out)
                [ $# -ge 2 ] || die "Falta el valor de --out"
                out="$2"
                shift 2
                ;;
            --no-copy)
                no_copy=1
                shift
                ;;
            --force)
                force=1
                shift
                ;;
            -h | --help)
                build_usage
                return 0
                ;;
            -*)
                die "Opción desconocida: $1"
                ;;
            *)
                die "Argumento inesperado: $1"
                ;;
        esac
    done

    root="$(find_project_root "$project")" || die "No se encontró un proyecto Capacitor en $project."
    [ -f "$root/package.json" ] || die "Falta package.json en $root."
    [ -d "$root/android" ] || die "Falta la plataforma Android. Ejecuta: cd $root && ./node_modules/.bin/cap add android"

    check_node || exit 1

    if [ ! -d "$root/node_modules" ]; then
        warn "Faltan las dependencias de Node en $root."
        if confirm "¿Ejecutar npm install ahora?"; then
            (cd "$root" && npm install --no-audit --no-fund) || die "Falló npm install."
        else
            die "Ejecuta npm install en $root y vuelve a intentarlo."
        fi
    fi

    jdk="$(require_jdk21)" || exit 1
    sdk="$(project_sdk "$root")" || {
        err "No se encontró el SDK de Android."
        printf '  Define ANDROID_HOME/ANDROID_SDK_ROOT o instala cmdline-tools.\n' >&2
        exit 1
    }

    if ! sdk_has_licenses "$sdk"; then
        err "Las licencias del SDK no están aceptadas en $sdk."
        printf '  Ejecuta:\n    %s\n' "$(licenses_hint "$sdk")" >&2
        exit 1
    fi

    cap_bin="$root/node_modules/.bin/cap"
    if [ ! -x "$cap_bin" ]; then
        die "No se encontró @capacitor/cli. Ejecuta npm install en $root."
    fi

    if [ "${ANDROIDDEV_DRY_RUN:-0}" = 1 ]; then
        printf '%s[dry-run]%s (cd %s && cap sync android)\n' "$C_YELLOW" "$C_RESET" "$root"
        printf '%s[dry-run]%s (cd %s/android && JAVA_HOME=%s ./gradlew assembleDebug)\n' \
            "$C_YELLOW" "$C_RESET" "$root" "$jdk"
        return 0
    fi

    info "Sincronizando assets web y Capacitor..."
    (
        cd "$root"
        export ANDROID_HOME="$sdk"
        export ANDROID_SDK_ROOT="$sdk"
        export JAVA_HOME="$jdk"
        "$cap_bin" sync android
    ) || die "Falló cap sync android."

    info "Compilando con Gradle (JDK 21: $jdk)..."
    gradlew="$root/android/gradlew"
    [ -f "$gradlew" ] || die "No se encontró gradlew en $root/android."
    (
        cd "$root/android"
        export ANDROID_HOME="$sdk"
        export ANDROID_SDK_ROOT="$sdk"
        export JAVA_HOME="$jdk"
        bash "$gradlew" assembleDebug
    ) || die "Falló la compilación con Gradle."

    apk="$root/android/app/build/outputs/apk/debug/app-debug.apk"
    if [ ! -f "$apk" ]; then
        apk="$(find "$root/android/app/build/outputs/apk/debug" -maxdepth 1 -name '*.apk' -print -quit 2>/dev/null || true)"
    fi
    [ -n "$apk" ] && [ -f "$apk" ] || die "Gradle terminó pero no se encontró ningún APK."

    if [ "$no_copy" = 1 ]; then
        ok "APK generado: $apk"
        return 0
    fi

    dest_dir="${out:-${ANDROIDDEV_OUTPUT_DIR:-}}"
    [ -n "$dest_dir" ] || dest_dir="$(desktop_dir)"
    mkdir -p "$dest_dir" || die "No se pudo crear la carpeta de salida: $dest_dir"
    dest_dir="$(cd "$dest_dir" && pwd -P)"

    app_name="$(project_app_name "$root")"
    base="$(slugify_file "$app_name")-debug"
    target="$dest_dir/$base.apk"
    if [ -e "$target" ] && [ "$force" != 1 ]; then
        target="$dest_dir/$base-$(timestamp).apk"
    fi

    cp "$apk" "$target" || die "No se pudo copiar el APK a $target."
    ok "APK guardado en $target"
    printf '   Tamaño: %s\n' "$(du -h "$target" | cut -f1)"
}
