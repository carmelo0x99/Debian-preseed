#!/usr/bin/env bash 

# Source info:
# - https://wiki.debian.org/DebianInstaller/Preseed
# - https://wiki.debian.org/DebianInstaller/Preseed/EditIso

# Settings
set -e 

DEBVER="12.4.0"
DEBARCH="amd64"

RAW_DEBIAN_ISO="./source_iso/debian-$DEBVER-$DEBARCH-netinst.iso"

WORKDIR='./workdir'
LOOPDIR="./loopdir"
ISODIR="$WORKDIR/isodir"

PRESEED_FILE='./preseed.cfg'
PRESEED_ISO="./destination_iso/debian-$DEBVER-$DEBARCH-netinst-preseed.iso"


# Main

# Check whether the script is run as root or with sudo
if [[ $EUID > 0 ]]; then
    echo "[-] This script must be run as root or with sudo"
    exit 255
fi

# Clean-up `WORKDIR`
if [ -d "$WORKDIR" ]; then
#    chmod +w -R $WORKDIR
    sudo rm -rf $WORKDIR
fi

# Mount source ISO
echo "[+] Mounting $RAW_DEBIAN_ISO onto $LOOPDIR"
sudo mount $RAW_DEBIAN_ISO $LOOPDIR

# Copy image
mkdir -p $ISODIR
cp -rT "$LOOPDIR" "$ISODIR"
chmod +w -R $WORKDIR
sudo umount "$LOOPDIR"

# Patch initrd with the modified preseed file
gunzip $ISODIR/install.amd/initrd.gz
echo $PRESEED_FILE | cpio -H newc -o -A -F $ISODIR/install.amd/initrd &> /dev/null
gzip $ISODIR/install.amd/initrd

# Fix md5sum
PREVIOUS_WORKING_DIR=$(pwd)
cd $ISODIR
find . -type f -exec md5sum "{}" \; > md5sum.txt
cd $PREVIOUS_WORKING_DIR

# Fix grub.cfg
#sudo sed -i "1s/^/set timeout=3\nset default=1\n\n/" $ISODIR/boot/grub/grub.cfg

# Fix isolinux.cfg
sudo sed -i "s/default vesamenu.c32/default auto/" $ISODIR/isolinux/isolinux.cfg

# Create ISO
# IMPORTANT: the arguments passed to the -b and -c flags should be RELATIVE paths to the last argument
genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -input-charset utf-8 \
            -o "$PRESEED_ISO" "$ISODIR" &> /dev/null

echo "[+] Preseed config '$PRESEED_FILE' has been successfully merged into image '$PRESEED_ISO'"

