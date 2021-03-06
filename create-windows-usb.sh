#
# credits goto the original author
# https://ypcs.fi/howto/2018/12/01/windowsiso/

ISOFILE="$1"
USBDEVICE="$2"
TEMPDIR="$(mktemp -d winimage-XXXXXX)"
SOURCE="source"
TARGET="target"

# Directory for mounting the ISO image
mkdir "${SOURCE}"

# Directory for mounting the USB stick
mkdir "${TARGET}"

# Create GPT partition table, one FAT32 partition that uses 100% of available space
# first create msdos table to ensure that existing table is purged
parted --script "${USBDEVICE}" mklabel msdos
parted --script "${USBDEVICE}" mklabel gpt
parted --script "${USBDEVICE}" mkpart primary fat32 1 100%
parted --script "${USBDEVICE}" set 1 msftdata on

# Just to make sure that partition is correctly formatted as FAT32
mkfs.vfat "${USBDEVICE}1"

# Mount Windows ISO image for file copying
mount -oloop "${ISOFILE}" "${SOURCE}"

# Mount USB stick, partition 1
mount "${USBDEVICE}1" "${TARGET}"

# Copy all files from ISO image to temporary directory
rsync -avh --no-o --no-g "${SOURCE}/" "${TEMPDIR}/"

# Split the install.wim file to smaller parts (max 250MB), to temporary directory
wimlib-imagex split "${TEMPDIR}/sources/install.wim" "${TEMPDIR}/sources/install.swm" 250

# Finally, copy resulting data structure, without large file (install.wim) to the USB stick
rsync -avh --no-o --no-g --exclude="install.wim" "${TEMPDIR}/" "${TARGET}/"

# Ensure that everything has been written to disk
sync
sync

# Unmount, your stick is ready now
umount "${SOURCE}"
umount "${TARGET}"
rm -rf "${TEMPDIR}"
