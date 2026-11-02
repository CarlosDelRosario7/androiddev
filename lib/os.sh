#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Detección de distro, gestor de paquetes y ayudas de instalación.
# shellcheck disable=SC2034

load_os_release() {
    OS_ID="linux"
    OS_LIKE=""
    OS_NAME="Linux"
    if [ -r /etc/os-release ]; then
        local key val
        while IFS='=' read -r key val; do
            val="${val%\"}"
            val="${val#\"}"
            val="${val%\'}"
            val="${val#\'}"
            case "$key" in
                ID) OS_ID="$val" ;;
                ID_LIKE) OS_LIKE="$val" ;;
                PRETTY_NAME) OS_NAME="$val" ;;
            esac
        done </etc/os-release
    fi
    PM="$(detect_pm)"
}

detect_pm() {
    if have apt-get; then
        printf 'apt\n'
    elif have dnf; then
        printf 'dnf\n'
    elif have yum; then
        printf 'yum\n'
    elif have pacman; then
        printf 'pacman\n'
    elif have zypper; then
        printf 'zypper\n'
    elif have apk; then
        printf 'apk\n'
    elif have xbps-install; then
        printf 'xbps\n'
    elif have emerge; then
        printf 'emerge\n'
    elif have nix-env; then
        printf 'nix\n'
    else
        printf 'desconocido\n'
    fi
}

pm_family() {
    case "${1:-}" in
        apt) printf 'Debian/Ubuntu/Kali\n' ;;
        dnf | yum) printf 'Fedora/RHEL\n' ;;
        pacman) printf 'Arch/Manjaro\n' ;;
        zypper) printf 'openSUSE/SLES\n' ;;
        apk) printf 'Alpine\n' ;;
        xbps) printf 'Void\n' ;;
        emerge) printf 'Gentoo\n' ;;
        nix) printf 'NixOS\n' ;;
        *) printf 'desconocida\n' ;;
    esac
}

is_wsl() {
    [ -r /proc/version ] && grep -qi microsoft /proc/version
}

pkg_name() {
    local pm="$1" tool="$2"
    case "$pm:$tool" in
        *:jdk21)
            case "$pm" in
                apt) printf 'openjdk-21-jdk\n' ;;
                dnf | yum | zypper) printf 'java-21-openjdk-devel\n' ;;
                pacman) printf 'jdk21-openjdk\n' ;;
                apk) printf 'openjdk21\n' ;;
                xbps) printf 'openjdk21\n' ;;
                emerge) printf 'dev-java/openjdk-bin:21\n' ;;
                nix) printf 'jdk21\n' ;;
                *) printf 'openjdk-21\n' ;;
            esac
            ;;
        *:node)
            case "$pm" in
                apt | dnf | yum | pacman | zypper | apk | xbps) printf 'nodejs npm\n' ;;
                emerge) printf 'net-libs/nodejs\n' ;;
                nix) printf 'nodejs_22\n' ;;
                *) printf 'nodejs\n' ;;
            esac
            ;;
        *:unzip) printf 'unzip\n' ;;
        *:curl) printf 'curl\n' ;;
        *:git) printf 'git\n' ;;
        *:adb)
            case "$pm" in
                apt) printf 'android-tools-adb\n' ;;
                dnf | yum | zypper | pacman | apk) printf 'android-tools\n' ;;
                *) printf 'android-tools\n' ;;
            esac
            ;;
        *) printf '%s\n' "$tool" ;;
    esac
}

install_hint() {
    local pm="$1"
    shift
    local packages="$*"
    case "$pm" in
        apt) printf 'sudo apt update && sudo apt install -y %s\n' "$packages" ;;
        dnf) printf 'sudo dnf install -y %s\n' "$packages" ;;
        yum) printf 'sudo yum install -y %s\n' "$packages" ;;
        pacman) printf 'sudo pacman -S --needed %s\n' "$packages" ;;
        zypper) printf 'sudo zypper install -y %s\n' "$packages" ;;
        apk) printf 'sudo apk add %s\n' "$packages" ;;
        xbps) printf 'sudo xbps-install -S %s\n' "$packages" ;;
        emerge) printf 'sudo emerge -av %s\n' "$packages" ;;
        nix) printf 'nix-env -iA %s\n' "$packages" ;;
        *) printf 'Instala manualmente: %s\n' "$packages" ;;
    esac
}

tool_install_hint() {
    local pm="$1" tool="$2"
    local packages
    packages="$(pkg_name "$pm" "$tool")"
    install_hint "$pm" "$packages"
}
