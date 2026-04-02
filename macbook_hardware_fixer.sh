#!/bin/bash
# =============================================================================
# MacBook Pro Ubuntu Hardware Fixer v2.0
# For: MacBook Pro 13" 2017 (MacBookPro14,1) on Ubuntu 26.04 Raccoon
#
# What this script does:
#   1. Intel Iris Plus 640 GPU — install VA-API acceleration tools
#   2. Bluetooth Broadcom BCM4350 — fix AirPods disconnections (PipeWire fix)
#   3. FaceTime HD Camera (Broadcom PCIe) — compile & install driver
#   4. Thunderbolt 3 (Alpine Ridge) — install bolt authorization daemon
#   5. Battery & Thermal — install TLP + thermald for MacBook-like efficiency
#   6. Screen Brightness Keys — install brightnessctl
# =============================================================================

set -euo pipefail

# --- ANSI colours ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_step() { echo -e "\n${BOLD}${BLUE}>>> $1${NC}"; }
log_ok()   { echo -e "  ${GREEN}[✔]${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "  ${RED}[✘]${NC} $1"; }
log_info() { echo -e "  ${BLUE}[i]${NC} $1"; }

# --- Root check ---
if [ "$EUID" -ne 0 ]; then
    log_err "Please run as root: sudo ./macbook_hardware_fixer.sh"
    exit 1
fi

KERNEL=$(uname -r)

echo -e "${BOLD}"
echo "============================================================"
echo "   MacBook Pro Ubuntu Hardware Fixer v2.0                  "
echo "   MacBook Pro 13\" 2017 | Ubuntu 26.04 Raccoon | Kernel $KERNEL"
echo "============================================================"
echo -e "${NC}"

# =============================================================================
# STEP 1: System update + Intel GPU VA-API acceleration
# =============================================================================
log_step "1/6 — Intel Iris Plus 640 GPU — VA-API acceleration"

apt-get update -qq

PKGS_GPU=(
    mesa-utils
    vainfo
    intel-media-va-driver   # VA-API driver for Intel Gen 8+ (Kaby Lake)
    libva2
    libva-drm2
    i965-va-driver          # Older VA-API fallback for Intel HD/Iris gen
)
apt-get install -y --no-install-recommends "${PKGS_GPU[@]}"

log_ok "Intel GPU acceleration packages installed."
log_info "Run 'vainfo' after reboot to confirm hardware decoding is active."

# =============================================================================
# STEP 2: Bluetooth — Fix AirPods disconnections (PipeWire + bluez config)
# =============================================================================
log_step "2/6 — Bluetooth — Fixing AirPods Pro disconnections"

BT_CONF="/etc/bluetooth/main.conf"

if [ ! -f "$BT_CONF" ]; then
    log_err "Bluetooth config not found at $BT_CONF. Is bluez installed?"
else
    # Backup original config
    cp "$BT_CONF" "${BT_CONF}.bak-macbook-fixer"
    log_info "Backup saved: ${BT_CONF}.bak-macbook-fixer"

    # --- [General] section fixes ---
    # Remove any existing conflicting values first
    sed -i '/^ControllerMode\s*=/d' "$BT_CONF"
    sed -i '/^FastConnectable\s*=/d' "$BT_CONF"
    sed -i '/^AutoEnable\s*=/d' "$BT_CONF"

    # IMPORTANT: Keep ControllerMode = dual (NOT bredr!) so AirPods BLE pairing works
    # Insert correct settings after [General] line
    sed -i '/^\[General\]/a AutoEnable = true\nFastConnectable = true' "$BT_CONF"

    # --- [Policy] section fixes — improve reconnect behaviour ---
    sed -i '/^ReconnectAttempts\s*=/d' "$BT_CONF"
    sed -i '/^ReconnectIntervals\s*=/d' "$BT_CONF"
    sed -i '/^\[Policy\]/a ReconnectAttempts = 7\nReconnectIntervals = 1,2,4,8,16,32,64' "$BT_CONF"

    log_ok "Bluetooth config updated (dual mode preserved for AirPods BLE pairing)."

    # --- WirePlumber 0.5 config: disable auto-switch to HFP/HSP profile ---
    # AirPods disconnections are caused by WirePlumber switching from A2DP (music)
    # to HFP (microphone/phone) and failing to reconnect on Ubuntu.
    WP_CONF_DIR="/etc/wireplumber/wireplumber.conf.d"
    mkdir -p "$WP_CONF_DIR"

    cat > "$WP_CONF_DIR/51-airpods-fix.conf" << 'EOF'
# MacBook Hardware Fixer - AirPods Pro stability fix
# Disables automatic switch from A2DP (high-quality audio) to HFP (phone/mic)
# which causes the "ba merge ba nu merge" audio dropout on Ubuntu with bluez 5.85+
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}
EOF
    log_ok "WirePlumber A2DP fix applied: auto-switch to HFP disabled."
    log_info "AirPods will stay on high-quality A2DP audio profile."

    # Restart bluetooth daemon to apply main.conf changes
    systemctl restart bluetooth
    log_ok "Bluetooth daemon restarted."
fi

# =============================================================================
# STEP 3: FaceTime HD Camera (Broadcom 720p PCIe — 14e4:1570)
# =============================================================================
log_step "3/6 — FaceTime HD Camera — Broadcom PCIe driver (facetimehd)"

PKGS_BUILD=(git curl xz-utils cpio build-essential kmod libssl-dev)
apt-get install -y --no-install-recommends "${PKGS_BUILD[@]}" linux-headers-"$KERNEL"

WEBCAM_DIR="/tmp/macbook_webcam_$$"
mkdir -p "$WEBCAM_DIR"

(
    cd "$WEBCAM_DIR"

    # -- Firmware (extracts from Apple's driver package) --
    log_info "Downloading facetimehd firmware extractor..."
    git clone --depth=1 https://github.com/patjak/facetimehd-firmware.git -q
    cd facetimehd-firmware

    set +e
    make 2>&1
    MAKE_FW_RC=$?
    set -e

    if [ $MAKE_FW_RC -ne 0 ]; then
        log_warn "Firmware extraction failed. The Apple firmware download may have changed URL."
        log_warn "Camera will NOT be available until this is resolved."
    else
        make install 2>&1
        log_ok "FaceTime HD firmware installed."
    fi

    cd "$WEBCAM_DIR"

    # -- Kernel module --
    log_info "Cloning facetimehd kernel module (for kernel $KERNEL)..."
    git clone --depth=1 https://github.com/patjak/facetimehd.git -q
    cd facetimehd

    set +e
    make KERNELRELEASE="$KERNEL" 2>&1
    MAKE_MOD_RC=$?
    set -e

    if [ $MAKE_MOD_RC -ne 0 ]; then
        log_warn "facetimehd kernel module failed to compile on kernel $KERNEL."
        log_warn "This is expected if the kernel is newer than the module supports."
        log_warn "Check: https://github.com/patjak/facetimehd for updates."
        log_warn "Camera will NOT be available. You may try again after a kernel update."
    else
        make install 2>&1
        depmod -a
        modprobe facetimehd && log_ok "facetimehd module loaded! Camera should now work." \
            || log_warn "Module installed but could not be loaded immediately. Try after reboot."
    fi
)

rm -rf "$WEBCAM_DIR"

# =============================================================================
# STEP 4: Thunderbolt 3 (Intel Alpine Ridge 4C) — bolt daemon
# =============================================================================
log_step "4/6 — Thunderbolt 3 — Installing bolt authorization daemon"

apt-get install -y --no-install-recommends bolt
# bolt uses D-Bus activation, NOT systemctl enable — starting it manually here
systemctl start bolt 2>/dev/null || true
log_ok "bolt installed. It activates automatically via D-Bus when a TB3 device is connected."
log_info "To authorize a Thunderbolt device: run 'boltctl enroll <device-uuid>'"
log_info "Or use GNOME Settings → Privacy → Thunderbolt."

# =============================================================================
# STEP 5: Battery & Thermal Management
# =============================================================================
log_step "5/6 — Battery & Thermal — TLP + thermald"

# TLP conflicts with power-profiles-daemon (GNOME default). Warn before removing.
if dpkg -l power-profiles-daemon &>/dev/null; then
    log_warn "TLP requires removing 'power-profiles-daemon' (GNOME default power manager)."
    log_warn "GNOME Settings → Power will still work, but profile switching will be handled by TLP instead."
fi

apt-get install -y --no-install-recommends tlp tlp-rdw thermald powertop
systemctl enable --now tlp
systemctl enable --now thermald
log_ok "TLP battery management enabled (replaces power-profiles-daemon)."
log_ok "thermald CPU thermal management enabled."
log_info "Run 'sudo powertop' to see per-process power usage."
log_info "TLP config file: /etc/tlp.conf — customize charging thresholds there."

# =============================================================================
# STEP 6: Screen brightness keys (F1/F2 on MacBook)
# =============================================================================
log_step "6/6 — Screen Brightness — brightnessctl"

# brightness-udev makes brightness setting persist across reboots (prevent reset to 100%)
apt-get install -y --no-install-recommends brightnessctl brightness-udev
# Add user to video group so brightness can be changed without sudo
REAL_USER="${SUDO_USER:-}"
if [ -n "$REAL_USER" ]; then
    usermod -aG video "$REAL_USER"
    log_ok "User '$REAL_USER' added to 'video' group (brightness without sudo)."
fi
log_ok "brightnessctl + brightness-udev installed (brightness persists across reboots)."
log_info "Test with: brightnessctl set 50%"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN}   All done! Hardware configuration complete.               ${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo ""
echo -e "  ${GREEN}[✔]${NC} Intel GPU VA-API acceleration"
echo -e "  ${GREEN}[✔]${NC} Bluetooth — AirPods stabilized (A2DP locked, no HFP drops)"
echo -e "  ${GREEN}[✔]${NC} FaceTime HD Camera driver attempted (see warnings above)"
echo -e "  ${GREEN}[✔]${NC} Thunderbolt 3 bolt daemon"
echo -e "  ${GREEN}[✔]${NC} TLP battery & thermald CPU management"
echo -e "  ${GREEN}[✔]${NC} Screen brightness control"
echo ""
echo -e "  ${YELLOW}[!]${NC} ${BOLD}Please REBOOT your MacBook now for all changes to take effect.${NC}"
echo ""
