# snd_hda_macbookpro

This is a kernel driver for sound on Macs with Cirrus 8409 HDA chips.
Sound output is now reasonably complete and integrated with Linux.
Sound input still needs work.


It will play audio through Internal speakers or headphones.

The primary audio should be set to Analogue Stereo Output in the Settings Audio dialog. Alternatively, if you want to use the internal microphone, set it to Analogue Stereo Duplex.

Sound recording from internal mike and headset mike is not yet fully interfaced with Linux user side.

The recorded sound level is very low but this is the sound level as returned in OSX.
Amplification will be required eg using something like PulseEffects.


The hardware device sound format is limited to 2/4 channel 44.1 kHz S24_LE S32_LE.
As long as use the default device volume control, other formats, frequencies work.


NOTA BENE: The direct hardware device (hw:0,0) and plughw:0,0 device have NO volume control so will be VERY loud!


Currently this works with MAX98706, SSM3515 and TAS5764L amplifiers.
It will NOT work with other amplifiers as each amplifier requires specific programming.


Power down/sleep completely unknown and untested.
At the moment everything is permanently powered on.


The Apple speaker setup is 4 speakers as a left tweeter, left woofer, right tweeter and right woofer
so this is actually a classic HiFi stereo (ie 2 channel) speaker system.
(These names are listed in the layout files under AppleHDA.kext/Contents/Resources).

The channel order for Linux has been modified to left tweeter, right tweeter and left woofer, right woofer
as this fits in with the Linux way much better.

The driver also has been modified to duplicate a stereo sound source onto the second stereo channel so all
speakers are driven (this essentially replicates the snd_hda_multi_out_analog_prepare function).

This will not sound the same as Apple (which is known to be using specific digital filter effects in CoreAudio).

To create a more Apple-like sound requires creating eg an Alsa pseudo device to channel duplicate a stereo sound
and apply different digital filters to the tweeter and woofer channels.


NOTE. My primary testing kernel is now Ubuntu LTS 24.04 6.8.


NOTA BENE. As of linux kernel 6.17 the sound kernel source directory has been completely re-organized.
           The installation script now works for 6.17 kernel versions (and later when they arrive).
           The old installation script is now called install.cirrus.driver.pre617.sh.
           The new version of the install.cirrus.driver.sh script will detect your kernel version and exec
           the old installation script as needed.
           Note that for kernel version 6.17 new files and directories have been added to the repo
           rather than attempting to update the pre 6.17 versions.

NOTA BENE (LINUX 7.0+): For bleeding-edge kernel versions like 7.0.x, the codebase compiles cleanly.
           If the script `install.cirrus.driver.sh` cannot find `linux-source-7.x.x` already installed
           on your system, it will automatically download and extract it from the Ubuntu repositories
           via `apt-get download` — no manual intervention required.

TESTING: After compiling/installing the driver, a test script is provided.
         Run `./tests/verify-installation.sh` to check if `snd_hda_codec_cs8409` works!

The following installation setup provided by leifliddy.


## Fresh Install Quick Start (Ubuntu 26.04 Raccoon)

On a brand new Ubuntu 26.04 installation on a MacBook Pro, run these commands in order:

**Step 1 — Install dependencies:**
```bash
sudo apt-get update && sudo apt-get install -y build-essential linux-headers-$(uname -r) make patch wget
```

**Step 2 — Clone this repository:**
```bash
git clone https://github.com/vrila1985-png/snd_hda_macbookpro.git
cd snd_hda_macbookpro
```

**Step 3 — Install the Cirrus Logic audio driver:**
```bash
sudo ./install.cirrus.driver.sh
```

**Step 4 — Install all remaining hardware drivers** (GPU VA-API, Bluetooth/AirPods fix, FaceTime HD Camera, Thunderbolt 3, battery management, screen brightness):
```bash
sudo ./macbook_hardware_fixer.sh
```

**Step 5 — Reboot:**
```bash
sudo reboot
```

**Step 6 — Verify the audio driver is working:**
```bash
./tests/verify-installation.sh
```


Compiling and installing driver:
-------------

**fedora package install**
```
dnf install gcc kernel-devel make patch wget
```
**ubuntu / ubuntu-based package install**  
```
sudo apt install build-essential linux-headers-$(uname -r) make patch wget
```
**arch package install**
```
pacman -S gcc linux-headers make patch wget
```
**void package install**
```
xbps-install -S gcc make linux-headers patch wget
```

**build driver**  
```
git clone https://github.com/davidjo/snd_hda_macbookpro.git
cd snd_hda_macbookpro/
#run the following command as root or with sudo
./install.cirrus.driver.sh
reboot
```

**Deleting driver**
```
# Check your kernel version
uname -a
# delete the ko file
sudo rm /lib/modules/{kernel version}/updates/snd-hda-codec-cs8409.ko
sudo depmod -a
```

Dynamic Kernel Module Support (dkms):
-------------

dkms is a framework which allows kernel modules to be dynamically built for each kernel on your system.
See here for more details: https://github.com/dell/dkms
You will need to first install dkms on your system

**install driver via dkms**
```
sudo ./install.cirrus.driver.sh -i
```

**remove driver from dkms**
```
sudo ./install.cirrus.driver.sh -r
```

