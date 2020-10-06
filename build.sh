#!/bin/bash
# shellcheck disable=SC2034

#############################################################
#                   Ayün build script                       #
#############################################################

# Archiso variables
iso_name="ayun"
iso_version="0.0.1"
iso_label="AYUNISO_001"
iso_publisher="AYUN <https://github.com/Ayun-Linux>"
install_dir="arch"
bootmodes="('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')"
arch="x86_64"
pacman_conf="pacman.conf"

# Ayün specific variables
BUILD_DIR="$(pwd)/ayun_build"
ARCHISO_DIR="/usr/share/archiso/configs/releng"

#############################################################
#                    Build functions                        #
#############################################################

# Check root permission
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run as root"
        exit
    fi
}

# Check if archiso is installed
check_archiso() {
    if ! sudo pacman -Qqs '^archiso$' >/dev/null \
    || ! sudo pacman -Qqs '^mkinitcpio-archiso$' >/dev/null; then
        printf "archiso or mkinitcpio-archiso was not found.\n"
        printf "Do you want to install it? [Y/n] "
        read -r answer
        if [ "${answer}" != "${answer#[Yy]}" ] ;then
            sudo pacman -Syy archiso mkinitcpio-archiso --needed
        else
            echo "archiso and mkinitcpio-archiso are required. Please install it before continuing."
            exit 1
        fi
        exit
    fi
}

create_build_dir() {
    # Create temporary directory if not exists
    [ -d "${BUILD_DIR}" ] || mkdir "${BUILD_DIR}"

    # Copy archiso files to tmp dir
    sudo cp -r "${ARCHISO_DIR}"/* "${BUILD_DIR}"

    # Copy Ayün files to tmp dir
    sudo cp -Tr "$(pwd)/src/airootfs/etc" "${BUILD_DIR}/airootfs/etc"
    sudo cp -Tr "$(pwd)/src/syslinux" "${BUILD_DIR}/airootfs/syslinux"

    # Add Ayün packages
    cat "$(pwd)/ayun-packages.x86_64" >> "${BUILD_DIR}/packages.x86_64"
    sort --unique --output="${BUILD_DIR}/packages.x86_64" "${BUILD_DIR}/packages.x86_64"

    # Remove Arch Linux motd
    rm "${BUILD_DIR}/airootfs/etc/motd"
}

# Modify pacman.conf
pacman_conf() {
    # Add chaotic-aur repo
    cat << EOF >> "${BUILD_DIR}/pacman.conf"
    [chaotic-aur]
    # Brazil
    Server = https://lonewolf.pedrohlc.com/\$repo/\$arch
    # USA
    Server = https://builds.garudalinux.org/repos/\$repo/\$arch
    Server = https://repo.kitsuna.net/\$arch
    # Netherlands
    Server = https://chaotic.tn.dedyn.io/\$arch
    # Germany
    Server = http://chaotic.bangl.de/\$repo/\$arch
EOF

    sudo pacman-key --keyserver hkp://keyserver.ubuntu.com -r 3056513887B78AEB 8A9E14A07010F7E3
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman-key --lsign-key 8A9E14A07010F7E3
}

# Generate profiledef.sh file
profiledef_gen() {
    [ ! -f "${BUILD_DIR}"/profiledef.sh ] || rm "${BUILD_DIR}/profiledef.sh"
    touch "${BUILD_DIR}/profiledef.sh"
    cat << EOF > "${BUILD_DIR}/profiledef.sh"
    iso_name="${iso_name}"
    iso_version="${iso_version}"
    iso_label="${iso_label}"
    iso_publisher="${iso_publisher}"
    install_dir="${install_dir}"
    bootmodes=${bootmodes}
    arch="${arch}"
    pacman_conf="${pacman_conf}"
EOF
}

#############################################################

main() {
    # Build ISO
    check_root
    check_archiso
    create_build_dir
    pacman_conf
    profiledef_gen
    sudo mkarchiso -v "${BUILD_DIR}" command_iso
}

main
