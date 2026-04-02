#!/bin/bash

# =================================================================
# snd_hda_macbookpro Installation Verifier
# Checks that the Cirrus Logic CS8409 audio driver is properly
# installed and active on the running system.
# =================================================================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}-> SUCCESS:${NC} $1"; ((PASS++)); }
warn() { echo -e "  ${YELLOW}-> WARNING:${NC} $1"; ((FAIL++)); }
info() { echo -e "  ${BLUE}-> NOTE:${NC}    $1"; }

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}    snd_hda_macbookpro Installation Verifier    ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# ------------------------------------------------------------
# [0/3] Check if the compiled .ko file exists on disk
# (supports plain .ko, compressed .ko.zst and .ko.gz variants)
# ------------------------------------------------------------
echo "[0/3] Checking if the driver binary (.ko) exists in the kernel module tree..."
KO_FOUND=false
for ko_path in \
    "/lib/modules/$(uname -r)/updates/codecs/cirrus/snd-hda-codec-cs8409.ko" \
    "/lib/modules/$(uname -r)/updates/codecs/cirrus/snd-hda-codec-cs8409.ko.zst" \
    "/lib/modules/$(uname -r)/updates/codecs/cirrus/snd-hda-codec-cs8409.ko.gz" \
    "/lib/modules/$(uname -r)/updates/snd-hda-codec-cs8409.ko" \
    "/lib/modules/$(uname -r)/updates/dkms/snd-hda-codec-cs8409.ko" \
    "/lib/modules/$(uname -r)/updates/dkms/snd-hda-codec-cs8409.ko.zst" \
    "/lib/modules/$(uname -r)/updates/dkms/snd-hda-codec-cs8409.ko.gz"; do
    if [ -f "$ko_path" ]; then
        pass "Compiled driver found at: $ko_path"
        KO_FOUND=true
        break
    fi
done
if [ "$KO_FOUND" = false ]; then
    warn "Could not find 'snd-hda-codec-cs8409.ko' (or .ko.zst/.ko.gz) in the updates folder."
    info "Did you run 'sudo ./install.cirrus.driver.sh' from the project root?"
fi

echo ""

# ------------------------------------------------------------
# [1/3] Check if the module is currently loaded in the kernel
# ------------------------------------------------------------
echo "[1/3] Verifying if module 'snd_hda_codec_cs8409' is loaded in the running kernel..."
if lsmod | grep -q "snd_hda_codec_cs8409"; then
    pass "Module is active and loaded."
else
    warn "Module is NOT currently loaded."
    info "If you just installed it, reboot or try: sudo modprobe snd-hda-codec-cs8409"
fi

echo ""

# ------------------------------------------------------------
# [2/3] Check dmesg for hardware probe logs
# ------------------------------------------------------------
echo "[2/3] Checking dmesg for Cirrus Logic CS8409 hardware initialization logs..."
if dmesg | grep -qi "cs8409"; then
    pass "Found 'cs8409' hardware diagnostic logs in dmesg."
    echo    "  ------------- Last 3 log entries: ---------------------"
    dmesg | grep -i "cs8409" | tail -n 3 | sed 's/^/    /'
    echo    "  -------------------------------------------------------"
else
    warn "No CS8409 hardware logs found in dmesg."
    info "The driver might not have probed the hardware. Check that you are on a supported Mac model."
fi

echo ""

# ------------------------------------------------------------
# [3/3] Check ALSA sees the sound card
# ------------------------------------------------------------
echo "[3/3] Checking ALSA for CS8409 audio playback card..."
if aplay -l 2>/dev/null | grep -qi -E "cs8409|cirrus"; then
    pass "ALSA specifically recognized a Cirrus / CS8409 playback path!"
    aplay -l 2>/dev/null | grep -i -E "cs8409|cirrus" | sed 's/^/    /'
else
    info "Playback might be wrapped inside a generic 'HDA Intel PCH' card."
    info "Check Settings -> Sound and look for 'Analogue Stereo Output' or 'Headphones'."
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All checks passed! ($PASS passed, $FAIL warnings)${NC}"
    echo -e "${BLUE}==================================================${NC}"
    exit 0
else
    echo -e "${YELLOW}Completed with warnings ($PASS passed, $FAIL warnings)${NC}"
    echo -e "${BLUE}==================================================${NC}"
    exit 1
fi
