#! /bin/bash

#variables
SERVER='159.65.88.73'
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$EDITION-$DEVICE-$VERSION
PROFILES=/usr/share/manjaro-arm-tools/profiles
NSPAWN='sudo systemd-nspawn -q --timezone=off --resolv-conf=copy-host -D'
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm/'
VERSION=$(date +'%y'.'%m')
ARCH='aarch64'
DEVICE='rpi3'
EDITION='minimal'
USER='manjaro'
PASSWORD='manjaro'

#import conf file
if [[ -f ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf ]]; then
source ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf 
else
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf 
fi

usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to upload"
    echo '    -r <repo>          Repository package belongs to. [Options = core, extra or community]'
    echo "    -k <gpg key ID>    Email address associated with the GPG key to use for signing"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_deploy_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -i <image>         Image to upload. Should be a .zip file."
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rockpro64 and pinebook]"
    echo '    -e <edition>       Edition of the image. [Default = minimal. Options = minimal, lxqt, mate and server]'
    echo "    -v <version>       Version of the image. [Default = Current YY.MM]"
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rockpro64 and pinebook]"
    echo "    -e <edition>       Edition to build [Default = minimal. Options = minimal, lxqt, mate and server]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -u <user>          Username for default user. [Default = manjaro]"
    echo "    -p <password>      Password of default user. [Default = manjaro]"
    echo "    -n                 Make only rootfs, compressed as a .zip, instead of a .img."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_oem() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rockpro64 and pinebook]"
    echo "    -e <edition>       Edition to build [Default = minimal. Options = minimal, lxqt, mate and server]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
get_timer(){
    echo $(date +%s)
}

# $1: start timer
elapsed_time(){
    echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

show_elapsed_time(){
    msg "Time %s: %s minutes..." "$1" "$(elapsed_time $2)"
}
 
sign_pkg() {
    msg "Signing [$PACKAGE] with GPG key belonging to $GPGMAIL..."
    gpg --detach-sign -u $GPGMAIL "$PACKAGE"
}

create_torrent() {
    msg "Creating torrent of $IMAGE..."
    cd $IMGDIR/
    mktorrent -a udp://mirror.strits.dk:6969 -v -w https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/$IMAGE -o $IMAGE.torrent $IMAGE
}

checksum_img() {
    # Create checksums for the image
    msg "Creating checksums for [$IMAGE]..."
    cd $IMGDIR/
    sha1sum $IMAGE > $IMAGE.sha1
    sha256sum $IMAGE > $IMAGE.sha256
}

pkg_upload() {
    msg "Uploading package to server..."
    echo "Please use your server login details..."
    scp $PACKAGE* $SERVER:/opt/repo/mirror/stable/$ARCH/$REPO/
    #msg "Adding [$PACKAGE] to repo..."
    #echo "Please use your server login details..."
    #ssh $SERVER 'bash -s' < $LIBDIR/repo-add.sh "$@"
}

img_upload() {
    # Upload image + checksums to image server
    msg "Uploading image and checksums to server..."
    echo "Please use your server login details..."
    rsync -raP $IMAGE* $OSDN/$DEVICE/$EDITION/$VERSION/
}

remove_local_pkg() {
    # remove local packages if remote packages exists, eg, if upload worked
    if ssh $SERVER "[ -f /opt/repo/mirror/stable/$ARCH/$REPO/$PACKAGE ]"; then
    msg "Removing local files..."
    rm $PACKAGE*
    else
    msg "Package did not get uploaded correctly! Files not removed..."
    fi
}

create_rootfs_pkg() {
    # Remove old rootfs if it exists
    if [ -d $BUILDDIR/$ARCH ]; then
    echo "Removing old rootfs..."
    sudo rm -rf $BUILDDIR/$ARCH
    fi
    msg "Creating rootfs..."
    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrorlist
    echo "Server = http://mirrors.dotsrc.org/manjaro-arm/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    sudo mkdir -p $BUILDDIR/$ARCH

    # basescrap the rootfs filesystem
    sudo pacstrap -G -c -C $LIBDIR/pacman.conf.$ARCH $BUILDDIR/$ARCH base-devel manjaro-arm-keyring

    # Enable cross architecture Chrooting
    if [[ "$ARCH" = "aarch64" ]]; then
        sudo cp /usr/bin/qemu-aarch64-static $BUILDDIR/$ARCH/usr/bin/
    else
        sudo cp /usr/bin/qemu-arm-static $BUILDDIR/$ARCH/usr/bin/
    fi
    
    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

   msg "Configuring rootfs for building..."
    $NSPAWN $BUILDDIR/$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH pacman -Syy base-devel manjaro-arm-keyring --noconfirm
    sudo cp $LIBDIR/makepkg $BUILDDIR/$ARCH/usr/bin/
    $NSPAWN $BUILDDIR/$ARCH chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    sudo rm -f $BUILDDIR/$ARCH/etc/ssl/certs/ca-certificates.crt
    sudo rm -f $BUILDDIR/$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    sudo cp -a /etc/ssl/certs/ca-certificates.crt $BUILDDIR/$ARCH/etc/ssl/certs/
    sudo cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $BUILDDIR/$ARCH/etc/ca-certificates/extracted/
    sudo sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $BUILDDIR/$ARCH/etc/makepkg.conf
    sudo sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $BUILDDIR/$ARCH/etc/makepkg.conf
}

create_rootfs_img() {
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    echo "Removing old rootfs..."
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    fi
    
    # fetch and extract rootfs
    msg "Downloading latest $ARCH rootfs..."
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    
    msg "Extracting $ARCH rootfs..."
    sudo bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    msg "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syy base $PKG_DEVICE $PKG_EDITION --needed --noconfirm
    
    msg "Enabling services..."
    # Enable services
    $NSPAWN rootfs_$ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    msg "Applying overlay for $EDITION edition..."
    sudo cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/
    
    msg "Setting up users..."
    #setup users
    echo "$USER" > $TMPDIR/user
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$PASSWORD" >> $TMPDIR/password
    $NSPAWN rootfs_$ARCH passwd root < $LIBDIR/pass-root 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash $(cat $TMPDIR/user) 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH passwd $(cat $TMPDIR/user) < $TMPDIR/password 1> /dev/null 2>&1
    sudo rm -f $TMPDIR/user $TMPDIR/password
    
    msg "Enabling user services..."
    if [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
        echo "No user services for $EDITION edition"
    else
        $NSPAWN rootfs_$ARCH --user manjaro systemctl --user enable pulseaudio.service 1> /dev/null 2>&1
    fi

    msg "Setting up system settings..."
    #system setup
    $NSPAWN rootfs_$ARCH chmod u+s /usr/bin/ping 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH update-ca-trust 1> /dev/null 2>&1
    
    msg "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "hdmi_drive=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "audio_pwm_mode=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "/dev/mmcblk0p1  /boot   vfat    defaults        0       0" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "rock64" ]] || [[ "$DEVICE" = "rockpro64" ]]; then
        echo "No device setups for $DEVICE..."
    elif [[ "$DEVICE" = "pinebook" ]]; then
        $NSPAWN rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
        $NSPAWN rootfs_$ARCH --user manjaro systemctl --user enable pinebook-user.service 1> /dev/null 2>&1
    else
        echo ""
    fi
    
    msg "Cleaning rootfs for unwanted files..."
       if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]]; then
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-arm-static
    else
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    fi
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*

    msg "$DEVICE $EDITION rootfs complete"
}

create_rootfs_oem() {
    msg "Creating OEM image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    echo "Removing old rootfs..."
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    fi
    
    # fetch and extract rootfs
    msg "Downloading latest $ARCH rootfs..."
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    
    msg "Extracting $ARCH rootfs..."
    sudo bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    msg "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syy base $PKG_DEVICE $PKG_EDITION dialog manjaro-arm-oem-install --needed --noconfirm
    
    msg "Enabling services..."
    # Enable services
    $NSPAWN rootfs_$ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    msg "Applying overlay for $EDITION edition..."
    sudo cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/
    
    msg "Enabling user services..."
    if [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
        echo "No user services for $EDITION edition"
    else
        $NSPAWN rootfs_$ARCH --user $USER systemctl --user enable pulseaudio.service 1> /dev/null 2>&1
    fi

    msg "Setting up system settings..."
    #system setup
    $NSPAWN rootfs_$ARCH chmod u+s /usr/bin/ping 1> /dev/null 2>&1
    $NSPAWN rootfs_$ARCH update-ca-trust 1> /dev/null 2>&1
    sudo mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
    sudo cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
    
    
    msg "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "hdmi_drive=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "audio_pwm_mode=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt
        echo "/dev/mmcblk0p1  /boot   vfat    defaults        0       0" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "rock64" ]] || [[ "$DEVICE" = "rockpro64" ]]; then
        echo "No device setups for $DEVICE..."
    elif [[ "$DEVICE" = "pinebook" ]]; then
        $NSPAWN rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
        $NSPAWN rootfs_$ARCH --user manjaro systemctl --user enable pinebook-user.service 1> /dev/null 2>&1
    else
        echo ""
    fi
    
    msg "Cleaning rootfs for unwanted files..."
       if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]]; then
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-arm-static
    else
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    fi
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*

    msg "$DEVICE $EDITION OEM rootfs complete"
}

create_img() {
    # Test for device input
    if [[ "$DEVICE" != "rpi2" && "$DEVICE" != "oc1" && "$DEVICE" != "oc2" && "$DEVICE" != "xu4" && "$DEVICE" != "pinebook" && "$DEVICE" != "rpi3" && "$DEVICE" != "rock64" && "$DEVICE" != "rockpro64" ]]; then
        echo 'Invalid device '$DEVICE', please choose one of the following'
        echo 'rpi2  |  oc1  | oc2  |  xu4 | pinebook | rpi3 | rock64 | rockpro64'
        exit 1
    else
    msg "Building image for $DEVICE $EDITION edition..."
    fi

    if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]]; then
        ARCH='armv7h'
    else
        ARCH='aarch64'
    fi

    if [[ "$EDITION" = "minimal" ]]; then
        _SIZE=2000
    else
        _SIZE=5000
    fi

    #making blank .img to be used
    sudo dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$_SIZE 1> /dev/null 2>&1

    #probing loop into the kernel
    sudo modprobe loop 1> /dev/null 2>&1

    #set up loop device
    LDEV=`sudo losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    sudo losetup $LDEV $IMGDIR/$IMGNAME.img 1> /dev/null 2>&1


    # For Raspberry Pi devices
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        #partition with boot and root
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary fat32 0% 100M 1> /dev/null 2>&1
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        sudo parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.vfat "${LDEV}p1" 1> /dev/null 2>&1
        sudo mkfs.ext4 "${LDEV}p2" 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        sudo mount ${LDEV}p1 $TMPDIR/boot
        sudo mount ${LDEV}p2 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        sudo mv $TMPDIR/root/boot/* $TMPDIR/boot

    #clean up
        sudo umount $TMPDIR/root
        sudo umount $TMPDIR/boot
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root $TMPDIR/boot
        sudo partprobe $LDEV 1> /dev/null 2>&1

    # For Odroid devices
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]] || [[ "$DEVICE" = "xu4" ]]; then
        #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/

    #flash bootloader
        cd $TMPDIR/root/boot/
        sudo ./sd_fusing.sh $LDEV 1> /dev/null 2>&1
        cd ~

    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1

    # For pinebook device
    elif [[ "$DEVICE" = "pinebook" ]]; then

    #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        sudo dd if=$TMPDIR/root/boot/u-boot-sunxi-with-spl-$DEVICE.bin of=${LDEV} bs=8k seek=1 1> /dev/null 2>&1
        
    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1
        
    # For rockpro64 device
    elif [[ "$DEVICE" = "rockpro64" ]]; then

    #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        sudo dd if=$TMPDIR/root/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc 1> /dev/null 2>&1
        sudo dd if=$TMPDIR/root/boot/uboot.img of=${LDEV} seek=16384 conv=notrunc 1> /dev/null 2>&1
        sudo dd if=$TMPDIR/root/boot/trust.img of=${LDEV} seek=24576 conv=notrunc 1> /dev/null 2>&1
        
    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1
    else
        #Not sure if this IF statement is nesssary anymore
        echo "The $DEVICE" has not been set up yet
    fi
}

create_zip() {
    msg "Compressing $IMGNAME.img..."
    #zip img
    cd $IMGDIR
    xz -zv --threads=0 $IMGNAME.img

    msg "Removing rootfs_$ARCH"
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
}

create_rootfs_zip() {
    #zip rootfs
    cd $ROOTFS_IMG/rootfs_$ARCH
    sudo zip -qr ../$IMGNAME.zip .
    sudo mv ../$IMGNAME.zip $IMGDIR/
    
    msg "Removing rootfs_$ARCH"
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
}

build_pkg() {
    #cp package to rootfs
    msg "Copying build directory {$PACKAGE} to rootfs..."
    $NSPAWN $BUILDDIR/$ARCH mkdir build 1> /dev/null 2>&1
    sudo cp -rp "$PACKAGE"/* $BUILDDIR/$ARCH/build/

    #build package
    msg "Building {$PACKAGE}..."
    $NSPAWN $BUILDDIR/$ARCH/ chmod -R 777 build/ 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH/ --chdir=/build/ makepkg -sc --noconfirm
}

export_and_clean() {
    if ls $BUILDDIR/$ARCH/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "Package Succeeded..."
        msg "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$ARCH
        cp $BUILDDIR/$ARCH/build/*.pkg.tar.xz* $PKGDIR/$ARCH/
        msg "Package saved as {$PACKAGE} in {$PKGDIR/$ARCH}..."

        #clean up rootfs
        msg "Cleaning rootfs..."
        sudo rm -rf $BUILDDIR/$ARCH > /dev/null

    else
        msg "!!!!! Package failed to build !!!!!"
        msg "Cleaning rootfs"
        sudo rm -rf $BUILDDIR/$ARCH > /dev/null
        exit 1
    fi
}

get_profiles() {
    if ls $PROFILES/arm-profiles/* 1> /dev/null 2>&1; then
        cd $PROFILES/arm-profiles
        git pull
    else
        cd $PROFILES
        git clone https://gitlab.com/Strit/arm-profiles.git
    fi
}
