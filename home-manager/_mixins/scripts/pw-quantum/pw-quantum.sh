#!/usr/bin/env bash
# Obsolete as the pipewire configuration is now tuned in the NixOS configuration

set +u

# Use pw-top to monitor
QUANT=2048


#pw-metadata -n settings 0 clock.min-quantum $((${QUANT} / 2))
#pw-metadata -n settings 0 clock.quantum     ${QUANT}
#pw-metadata -n settings 0 clock.max-quantum $((${QUANT} * 2))

pw-metadata -n settings 0 clock.min-quantum "${QUANT}"
pw-metadata -n settings 0 clock.quantum     "${QUANT}"
pw-metadata -n settings 0 clock.max-quantum "${QUANT}"
