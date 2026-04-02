#!/bin/bash

# Test script for verifying if the driver is installed and active
echo "=================================================="
echo "    snd_hda_macbookpro Installation Verifier    "
echo "=================================================="

echo ""
echo "[0/3] Checking if the binary file (.ko) exists in the current kernel updates module tree..."
if [ -f "/lib/modules/$(uname -r)/updates/codecs/cirrus/snd-hda-codec-cs8409.ko" ] || \
   [ -f "/lib/modules/$(uname -r)/updates/snd-hda-codec-cs8409.ko" ] || \
   [ -f "/lib/modules/$(uname -r)/updates/dkms/snd-hda-codec-cs8409.ko" ]; then
    echo "  -> SUCCESS: Compiled driver file is physically installed."
else
    echo "  -> WARNING: Could not find 'snd-hda-codec-cs8409.ko' in the updates folder."
    echo "  -> Did you run 'sudo ./install.cirrus.driver.sh' properly?"
fi

echo ""
echo "[1/3] Verifying if module 'snd_hda_codec_cs8409' is loaded in the running kernel..."
if lsmod | grep -q "snd_hda_codec_cs8409"; then
    echo "  -> SUCCESS: Module is active."
else
    echo "  -> WARNING: Module is NOT currently loaded! If you just installed it, please reboot."
    echo "  -> Alternatively, try: sudo modprobe snd-hda-codec-cs8409"
fi

echo ""
echo "[2/3] Checking dmesg for Cirrus Logic hardware initialization logs..."
if dmesg | grep -i "cs8409" > /dev/null; then
    echo "  -> SUCCESS: Found 'cs8409' hardware diagnostic logs."
    echo "  ------------- Last 3 logs: ---------------------"
    dmesg | grep -i "cs8409" | tail -n 3
    echo "  ------------------------------------------------"
else
    echo "  -> WARNING: No hardware logs found! The driver might not have successfully probed the internal DAC/Amp chips."
fi

echo ""
echo "[3/3] Checking ALSA detected audio playback cards..."
if aplay -l | grep -i -E "cs8409|cirrus"; then
    echo "  -> SUCCESS: ALSA specifically recognized a Cirrus / CS8409 playback path!"
else
    echo "  -> NOTE: Playback might be wrapped inside a generic 'HDA Intel PCH' card description."
    echo "  -> Check your audio settings panel (e.g. PulseAudio/Pipewire) for 'Analogue Stereo / Headphones'."
fi

echo ""
echo "Verification complete."
