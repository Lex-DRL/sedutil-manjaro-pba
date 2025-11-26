#!/bin/bash
set -e # Stop on any error

SCRIPT_PATH="$(realpath $0)"
SCRIPT_VERSION='0.0.1'

ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
LATEST_STABLE_DIR_URL="$ALPINE_MIRROR/latest-stable/releases/x86_64"
IMG_SIZE_MB=32
FAT_VER=16

# ------------------------------

ALPINE_VERSION=''
ALPINE_STANDARD_ISO_URL=''
ALPINE_MINIROOTFS_TGZ_URL=''
LOOP_DEV=''
LOOP_EFI=''
SEDUTIL_VERSION=''

PWD="$(pwd)"
BUILD_DIR="$PWD/bld"
DOWNLOAD_DIR="$PWD/download"

ROOTFS_DIR="$BUILD_DIR/rootfs"
MOUNT_ISO_DIR="$PWD/iso_mount"
MOUNT_OUT_EFI_DIR="$PWD/efi_mount"
EFI_BOOT_DIR="$MOUNT_OUT_EFI_DIR/EFI/boot"

OUTPUT_IMG="$PWD/UEFI64-alpine.img"

# Downloads - preserved after build:
FILE_MINIROOTFS_GZ="$DOWNLOAD_DIR/alpine-minirootfs.tar.gz"
FILE_STANDARD_ISO="$DOWNLOAD_DIR/alpine-standard.iso"
FILE_DL_VERSION="$DOWNLOAD_DIR/alpine.version"
# Downloads - temporary extracted to build dir:
FILE_EXTRACTED_KERNEL="$BUILD_DIR/vmlinuz-lts"

# ------------------------------

echo ''
echo 'This build script is intended to be run under Arch-based Linux distro (Manjaro assumed),'
echo 'while also booted from a 64-bit UEFI, from an EFI partition on GPT-partitioned drive.'
echo '------------------------------'
echo "$SCRIPT_PATH"
echo '------------------------------'
echo "About to build bootable image based on Alpine Linux..."
echo "Running under: $(uname -o)-$(uname -r)-$(uname -m)"
echo "Working directory: $PWD"
echo "Download directory: $DOWNLOAD_DIR"
echo "Build directory: $BUILD_DIR"

echo ''
echo 'Continue? (Enter / Ctrl+C)'
read

mkdir -p "$DOWNLOAD_DIR" # Don't clean it up if it's already there
sudo rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ------------------------------

install_pkgs() {
	echo ''
	echo "Installing essential dependencies..."
	sudo pacman -Syyu --needed --noconfirm git yay
	echo ''
	echo "Installing <sedutil> with <yay>..."
	yay -Su --needed --noconfirm sedutil
	# echo ''
	# echo "Installing optional dependencies for <sedutil>..."
	# sudo pacman -Su --needed --noconfirm --asdeps syslinux gptfdisk parted intel-ucode amd-ucode dosfstools mtools util-linux
	SEDUTIL_VERSION="$(sedutil-cli --version | grep -oE '[0-9]+(\.[0-9]+)*$')"
}


# setup_alpine_aports() {
# 	echo ''
# 	echo "Setting up Alpine build environment..."
# 	cd "$BUILD_DIR"
# 	echo "Cloning the Alpine 'aports' repository to get the mkimage script..."
# 	git clone --depth 1 https://gitlab.alpinelinux.org/alpine/aports.git
# 	cd "$PWD"
# }


fetch_latest_alpine_version() {
	ALPINE_VERSION=''

	echo ''
	echo "Fetching the latest Alpine Linux stable version..."
	echo "    $LATEST_STABLE_DIR_URL"
	ALPINE_VERSION="$( \
		curl -s "$LATEST_STABLE_DIR_URL/" \
		| grep -o 'alpine-minirootfs-[0-9]\+\(\.[0-9]\+\)*-x86_64\.tar\.gz' \
		| sed 's/alpine-minirootfs-\([0-9]\+\(\.[0-9]\+\)*\)-x86_64\.tar\.gz/\1/' \
		| sort -V \
		| tail -1 \
	)"

	if [ -z "$ALPINE_VERSION" ]; then
		echo "ERROR: Failed to fetch latest Alpine version"
		exit 1
	fi

	echo "    $ALPINE_VERSION"

	ALPINE_MINIROOTFS_TGZ_URL="$LATEST_STABLE_DIR_URL/alpine-minirootfs-$ALPINE_VERSION-x86_64.tar.gz"
	ALPINE_STANDARD_ISO_URL="$LATEST_STABLE_DIR_URL/alpine-standard-$ALPINE_VERSION-x86_64.iso"
}


download_file() {
	local nice_name="$1"
	local machine_name="$2"
	local in_url="$3"
	local out_file="$4"

	echo ''
	echo "Downloading $nice_name..."
	if [ -z "$ALPINE_VERSION" ]; then
		echo "ERROR: Alpine version is undefined"
		exit 1
	fi
	if [ -f "$out_file" ] && [ -f "$FILE_DL_VERSION" ] && [ "$(cat "$FILE_DL_VERSION")" = "$ALPINE_VERSION" ]; then
		echo "File already exists (for $ALPINE_VERSION version), no need to download:"
		echo "    $out_file"
		return 0
	fi

	if [ -z "$in_url" ]; then
		echo "ERROR: Source URL for <$machine_name> undefined"
		exit 1
	fi

	echo "Latest <$machine_name> URL:"
	echo "    $in_url"
	echo "To:"
	echo "    $out_file"

	sudo rm -rf "$out_file"
	if ! wget -O "$out_file" "$in_url"; then
		echo "ERROR: Failed to download $nice_name"
		exit 1
	fi
	echo "$nice_name download complete"
}


extract_alpine_standard_iso() {
	echo ''
	echo "Extracting boot files from Alpine standard ISO..."
	echo "Temporary mount to:"
	echo "    $MOUNT_ISO_DIR"
	sudo rm -rf "$MOUNT_ISO_DIR"
	mkdir -p "$MOUNT_ISO_DIR"
	sudo mount -o ro,loop "$FILE_STANDARD_ISO" "$MOUNT_ISO_DIR"

	echo "Extracting kernel to:"
	echo "    $FILE_EXTRACTED_KERNEL"
	sudo rm -rf "$FILE_EXTRACTED_KERNEL"
	sudo cp "$MOUNT_ISO_DIR/boot/vmlinuz-lts" "$FILE_EXTRACTED_KERNEL"

	# echo "Extracting Syslinux EFI files"
	# SYSLINUX_EFI_EXTRACT_DIR="$BUILD_DIR/syslinux_efi"
	# mkdir -p "$SYSLINUX_EFI_EXTRACT_DIR"
	# sudo cp -r "$MOUNT_ISO_DIR/boot/syslinux" "$SYSLINUX_EFI_EXTRACT_DIR/"

	cleanup_alpine_iso_mount

	echo ''
	echo "ISO extraction complete"
}


download_and_exatract_all_alpine_files() {
	fetch_latest_alpine_version
	download_file "Alpine minirootfs" "alpine-minirootfs" "$ALPINE_MINIROOTFS_TGZ_URL" "$FILE_MINIROOTFS_GZ"
	download_file "Alpine standard ISO" "alpine-standard" "$ALPINE_STANDARD_ISO_URL" "$FILE_STANDARD_ISO"
	extract_alpine_standard_iso
	sudo rm -f "$FILE_DL_VERSION"
	echo "$ALPINE_VERSION" > "$FILE_DL_VERSION"
}


initialize_rootfs_dir_with_alpine_structure() {
	echo ''
	echo "Extracting Alpine minirootfs to a temporary rootfs directory..."
	echo "    $ROOTFS_DIR"
	sudo rm -rf "$ROOTFS_DIR"
	mkdir -p "$ROOTFS_DIR"
	sudo tar -xzf "$FILE_MINIROOTFS_GZ" -C "$ROOTFS_DIR"
	echo "rootfs directory is initialized with Alpine minirootfs"
}


backup_script_to() {
	local out_file="$1/image_build_script.sh"
	local dir_human_name="$2"

	echo ''
	echo "Copying a backup of the build script itself into $dir_human_name - just to be nice..."
	echo "    $out_file"
	sudo cp "$SCRIPT_PATH" "$out_file"
	sudo chmod 754 "$out_file"
}


save_version_file_to() {
	local out_file="$1/image_version.txt"
	local dir_human_name="$2"

	echo ''
	echo "Saving the version file into $dir_human_name..."
	echo "    $out_file"
	sudo rm -rf "$out_file"
	for line in \
		"alpine: $ALPINE_VERSION" \
		"sedutil: AUR: $SEDUTIL_VERSION" \
		"built-under: $(uname -o)-$(uname -r)-$(uname -m)" \
		"script-version: $SCRIPT_VERSION"
	do
		echo "$line" | sudo tee -a "$out_file"
	done
	sudo chmod 644 "$out_file"
}


customize_rootfs_dir() {
	rootfs_setup_busybox
	rootfs_add_essential_tools
	rootfs_create_init_script

	backup_script_to "$ROOTFS_DIR" 'rootfs dir'
	save_version_file_to "$ROOTFS_DIR" 'rootfs dir'

	# echo "Installing essential Alpine packages to rootfs..."
	# sudo chroot "$ROOTFS_DIR" /bin/sh -c "
	#	apk update
	#	apk add syslinux efibootmgr busybox-static
	#"

	echo ''
	echo 'rootfs preparation complete'
}

rootfs_setup_busybox() {
	# TODO: install busybox from Manjaro
	echo 'Setting up BusyBox (TODO)...'
}

rootfs_add_essential_tools() {
	echo ''
	echo "Adding essential tools to rootfs..."

	# Copy dmesg and other essential busybox applets if missing
	if [ ! -f "$ROOTFS_DIR/usr/bin/dmesg" ]; then
		echo '    dmesg'
		sudo ln -sf /bin/busybox "$ROOTFS_DIR/usr/bin/dmesg" 2>/dev/null || true
	fi

	# Ensure we have grep for parsing logs
	if [ ! -f "$ROOTFS_DIR/bin/grep" ]; then
		echo '    grep'
		sudo ln -sf /bin/busybox "$ROOTFS_DIR/bin/grep" 2>/dev/null || true
	fi
}

rootfs_create_init_script() {
	local init_file="$ROOTFS_DIR/init"
	echo ''
	echo "Creating init script in rootfs..."
	echo "    $init_file"
	sudo rm -rf "$init_file"

	echo "The image will:"
	echo "  1. Boot and show Alpine Linux banner"
	echo "  2. Display system information"
	echo "  3. List storage devices"
	echo "  4. Wait for Enter key"
	echo "  5. Reboot the system"
	sudo tee "$init_file" > /dev/null << 'EOF'
#!/bin/busybox sh

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Wait for devices to be populated
sleep 1

# Create console device (this should work now with devtmpfs mounted)
mknod -m 622 /dev/console c 5 1

# Simple console redirection - this is the most reliable approach
exec >/dev/console 2>&1

echo "=== CONSOLE WORKING ==="
echo "Kernel: $(uname -r)"
echo "Init script is running!"

# Test basic commands
echo "Block devices:"
ls -la /dev/sd* /dev/nvme* 2>/dev/null | head -10 || echo "No block devices found"

echo "Mount points:"
mount | head -10

# Try to mount EFI partition using device scan
echo "Scanning for EFI partition..."
for device in /dev/sd* /dev/nvme*; do
    [ -b "$device" ] || continue
    echo "Trying $device"
    if mount -t vfat "$device" /mnt 2>/dev/null; then
        if [ -f /mnt/vmlinuz-lts ]; then
            echo "Found EFI partition: $device"
            echo "SUCCESS: $(date)" > /mnt/test_success.log
            cat /proc/version > /mnt/kernel_version.log
            sync
            umount /mnt
            break
        fi
        umount /mnt
    fi
done

echo "Sleeping 10 seconds..."
sleep 10
echo "Rebooting..."
sync
reboot -f
EOF

	sudo chmod 755 "$init_file"
	echo "init script created"
}

# ------------------------------

create_out_img() {
	echo ''
	echo "Creating the bootable EFI image (${IMG_SIZE_MB}Mb)..."
	echo "    $OUTPUT_IMG"
	cleanup_image_mount_points

	echo 'Initializing as an empty file...'
	sudo rm -rf "$OUTPUT_IMG"
	dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=$IMG_SIZE_MB status=progress
	chmod 644 "$OUTPUT_IMG"

	echo "Creating GPT with only a single EFI partition..."
	sudo sgdisk --clear --new=1:0:0 --typecode=1:ef00 --change-name=1:EFI "$OUTPUT_IMG"
	# --new=1:0:0: Create partition #1 starting at sector 0, ending at sector 0 (which means "use all available space")
	# --typecode=1:ef00: Set partition type for partition #1 to EF00 (EFI System Partition)
	echo "Partition table created"

	echo ''
	echo "Setting up loop device..."
	LOOP_DEV=$(sudo losetup --find --show --partscan "$OUTPUT_IMG")
	# --find: Find first available loop device
	# --show: Print which loop device was assigned
	# --partscan: Scan for partitions automatically
	LOOP_EFI="${LOOP_DEV}p1"
	echo "    $LOOP_DEV"
	echo "    └─$LOOP_EFI (EFI)"

	echo "Formatting EFI partition as FAT$FAT_VER with label UEFI_PBA..."
	sudo mkfs.fat -F $FAT_VER -n UEFI_PBA "$LOOP_EFI"

	echo "Mounting EFI partition..."
	echo "    To: $MOUNT_OUT_EFI_DIR"
	rm -rf "$MOUNT_OUT_EFI_DIR"
	mkdir -p "$MOUNT_OUT_EFI_DIR"
	sudo mount -t vfat -o rw,noatime,umask=022 "$LOOP_EFI" "$MOUNT_OUT_EFI_DIR"

	efi_setup

	cleanup_image_mount_points
}

efi_setup() {
	echo ''
	echo 'Setting up EFI partition as bootable...'

	efi_init_syslinux_from_running_arch
	efi_configure_syslinux

	efi_copy_alpine_kernel
	efi_pack_initramfs_image

	backup_script_to "$MOUNT_OUT_EFI_DIR" 'EFI partition'
	save_version_file_to "$MOUNT_OUT_EFI_DIR" 'EFI partition'
}

efi_init_syslinux_from_running_arch() {
	# Syslinux setup - according to:
	# https://wiki.archlinux.org/title/Syslinux#UEFI_systems
	echo "Copying syslinux to EFI bootloader..."
	echo "    $EFI_BOOT_DIR/"
	sudo rm -rf "$EFI_BOOT_DIR"
	sudo mkdir -p "$EFI_BOOT_DIR"
	sudo cp -r /usr/lib/syslinux/efi64/* "$EFI_BOOT_DIR/"
	sudo mv "$EFI_BOOT_DIR/syslinux.efi" "$EFI_BOOT_DIR/bootx64.efi"
	echo 'syslinux copied'
}

efi_configure_syslinux() {
	echo ''
	echo "Creating syslinux configuration..."
	echo "    $EFI_BOOT_DIR/syslinux.cfg"
	sudo tee "$EFI_BOOT_DIR/syslinux.cfg" > /dev/null << 'EOF'
TIMEOUT 10
PROMPT 0
DEFAULT alpine_sed

SERIAL 0 115200
CONSOLE 0

LABEL alpine_sed
    MENU LABEL Pre Boot Authorization
    LINUX /vmlinuz-lts
    APPEND console=tty0 console=tty1 console=ttyS0,115200n8 vga=791 video=vesafb:off video=efifb:off
    INITRD /initramfs.cpio.gz
EOF
	echo "syslinux.cfg saved"
}

efi_copy_alpine_kernel() {
	local out_file="$MOUNT_OUT_EFI_DIR/vmlinuz-lts"
	echo ''
	echo "Copying Alpine kernel"
	echo "    From: $FILE_EXTRACTED_KERNEL"
	echo "    To: $out_file"
	sudo cp "$FILE_EXTRACTED_KERNEL" "$out_file"
	sudo chmod 755 "$out_file"
	echo 'copied'
}

efi_pack_initramfs_image() {
	local out_file="$MOUNT_OUT_EFI_DIR/initramfs.cpio.gz"
	echo ''
	echo "Creating initramfs CPIO image..."
	echo "    $out_file"
	(
		cd "$ROOTFS_DIR" && \
		sudo find . \
		| sudo cpio -o -H newc \
		| gzip \
		| sudo tee "$out_file" \
		> /dev/null
	)
	cd "$PWD"
	sudo chmod 644 "$out_file"
	echo "initramfs image created"
}

# ------------------------------

cleanup_image_mount_points() {
	if [ -n "$MOUNT_OUT_EFI_DIR" ]; then
		if mountpoint -q "$MOUNT_OUT_EFI_DIR"; then
			echo ''
			echo "Unmounting EFI partition at path:"
			echo "    $MOUNT_OUT_EFI_DIR"
			sudo umount -fR "$MOUNT_OUT_EFI_DIR"
		fi
		sudo rm -rf "$MOUNT_OUT_EFI_DIR"
	fi

	if [ -n "$LOOP_EFI" ]; then
		# If it's a block device and it's mounted...
		if [ -b "$LOOP_EFI" ] && findmnt "$LOOP_EFI" >/dev/null 2>&1; then
			echo ''
			echo "Unmounting EFI partition:"
			echo "    $LOOP_EFI"
			sudo umount -fRA "$LOOP_EFI"
		fi
		LOOP_EFI=''
	fi

	if [ -n "$LOOP_DEV" ]; then
		if losetup "$LOOP_DEV" >/dev/null 2>&1; then
			echo ''
			echo "Detaching image's loop device:"
			echo "    $LOOP_DEV"
			sudo losetup -d "$LOOP_DEV"
		fi
		LOOP_DEV=''
	fi
}

cleanup_alpine_iso_mount() {
	if [ -n "$MOUNT_ISO_DIR" ]; then
		if mountpoint -q "$MOUNT_ISO_DIR"; then
			echo ''
			echo "Unmounting Alpine ISO image..."
			echo "    $MOUNT_ISO_DIR"
			sudo umount -fR "$MOUNT_ISO_DIR"
		fi
		sudo rm -rf "$MOUNT_ISO_DIR"
	fi
}

cleanup_all() {
	cleanup_image_mount_points
	cleanup_alpine_iso_mount
}

#------------------------------

# Main execution
trap cleanup_all EXIT # Set up trap to ensure cleanup runs on script exit, with any exit status

install_pkgs
download_and_exatract_all_alpine_files

echo ''
echo '------------------------------'
initialize_rootfs_dir_with_alpine_structure
customize_rootfs_dir

echo ''
echo '------------------------------'
create_out_img
cleanup_all

echo ''
echo ''
echo '================================================'
echo ''
echo ''
echo "Boot image created:"
echo "    $OUTPUT_IMG"
echo ''
echo "Write to USB with:"
echo "sudo dd if='$OUTPUT_IMG' of=/dev/sdX bs=4M status=progress && sync"
echo ''



_todo() {
# Create busybox symlinks in initramfs
sudo cp "$ROOTFS_DIR/bin/busybox.static" "$ROOTFS_DIR/busybox"
sudo chroot "$ROOTFS_DIR" /busybox --install -s

# Make the image bootable by installing syslinux MBR
sudo dd if="$ROOTFS_DIR/usr/share/syslinux/gptmbr.bin" of="$OUTPUT_IMG" bs=440 count=1 conv=notrunc
}
