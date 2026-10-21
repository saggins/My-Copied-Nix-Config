#!/usr/bin/env bash

function usage() {
    echo "Usage: ${0} {build|switch} [remote-host]"
    exit 1
}

# Validate input argument
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

if [ "${1}" != "build" ] && [ "${1}" != "switch" ]; then
    echo "Invalid argument: ${1}"
    usage
fi

if [ -e "${HOME}/Zero/nix-config" ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    if [ -n "${2:-}" ]; then
        # Build locally, deploy over SSH; host is the flake name or its MagicDNS FQDN
        host="${2%%.*}"
        echo "${1^}ing NixOS for ${host} via ${2} with ${build_cores} cores"
        nh os "${1}" --hostname "${host}" --target-host "${USER}@${2}" "${HOME}/Zero/nix-config/" -- --cores "${build_cores}"
    else
        echo "${1^}ing NixOS  with ${build_cores} cores"
        nh os "${1}" "${HOME}/Zero/nix-config/" -- --cores "${build_cores}"
    fi
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
