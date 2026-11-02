#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Detección y validación de JDK 21.

java_version_of() {
    local bin="$1" out version
    [ -x "$bin" ] || return 1
    out="$("$bin" -version 2>&1)" || return 1
    version="$(printf '%s\n' "$out" | sed -n 's/.*version "\([^"]*\)".*/\1/p' | head -n1)"
    [ -n "$version" ] || return 1
    case "$version" in
        1.*) printf '%s\n' "$version" | cut -d. -f2 ;;
        *) printf '%s\n' "$version" | sed 's/[^0-9].*//' ;;
    esac
}

java_home_from_bin() {
    local bin="$1" home
    home="$("$bin" -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java.home = //p' | head -n1)"
    if [ -n "$home" ] && [ -x "$home/bin/java" ]; then
        printf '%s\n' "$home"
        return 0
    fi
    if [ -L "$bin" ] || [ -x "$bin" ]; then
        bin="$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")"
    fi
    dirname "$(dirname "$bin")"
}

normalize_jdk_candidate() {
    local candidate="$1"
    if [ -d "$candidate" ] && [ -x "$candidate/bin/java" ]; then
        (cd "$candidate" && pwd -P)
        return 0
    fi
    if [ -x "$candidate" ]; then
        java_home_from_bin "$candidate"
        return 0
    fi
    return 1
}

jdk_candidates() {
    local candidate
    for candidate in "${ANDROIDDEV_JAVA_HOME:-}" "${JAVA_HOME:-}"; do
        if [ -n "$candidate" ]; then
            normalize_jdk_candidate "$candidate" || true
        fi
    done
    if have java; then
        candidate="$(command -v java)"
        normalize_jdk_candidate "$candidate" || true
    fi
    for candidate in \
        /usr/lib/jvm/* \
        /usr/lib64/jvm/* \
        /usr/java/* \
        /opt/java/* \
        /opt/jdk* \
        /opt/android-studio/jbr \
        /usr/lib/android-studio/jbr \
        /snap/android-studio/current/android-studio/jbr; do
        if [ -e "$candidate" ]; then
            normalize_jdk_candidate "$candidate" || true
        fi
    done
    for candidate in \
        "$HOME"/.sdkman/candidates/java/* \
        "$HOME"/.jdks/* \
        "$HOME"/.local/share/JetBrains/Toolbox/apps/AndroidStudio/*/jbr; do
        if [ -e "$candidate" ]; then
            normalize_jdk_candidate "$candidate" || true
        fi
    done
}

jdk_candidates_unique() {
    jdk_candidates | awk 'NF && !seen[$0]++'
}

find_jdk21() {
    local candidate major
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        [ -x "$candidate/bin/java" ] || continue
        major="$(java_version_of "$candidate/bin/java" 2>/dev/null || true)"
        if [ "$major" = 21 ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(jdk_candidates_unique)
    return 1
}

list_jdks() {
    local candidate major
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        [ -x "$candidate/bin/java" ] || continue
        major="$(java_version_of "$candidate/bin/java" 2>/dev/null || true)"
        if [ -n "$major" ]; then
            printf '  - JDK %s: %s\n' "$major" "$candidate"
        fi
    done < <(jdk_candidates_unique)
}

jdk21_install_hint() {
    tool_install_hint "${PM:-desconocido}" jdk21
}

require_jdk21() {
    local jdk
    if jdk="$(find_jdk21)"; then
        printf '%s\n' "$jdk"
        return 0
    fi
    err "No se encontró un JDK 21."
    printf '  Instálalo con:\n    %s\n' "$(jdk21_install_hint)" >&2
    printf '  Si ya lo tienes en una ruta no habitual:\n    export ANDROIDDEV_JAVA_HOME=/ruta/al/jdk-21\n' >&2
    return 1
}
