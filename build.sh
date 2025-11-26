#!/bin/bash
set -e

SCRIPT_VERSION='1.0.0'

# Configuration
SEDUTIL_VER='1.15' # 1.15/1.15.1/1.20, or empty - to use the latest version from AUR
IMAGE_SIZE_MB=80
STABLE_KERNEL=linux612
EFI_FAT_VER=16
# MKINITCPIO_HOOKS='base udev microcode modconf kms keyboard keymap consolefont block'
MKINITCPIO_HOOKS='base udev microcode modconf keyboard keymap consolefont block'

# --------------------
# Script constants

OFFICIAL_PBA_URL_1_15_0='https://github.com/Drive-Trust-Alliance/exec/blob/1.15/UEFI64.img.gz?raw=true'
OFFICIAL_PBA_URL_1_15_1='https://github.com/Drive-Trust-Alliance/exec/blob/1.15.1/UEFI64.img.gz?raw=true'
OFFICIAL_PBA_URL_1_20_0='https://github.com/Drive-Trust-Alliance/exec/blob/1.20.0/UEFI64.img.gz?raw=true'

PWD="$(pwd)"
SCRIPT_PATH="$(realpath $0)"
BUILD_DIR="$PWD/bld"
CHROOT_DIR="$BUILD_DIR/mnt"
OUTPUT_IMG="$BUILD_DIR/Manjaro-PBA.img"

# --------------------
# Actual variables: set by functions

LOOP_DEVICE=''
OFFICIAL_PBA_DL_IMG=''

cleanup_loop_device() {
	sudo umount "$CHROOT_DIR/boot" 2>/dev/null || true

	if [ -n "$LOOP_DEVICE" ]; then
		if losetup "$LOOP_DEVICE" >/dev/null 2>&1; then
			echo "Detaching image's loop device:"
			echo "    $LOOP_DEVICE"
			sudo losetup -d "$LOOP_DEVICE"
		fi
		LOOP_DEVICE=''
	fi
}

# Cleanup function
cleanup() {
	echo ''
	echo '--------------------'
	echo ''
	echo "Cleaning up..."

	cleanup_loop_device

	if [ -d "$CHROOT_DIR/boot_orig" ]; then
		echo "Restoring the original boot dir..."
		sudo rm -rf "$CHROOT_DIR/boot" 2>/dev/null || true
		sudo mv -v "$CHROOT_DIR/boot_orig" "$CHROOT_DIR/boot"
	fi
	sudo rm -rf "$CHROOT_DIR/boot2" 2>/dev/null || true
	sudo rm -rf "$BUILD_DIR/Manjaro-PBA.img" 2>/dev/null || true # Don't use $OUTPUT_IMG: attempt to remove incomplete image when process was interrupted
}
trap cleanup EXIT

# --------------------
# Utility functions

download_and_unpack_gz_file() {
	local nice_name="$1"
	local in_gz_url="$2"
	local out_unpacked_file="$3"

	echo ''
	echo "Downloading and unpacking $nice_name..."
	if [ -f "$out_unpacked_file" ]; then
		echo "File already exists, no need to download:"
		echo "    $out_unpacked_file"
		return 0
	fi

	if [ -z "$in_gz_url" ]; then
		echo "ERROR: Source URL for $nice_name undefined"
		exit 1
	fi

	echo "Gzipped source:"
	echo "    $in_gz_url"
	echo "Saved (unpacked) file:"
	echo "    $out_unpacked_file"

	sudo rm -rf "$out_unpacked_file"
	if ! wget -O - "$in_gz_url" | gunzip > "$out_unpacked_file"; then
		# ... > "${out_unpacked_file%.gz}" - to also force-remove gz extension
		echo "ERROR: Failed to download or unpack $nice_name"
		exit 1
	fi
	echo "$nice_name download complete"
}

append_override_to_file() {
	local file_path="$1"
	local as_sudo="$2"

	echo "Adding override to:"
	echo "    $file_path"

	local prefix='# -------------------- Overrides for sedutil PBA --------------------'
	local sed_pattern="/$prefix/,\$d" # Removes existing overrides from file
	local sed_remove_trailing_empty=':a;/^[ \n]*$/{$d;N;ba}'

	if [ -z "$as_sudo" ]; then
		# empty 'as_sudo' arg: do under the current user
		touch "$file_path"
		sed -i "$sed_pattern" "$file_path"
		sed -i "$sed_remove_trailing_empty" "$file_path"
		(echo ''; echo "$prefix"; echo ''; cat) >> "$file_path"
		return 0
	fi

	# 'as_sudo' isn't empty
	sudo touch "$file_path"
	sudo sed -i "$sed_pattern" "$file_path"
	sudo sed -i "$sed_remove_trailing_empty" "$file_path"
	(echo ''; echo "$prefix"; echo ''; cat) | sudo tee -a "$file_path" >/dev/null
}

# --------------------
# The main process split into steps

main_init() {
	echo ''
	echo "Installing build dependencies..."
	sudo pacman -Su --needed --noconfirm arch-install-scripts manjaro-tools-base-git yay

	echo 'Installing sedutil from AUR...'
	yay -Su --needed --noconfirm sedutil # NOT sudo
	# sudo rm -rf "$BUILD_DIR"
	mkdir -p "$BUILD_DIR"
}

download_required_official_image() {
	local gz_url=''
	case "$SEDUTIL_VER" in
	'1.20' | '1.20.0')
		SEDUTIL_VER='1.20'
		gz_url="$OFFICIAL_PBA_URL_1_20_0"
		OFFICIAL_PBA_DL_IMG="$BUILD_DIR/UEFI64-1.20.img"
		;;
	'1.15.1')
		gz_url="$OFFICIAL_PBA_URL_1_15_1"
		OFFICIAL_PBA_DL_IMG="$BUILD_DIR/UEFI64-1.15.1.img"
		;;
	'1.15' | '1.15.0')
		SEDUTIL_VER='1.15'
		gz_url="$OFFICIAL_PBA_URL_1_15_0"
		OFFICIAL_PBA_DL_IMG="$BUILD_DIR/UEFI64-1.15.img"
		;;
	esac

	if [ -n "$gz_url" ]; then
		download_and_unpack_gz_file "Pre-built PBA image (v$SEDUTIL_VER)" "$gz_url" "$OFFICIAL_PBA_DL_IMG"
	else
		SEDUTIL_VER=''
		OFFICIAL_PBA_DL_IMG=''
	fi
}

install_chroot_system() {
	echo ''
	echo '--------------------'
	echo ''
	echo "Installing minimal system with pacstrap..."
	sudo mkdir -p "$CHROOT_DIR"
	sudo pacstrap -c -G "$CHROOT_DIR" \
		base $STABLE_KERNEL manjaro-release `# absolute minimum packages` \
		efibootmgr grub update-grub `# bootloader` \
		busybox `# to be installed into intramfs' /bin, to make initramfs self-sufficient` \
		amd-ucode intel-ucode `# from arch wiki - for hardware bug and security fixes` \
		`# none of GPUs, network adapters, bluetooth, soundcards, etc. is needed - so, no 'linux-firmware-meta'` \
		linux-firmware-other `# however, some laptops might have issues without it`\
		dosfstools

	echo ''
	local vconsole_file="$CHROOT_DIR/etc/vconsole.conf"
	append_override_to_file "$vconsole_file" sudo << 'EOF'
KEYMAP=us
EOF
	sudo chmod 644 "$vconsole_file"

	echo ''
	echo "Backing up original boot dir:"
	sudo mv -v "$CHROOT_DIR/boot" "$CHROOT_DIR/boot_orig"
	sudo cp -prlL "$CHROOT_DIR/boot_orig" "$CHROOT_DIR/boot"

	echo ''
	echo '--------------------'
}

# --------------------
# Manjaro install customization

configure_mkinitcpio_from_outside() {
	echo ''
	echo "Configuring mkinitcpio..."
	mkinitcpio_conf "$CHROOT_DIR/etc/mkinitcpio.conf"
	for preset_file in $(sudo ls "$CHROOT_DIR/etc/mkinitcpio.d"); do
		mkinitcpio_kernel_preset "$CHROOT_DIR/etc/mkinitcpio.d/$preset_file"
	done
	mkinitcpio_install_hook "$CHROOT_DIR"
	mkinitcpio_runtime_hook "$CHROOT_DIR"
}

configure_grub_from_outside() {
	echo ''
	echo "Configuring GRUB..."
	append_override_to_file "$CHROOT_DIR/etc/default/grub" sudo << 'EOF'
GRUB_TIMEOUT=0
GRUB_SAVEDEFAULT=false
GRUB_DISABLE_RECOVERY=true
GRUB_DISABLE_SUBMENU=y
GRUB_DISABLE_OS_PROBER=true
GRUB_DISABLE_LINUX_UUID=true
GRUB_DISABLE_LINUX_PARTUUID=true
GRUB_CMDLINE_LINUX_DEFAULT="quiet udev.log_priority=3 break=premount libata.allow_tpm=1"
EOF
}

# --------------------
# Functions related to <mkinitcpio>

mkinitcpio_conf() {
	local file_path="$1"

	echo "Setting up hooks in mkinitcpio.conf..."
	append_override_to_file "$file_path" sudo << EOF
HOOKS=($MKINITCPIO_HOOKS sed_pba)
EOF
	sudo chmod 644 "$file_path"
}

mkinitcpio_kernel_preset() {
	local file_path="$1"

	echo "Making 'default' preset the only one..."
	append_override_to_file "$file_path" sudo << 'EOF'
PRESETS=('default')
EOF
	sudo chmod 644 "$file_path"
}

mkinitcpio_install_hook() {
	local CHROOT_DIR="$1"
	local file_path="$CHROOT_DIR/etc/initcpio/install/sed_pba"
	echo "Adding 'sed_pba' install-hook for mkinitcpio to:"
	echo "    $file_path"

	sudo mkdir -p "$CHROOT_DIR/etc/initcpio/install"

	sudo tee "$file_path" > /dev/null << 'EOF'
#!/usr/bin/env bash

# https://man.archlinux.org/man/mkinitcpio.8#ABOUT_INSTALL_HOOKS

build() {
	echo 'Adding lsblk...'
	add_binary lsblk

	echo 'Adding sedutil binaries...'
	add_binary /SEDUTIL_BIN/sedutil-cli /bin/sedutil-cli
	add_binary /SEDUTIL_BIN/linuxpba /bin/linuxpba

	echo 'Adding /SED_PBA dir...'
	add_full_dir /SED_PBA
	# add_file /SED_PBA/build-details /SED_PBA/build-details

	add_runscript
}

help() {
	cat <<HELPEOF
This hook adds everything sedutil-related into initramfs. Shoud be last.
HELPEOF
}
EOF
	sudo chmod 644 "$file_path"
}

mkinitcpio_runtime_hook() {
	local CHROOT_DIR="$1"
	local file_path="$CHROOT_DIR/etc/initcpio/hooks/sed_pba"
	echo "Adding 'sed_pba' runtime-hook for mkinitcpio to:"
	echo "    $file_path"

	sudo mkdir -p "$CHROOT_DIR/etc/initcpio/hooks"

	sudo tee "$file_path" > /dev/null << 'EOF'
#!/usr/bin/ash

# https://wiki.archlinux.org/title/Mkinitcpio#Build_hooks
# https://man.archlinux.org/man/mkinitcpio.8#ABOUT_RUNTIME_HOOKS

run_hook() {
	echo 'SED Pre-boot Authorisation (Manjaro-based)'
	echo '------------------------------------------'
	echo "v$(cat /SED_PBA/build-version)"
	echo "EFI UUID: $(cat /SED_PBA/efi-uuid)"

	# ls -hlA /SED_PBA

	# echo ''
	# lsblk -o NAME,LABEL,MODEL,SIZE,UUID

	echo ''
	sedutil-cli --scan

	echo ''
	linuxpba

	echo "Reboot"
	sleep 1
	sync
	reboot -f
}
EOF
	sudo chmod 644 "$file_path"
}

# --------------------
# Actual image creation

init_out_image() {
	echo ''
	echo "Creating disk image (${IMAGE_SIZE_MB}Mb):"
	echo "    $OUTPUT_IMG"
	dd if=/dev/zero of="$OUTPUT_IMG" bs="${IMAGE_SIZE_MB}M" count=1
	echo "Setting up loop device..."
	LOOP_DEVICE=$(sudo losetup --find --show --partscan "$OUTPUT_IMG")
	echo "    $LOOP_DEVICE"
	echo "Partitioning loop device..."
	sudo parted "$LOOP_DEVICE" mktable gpt
	sudo parted "$LOOP_DEVICE" mkpart primary fat32 1MiB 100%
	sudo parted "$LOOP_DEVICE" set 1 esp on
	sudo parted "$LOOP_DEVICE" name 1 EFI
	echo "Formatting EFI partition as FAT$EFI_FAT_VER:"
	echo "    ${LOOP_DEVICE}p1"
	sudo mkfs.fat -F $EFI_FAT_VER -n EFI_PBA "${LOOP_DEVICE}p1"
	echo "Output image partitioned and formatted."

	echo "Re-setting up loop device..."
	sudo sync
	sudo losetup -d "$LOOP_DEVICE"
	LOOP_DEVICE=''
	sudo sync
	LOOP_DEVICE=$(sudo losetup --find --show --partscan "$OUTPUT_IMG")
	echo "    $LOOP_DEVICE"
	echo "Output image initialized with empty EFI partition."
}

chroot_build_final_efi() {
	echo ''
	echo '--------------------'
	echo ''
	echo "Generating final EFI boot partition..."

	if [ -z  "$LOOP_DEVICE" ]; then
		echo "ERROR: No loop device set up"
		exit 1
	fi

	local efi_device="${LOOP_DEVICE}p1"

	if [ -b "$efi_device" ]; then
		echo "    $efi_device"
	else
		echo "ERROR: EFI partition doesn't exist: $efi_device"
		exit 1
	fi

	echo ''
	echo 'Initializing /SED_PBA dir...'
	echo "    $CHROOT_DIR/SED_PBA"
	sudo rm -rf "$CHROOT_DIR/SED_PBA" 2>/dev/null || true
	sudo mkdir -p "$CHROOT_DIR/SED_PBA"
	sudo chmod 755 "$CHROOT_DIR/SED_PBA"

	echo 'Backing up the build script itself into /SED_PBA...'
	sudo cp -pvL "$SCRIPT_PATH" "$CHROOT_DIR/SED_PBA/pba-build-script.sh"
	sudo chmod 644 "$CHROOT_DIR/SED_PBA/pba-build-script.sh"

	local efi_uuid="$(sudo blkid -s UUID -o value "$efi_device")"

	echo "$efi_uuid" | sudo tee "$CHROOT_DIR/SED_PBA/efi-uuid" > /dev/null
	echo "$IMAGE_SIZE_MB" | sudo tee "$CHROOT_DIR/SED_PBA/image-size-mb" > /dev/null
	echo 'Added to /SED_PBA:'
	echo "    efi-uuid: $(cat "$CHROOT_DIR/SED_PBA/efi-uuid")"
	echo "    image-size-mb: $(cat "$CHROOT_DIR/SED_PBA/image-size-mb")"

	echo ''
	echo "Generating temporary script (to run under chrooted Manjaro)..."
	sudo tee "$CHROOT_DIR/tmp-script-efi-install" > /dev/null << EOF
#!/bin/bash
set -e

ORIG_IMG_LOOP_DEVICE=''

cleanup() {
	echo ''
	echo 'Cleaning up (under chrooted Manjaro)...'
	echo 'Unmounting /boot...'
	umount /boot 2>/dev/null || true
	$(chroot_sedutil_cleanup_commands)
	echo 'Cleanup under chrooted Manjaro complete.'
}
trap cleanup EXIT


$(chroot_sedutil_install_commands)

$(chroot_build_config_commands)

echo ''
echo "Removing original initramfs files from initial installation..."
rm -rf /boot/initramfs*.img

echo 'Rebuilding initramfs with updated configs (under chrooted Manjaro)...'
mkinitcpio -P

echo ''
echo 'Removing separate microcode images (already integrated to initramfs):'
rm -rfv /boot/*-ucode.img

echo ''
echo 'Temporarily renaming /boot directory to /boot2...'
mv /boot /boot2

echo 'Mounting EFI partition as /boot (under chrooted Manjaro):'
echo '    $efi_device -> /boot'
mkdir -p /boot
mount -t vfat -o rw,noatime,umask=000 '$efi_device' /boot

echo ''
echo 'Copying files from /boot2 to EFI partition:'
cp -prvL /boot2/* /boot/

echo ''
echo 'Installing GRUB...'
mkdir -p /boot/EFI
grub-install --target=x86_64-efi --removable --efi-directory=/boot

echo ''
echo 'Rebuilding GRUB menu...'
mkdir -p '/boot/grub'
# grub-mkconfig -o /boot/grub/grub.cfg
update-grub
EOF
	sudo chmod 755 "$CHROOT_DIR/tmp-script-efi-install"

	echo "Running it..."
	sudo manjaro-chroot "$CHROOT_DIR" /tmp-script-efi-install
	echo "EFI partition fully set up."
}

chroot_sedutil_cleanup_commands() {
	if [ -z "$OFFICIAL_PBA_DL_IMG" ]; then
		# echo "echo 'Uninstalling sedutil AUR package...'"
		# echo 'yay -R --noconfirm sedutil 2>/dev/null || true'
		return 0
	fi

	cat << 'EOF'
echo 'Unmounting /ORIG_EFI...'
umount /ORIG_EFI 2>/dev/null || true
rm -rf /ORIG_EFI 2>/dev/null || true

if [ -n "$ORIG_IMG_LOOP_DEVICE" ]; then
	if losetup "$ORIG_IMG_LOOP_DEVICE" >/dev/null 2>&1; then
		echo "Detaching loop device of original sedutil image:"
		echo "    $ORIG_IMG_LOOP_DEVICE"
		losetup -d "$ORIG_IMG_LOOP_DEVICE"
	fi
	ORIG_IMG_LOOP_DEVICE=''
fi

echo "Removing data copied from original PBA image..."
# rm -rf /ORIG_ROOTFS 2>/dev/null || true
rm -rf /ORIG_PBA.img 2>/dev/null || true
EOF
}

chroot_sedutil_install_commands() {
	sudo rm -rf "$CHROOT_DIR/SEDUTIL_BIN" 2>/dev/null || true
	sudo mkdir -p "$CHROOT_DIR/SEDUTIL_BIN" > /dev/null
	sudo chmod 755 "$CHROOT_DIR/SEDUTIL_BIN" > /dev/null

	if [ -z "$OFFICIAL_PBA_DL_IMG" ]; then
		# Using sedutil from AUR (installed in the build OS, not in the chrooted one)
		sudo cp -pL "$(which sedutil-cli)" "$CHROOT_DIR/SEDUTIL_BIN/sedutil-cli" > /dev/null
		sudo cp -pL "$(which linuxpba)" "$CHROOT_DIR/SEDUTIL_BIN/linuxpba" > /dev/null
		sudo chmod 755 "$CHROOT_DIR/SEDUTIL_BIN/"* > /dev/null

		cat << 'EOF'
sedutil_aur_version="$(/SEDUTIL_BIN/sedutil-cli --version | grep -oE '[0-9]+(\.[0-9]+)*$')"
echo "$sedutil_aur_version-AUR" > /SED_PBA/version-sedutil

echo ''
echo 'Added to /SED_PBA:'
echo "    version-sedutil: $(cat /SED_PBA/version-sedutil)"
EOF
		return 0
	fi

	sudo cp -pL "$OFFICIAL_PBA_DL_IMG" "$CHROOT_DIR/ORIG_PBA.img" > /dev/null

	echo "echo '$SEDUTIL_VER' > /SED_PBA/version-sedutil"

	cat << 'EOF'
echo ''
echo 'Added to /SED_PBA:'
echo "    version-sedutil: $(cat /SED_PBA/version-sedutil)"

echo "Setting up loop device for original PBA image (under chrooted Manjaro)..."
ORIG_IMG_LOOP_DEVICE=$(losetup --find --show --partscan /ORIG_PBA.img)
echo "    $ORIG_IMG_LOOP_DEVICE"

echo "Mounting original EFI partition as /ORIG_EFI (under chrooted Manjaro):"
echo "    ${ORIG_IMG_LOOP_DEVICE}p1"
mkdir -p /ORIG_EFI
mount -t vfat -o rw,noatime,umask=000 "${ORIG_IMG_LOOP_DEVICE}p1" /ORIG_EFI

echo "Extracting original initramfs to /ORIG_ROOTFS (under chrooted Manjaro)..."
rm -rf /ORIG_ROOTFS 2>/dev/null || true
mkdir -p /ORIG_ROOTFS
cd /ORIG_ROOTFS
lsinitcpio --extract /ORIG_EFI/EFI/boot/rootfs.cpio.xz > /dev/null
cd /
echo "Extracted."

echo ''
echo "Copying sedutil binaries to /SEDUTIL_BIN dir..."
cp -pvL /ORIG_ROOTFS/sbin/sedutil-cli /SEDUTIL_BIN/sedutil-cli
cp -pvL /ORIG_ROOTFS/sbin/linuxpba /SEDUTIL_BIN/linuxpba
EOF
}

chroot_build_config_commands() {
	local regex_kernel_version='[0-9]+((\.|-)[0-9]+)*' # only numeric part (separated with '.' or '-')
	local regex_everyting_after_semicolon='^.+?\:[ \t]*\K[^ \t].*?$'
	cat << EOF
echo ''
echo 'Saving biild-config files to /SED_PBA:'
echo '$SCRIPT_VERSION' > /SED_PBA/version-build-script
uname -r | grep -oP '$regex_kernel_version' > /SED_PBA/version-kernel
lsb_release -r | grep -oP '$regex_everyting_after_semicolon' > /SED_PBA/version-manjaro
lsb_release -c | grep -oP '$regex_everyting_after_semicolon' > /SED_PBA/version-manjaro-codename
EOF
	cat << 'EOF'
version_id="$(cat /SED_PBA/version-sedutil)"
version_id="$version_id-kernel-$(cat /SED_PBA/version-kernel)"
version_id="$version_id-Manjaro-$(cat /SED_PBA/version-manjaro)"
version_id="$version_id-script-$(cat /SED_PBA/version-build-script)"
echo "$version_id" > /SED_PBA/build-version

echo "sedutil: $(cat /SED_PBA/version-sedutil)" > /SED_PBA/build-details
echo "Kernel: $(cat /SED_PBA/version-kernel)-$(uname -m)" >> /SED_PBA/build-details
echo "Manjaro: $(cat /SED_PBA/version-manjaro) ($(cat /SED_PBA/version-manjaro-codename))" >> /SED_PBA/build-details
echo "PBA build script: $(cat /SED_PBA/version-build-script)" >> /SED_PBA/build-details

echo "    build-version: $(cat /SED_PBA/build-version)"
echo "    version-build-script: $(cat /SED_PBA/version-build-script)"
echo "    version-kernel: $(cat /SED_PBA/version-kernel)"
echo "    version-manjaro: $(cat /SED_PBA/version-manjaro)"
echo "    version-manjaro-codename: $(cat /SED_PBA/version-manjaro-codename)"

echo ''
echo '/SED_PBA/build-details:'
cat /SED_PBA/build-details
EOF
	echo 'chmod 644 /SED_PBA/*'
}

move_out_image() {
	echo ''
	cleanup_loop_device

	local sed="$CHROOT_DIR/SED_PBA"
	local new_path="$PWD/SEDPBA-$(cat "$sed/version-sedutil")-Manjaro-$(cat "$sed/version-manjaro").img"

	echo "Moving the created image to output path:"
	sudo rm -rf "$new_path" 2>/dev/null || true
	sudo mv -v "$OUTPUT_IMG" "$new_path"
	OUTPUT_IMG="$new_path"
}

# --------------------

main_init
download_required_official_image
install_chroot_system

configure_mkinitcpio_from_outside
configure_grub_from_outside
init_out_image
chroot_build_final_efi
move_out_image

echo ''
echo ''
echo '================================================'
echo ''
echo ''
echo "Boot image created successfully:"
echo "    $OUTPUT_IMG"
echo ''
echo "Write to USB with:"
echo "sudo dd if='$OUTPUT_IMG' of=/dev/sdX bs=2M status=progress && sync"
echo ''
