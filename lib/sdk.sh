#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Detección del SDK de Android y comprobación de componentes.

ANDROIDDEV_COMPILE_SDK="${ANDROIDDEV_COMPILE_SDK:-35}"
ANDROIDDEV_BUILD_TOOLS="${ANDROIDDEV_BUILD_TOOLS:-35.0.0}"

sdk_candidates() {
    local candidate
    for candidate in \
        "${ANDROIDDEV_SDK_DIR:-}" \
        "${ANDROID_HOME:-}" \
        "${ANDROID_SDK_ROOT:-}" \
        "$HOME/Android/Sdk" \
        "$HOME/android-sdk" \
        "$HOME/.local/share/android-sdk" \
        "/opt/android-sdk" \
        "/usr/lib/android-sdk"; do
        if [ -n "$candidate" ]; then
            printf '%s\n' "$candidate"
        fi
    done
    if have sdkmanager; then
        candidate="$(command -v sdkmanager)"
        candidate="$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")"
        candidate="$(dirname "$(dirname "$(dirname "$(dirname "$candidate")")")")"
        printf '%s\n' "$candidate"
    fi
    if have adb; then
        candidate="$(command -v adb)"
        candidate="$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")"
        candidate="$(dirname "$(dirname "$candidate")")"
        printf '%s\n' "$candidate"
    fi
}

is_android_sdk() {
    local dir="$1"
    [ -d "$dir" ] || return 1
    [ -d "$dir/platform-tools" ] || [ -d "$dir/cmdline-tools" ] || [ -d "$dir/platforms" ]
}

find_android_sdk() {
    local candidate
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if is_android_sdk "$candidate"; then
            (cd "$candidate" && pwd -P)
            return 0
        fi
    done < <(sdk_candidates | awk 'NF && !seen[$0]++')
    return 1
}

find_sdkmanager() {
    local sdk="$1" candidate
    for candidate in "$sdk"/cmdline-tools/latest/bin/sdkmanager "$sdk"/cmdline-tools/*/bin/sdkmanager; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    if have sdkmanager; then
        command -v sdkmanager
        return 0
    fi
    return 1
}

sdk_build_tools() {
    local sdk="$1"
    [ -d "$sdk/build-tools" ] || return 1
    find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V | tail -n1
}

sdk_platform() {
    local sdk="$1"
    [ -d "$sdk/platforms" ] || return 1
    find "$sdk/platforms" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sed -n 's/^android-//p' | sort -n | tail -n1
}

sdk_has_licenses() {
    local sdk="$1"
    [ -s "$sdk/licenses/android-sdk-license" ]
}

sdk_metadata_json() {
    local sdk="$1"
    local adb="no" sdkmanager="no" licenses="no"
    local build_tools platform cmdline
    [ -x "$sdk/platform-tools/adb" ] && adb="sí"
    if find_sdkmanager "$sdk" >/dev/null 2>&1; then
        sdkmanager="sí"
    fi
    sdk_has_licenses "$sdk" && licenses="sí"
    build_tools="$(sdk_build_tools "$sdk" || true)"
    platform="$(sdk_platform "$sdk" || true)"
    cmdline="no"
    [ -d "$sdk/cmdline-tools" ] && cmdline="sí"
    printf 'adb=%s sdkmanager=%s cmdline-tools=%s licenses=%s build-tools=%s platform=%s\n' \
        "$adb" "$sdkmanager" "$cmdline" "$licenses" "${build_tools:-ninguno}" "${platform:-ninguna}"
}

sdkmanager_hint() {
    local sdk="$1" sdkmanager
    if sdkmanager="$(find_sdkmanager "$sdk")"; then
        printf '%s --sdk_root=%s "platform-tools" "platforms;android-%s" "build-tools;%s"\n' \
            "$sdkmanager" "$sdk" "$ANDROIDDEV_COMPILE_SDK" "$ANDROIDDEV_BUILD_TOOLS"
    else
        printf 'No se encontró sdkmanager. Instala cmdline-tools en %s\n' "$sdk"
    fi
}

licenses_hint() {
    local sdk="$1" sdkmanager
    if sdkmanager="$(find_sdkmanager "$sdk")"; then
        printf 'yes | %s --sdk_root=%s --licenses\n' "$sdkmanager" "$sdk"
    else
        printf 'Instala cmdline-tools y ejecuta: sdkmanager --licenses\n'
    fi
}

escape_properties_value() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/:/\\:/g'
}

ensure_local_properties() {
    local root="$1" sdk="$2" props current tmp
    props="$root/android/local.properties"
    [ -d "$root/android" ] || return 1

    if [ -f "$props" ] && grep -q '^sdk.dir=' "$props"; then
        current="$(sed -n 's/^sdk.dir=//p' "$props" | head -n1)"
        current="${current//\\:/:}"
        if [ -d "$current" ] && is_android_sdk "$current"; then
            printf '%s\n' "$current"
            return 0
        fi
        warn "local.properties apunta a un SDK inválido: $current"
    fi

    tmp="$(mktemp "$props.androiddev.XXXXXX")"
    if [ -f "$props" ]; then
        grep -v '^sdk.dir=' "$props" >"$tmp" || true
    fi
    printf 'sdk.dir=%s\n' "$(escape_properties_value "$sdk")" >>"$tmp"
    chmod --reference="$props" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    mv "$tmp" "$props"
    printf '%s\n' "$sdk"
}

project_sdk() {
    local root="$1" sdk current props
    props="$root/android/local.properties"
    if [ -f "$props" ] && grep -q '^sdk.dir=' "$props"; then
        current="$(sed -n 's/^sdk.dir=//p' "$props" | head -n1)"
        current="${current//\\:/:}"
        if [ -d "$current" ] && is_android_sdk "$current"; then
            printf '%s\n' "$current"
            return 0
        fi
    fi
    if ! sdk="$(find_android_sdk)"; then
        return 1
    fi
    ensure_local_properties "$root" "$sdk"
}

require_android_sdk() {
    local sdk
    if sdk="$(find_android_sdk)"; then
        printf '%s\n' "$sdk"
        return 0
    fi
    err "No se encontró el SDK de Android."
    printf '  Define ANDROID_HOME o ANDROID_SDK_ROOT, o instala cmdline-tools en:\n' >&2
    printf '    ~/Android/Sdk\n' >&2
    printf '  Luego instala los paquetes con:\n' >&2
    printf '    sdkmanager "platform-tools" "platforms;android-%s" "build-tools;%s"\n' \
        "$ANDROIDDEV_COMPILE_SDK" "$ANDROIDDEV_BUILD_TOOLS" >&2
    return 1
}
