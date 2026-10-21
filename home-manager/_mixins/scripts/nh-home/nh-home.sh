#!/usr/bin/env bash

STAMP=$(date +%Y%m%d-%H%M%S)

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

# Proceed if the nix-config directory exists
if [ -e "${HOME}/Zero/nix-config" ]; then
    # Get the number of processing units
    case "$(uname -s)" in
        Linux)  all_cores=$(nproc);;
        Darwin) all_cores=$(sysctl -n hw.logicalcpu);;
    esac
    # Calculate 75% of the number of processing units
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")

    if [ -n "${2:-}" ]; then
        # nh home can't deploy remotely; build here, copy the closure, activate there
        # host is the flake name or its MagicDNS FQDN
        remote="${USER}@${2}"
        config="${USER}@${2%%.*}"
        echo "${1^}ing Home Manager for ${remote} with ${build_cores} cores"
        hm=$(nix build --no-link --print-out-paths --cores "${build_cores}" \
            "${HOME}/Zero/nix-config#homeConfigurations.\"${config}\".activationPackage")
        if [ "${1}" = "switch" ]; then
            nix copy --to "ssh-ng://${remote}" "${hm}"
            # Expand STAMP and hm locally on purpose; NIX_SSHOPTS is word-split on purpose
            # shellcheck disable=SC2029,SC2086
            ssh ${NIX_SSHOPTS:-} "${remote}" "HOME_MANAGER_BACKUP_EXT=${STAMP} ${hm}/activate"
        else
            echo "${hm}"
        fi
    else
        echo "${1^}ing Home Manager  with ${build_cores} cores"
        case $1 in
            build) nh home build "${HOME}/Zero/nix-config/" -- --cores "${build_cores}";;
            switch) nh home switch --backup-extension "${STAMP}" "${HOME}/Zero/nix-config/" -- --cores "${build_cores}";;
        esac
    fi
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
