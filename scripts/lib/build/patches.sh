#!/bin/bash

function patches() {
    local pkgname="${1}"

    if [ "${BUILD_ARCH}" = "x86-64-v3" ]
    then
        patches-x86-64-v3 "${pkgname}"
    else
        patches-x86-64 "${pkgname}"
    fi

    patches-all
}

# Patches for a `x86-64-v3` arch
function patches-x86-64-v3() {
    local pkgname="${1}"

    case "${pkgname}" in
        "proton"* | "dxvk-mingw" | "vkd3d-proton-mingw" | "wine-ge-custom")
            echo "[i] march patch"
            sed -i 's|-march=nocona -mtune=core-avx2|-march=x86-64-v3|g' PKGBUILD
            ;;
        "linux-xanmod"*)
            export _microarchitecture=93
            ;;
    esac
}

# Patches for a `x86-64` arch
function patches-x86-64() {
    local pkgname="${1}"

    case "${pkgname}" in
        "linux-xanmod"*)
            export _microarchitecture=0
            ;;
    esac
}

# Patches for all arches
function patches-all() {
    local pkgname="${1}"

    case "${pkgname}" in
        "winesync")
            export _microarchitecture=0
            ;;
    esac
}
