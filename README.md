# BigLinux ARM Tools
Contains scripts and files needed to build and manage biglinux-arm packages and images.

*These tools only work on Manjaro based distributions!*

## Dependencies
These scripts rely on certain packages, other than what's in the `base` package group, to be able to function. These packages are:
* parted (arch repo)
* libarchive (arch repo)
* git (arch repo)
* qemu-user-static-binfmt (arch repo)
* dosfstools (arch repo)
* pacman (arch repo)
* polkit (arch repo)
* gnugpg (arch repo)
* wget (arch repo)
* zstd (arch repo) - unzstd used for early package verification and zstd image compression
* systemd-nspawn with support for `--resolv-conf=copy-host` (arch repo)

### Optional Dependencies
* gzip (arch repo) (for `builddockerimg`)
* docker (arch repo) (for `builddockkerimg`)
* mktorrent (arch repo) (for torrent support in `deployarmimg`)
* rsync (arch repo) (for `deployarmimg`)
* bmap-tools (AUR or manjaro repo) (for BMAP support in `buildarmimg`)
* btrfs-progs (arch repo) (for btrfs support in `buildarmimg`)
* grub-efi-arm64 (AUR) (for generic-efi image support in `buildarmimg`)

## From github (tagged or GIT version)
* Download the `.zip` or `.tar.gz` file from .
* Extract it.
* Copy the contents of `lib/` to `/usr/share/biglinux-arm-tools/lib/`.
* Copy the contents of `bin/` to `/usr/bin/`. Remember to make them executable.
* Create `/var/lib/biglinux-arm-tools/pkg` folder.
* Create `/var/lib/biglinux-arm-tools/img` folder.
* Create `/var/lib/biglinux-arm-tools/tmp` folder.
* Create `/var/cache/biglinux-arm-tools/img` folder.
* Create `/var/cache/biglinux-arm-tools/pkg` folder.
* Install `binfmt-qemu-static` package and make sure `systemd-binfmt` is running

# Usage
## buildarmpkg
This script is used to create packages for ARM architectures.
It assumes you have filled out the PACKAGER section of your `/etc/makepkg.conf`.

Options inside `[` `]` are optional. Use `-h` to see what the defaults are.

**Syntax**

```
sudo buildarmpkg -p package [-a architecture] [-k] [-i packages] [-b branch]
```

To use one or more local packages, put them all in the desired directory, named `packages` in the example below, before running the utility:
```
sudo buildarmpkg -p package [-a architecture] [-k] [-i packages] [-b branch]
```

To build an aarch64 package against arm-unstable branch use the following command:

```
sudo buildarmpkg -p package -a aarch64 -b unstable
```

You can also build `any` packages, which will use the aarch64 architecture to build from.

```
sudo buildarmpkg -p package -a any
```

The built packages will be copied to `$PKGDIR` as specified in `/usr/share/biglinux-arm-tools/lib/biglinux-arm-tools.conf` and placed in a subdirectory for the respective architecture.
Default package destination is `/var/cache/biglinux-arm-tools/pkg/`.

## signarmpkgs
This script uses the GPG identity you have setup in your /etc/makepkg.conf to sign the packages in the current folder.

```
cd <folder with built packages>
signarmpkgs
```

## buildarmimg
For a list of supported devices and editions, please look at the Profiles repository linked below.

This script will compress the image file and place it in `/var/cache/biglinux-arm-tools/img/`

Profiles that gets used are from this [Github](https://github.com/biglinux/biglinux-arm-profiles) repository.

**Syntax**

```
sudo buildarmimg [-d device] [-e edition] [-v version] [-n] [-x] [-i packages] [-b branch] [-m] [-z compression]
```

To build a minimal image version 18.07 for the raspberry pi 3 on arm-unstable branch with bmap support:

```
sudo buildarmimg -d rpi3 -e minimal -v 18.07 -b unstable -m
```

To build a minimal version 18.08 RC1 for the odroid-c2 with a new rootfs downloaded:

```
sudo buildarmimg -d oc2 -e minimal -v 18.08-rc1 -n
```

To build an lxqt version with one or more local packages installed for the rock64:

```
sudo buildarmimg -d rock64 -e lxqt -i packages
```

To build an xfce version with one or more local packages installed for the rock64, put them all in the desired directory, named `packages` in the example below, before running the utility:

```
sudo buildarmimg -d rock64 -e xfce -i packages
```

To build a kde-plasma edition for the Pinebook Pro with btrfs filesystem:

```
sudo buildarmimg -d pbpro -e kde-plasma -p btrfs
```

To build a factory image for the Pinebook Pro, with BSP uboot:
```
sudo buildarmimg -d pbpro-bsp -e kde-plasma -f
```
A log is located at /var/log/biglinux-arm-tools/buildarmimg-$(date +%Y-%m-%d-%H:%M).log

## buildemmcinstaller (depricated)
This script does almost the same as the `buildarmimg` script.

Except that it always creates a minimal image, with an already existing image inside it, only to be used for internal storage (eMMC) deployments.

**Syntax**
```
sudo buildemmcinstaller [-d device] [-e edition] -v version [-f flashversion] [-n] [-x] [-i packages]
```

So to build an eMMC installer image for KDE Plasma 19.04 on Pinebook:
```
sudo buildemmcinstaller -d pinebook -e kde-plasma -v 19.04 -f first-emmc-flasher
```
Be aware that the device, edition and version, most already exist on the OSDN download page, else it won't work.


## buildrootfs
This script does exactly what it says it does. It builds a very small rootfs, to be used by the BigLinux ARM Installer and `buildarmimg`. Right now only supports `aarch64`.

**Syntax**
```
sudo buildrootfs
```

To build an aarch64 rootfs:
```
sudo buildrootfs
```

A log is located at /var/log/biglinux-arm-tools/buildrootfs-$(date +%Y-%m-%d-%H:%M).log

## builddockerimg
This script is similar to `buildrootfs`, except that it builds a rootfs ready for package building and turns it into a docker image, that can be uploaded to DockerHub.

**Syntax**
```
sudo builddockerimg
```
This uploads the docker file directly to the BigLinux ARM acccount on DockerHub.

A log is located at /var/log/biglinux-arm-tools/builddockerimg-$(date +%Y-%m-%d-%H:%M).log

## deployarmimg (depricated)
This script will create checksums for and upload the newly generated image. It assumes you have upload access to our OSDN server.
If you don't, you can't use this.

**Syntax**

```
deployarmimg -i image [-d device] [-e edition] [-v version] -k email@server.org [-t] [-u osdn-username]
```

To upload an image to the raspberry pi minimal 18.07 folder use with torrent:

```
deployarmimg -i biglinux-arm-minimal-rpi3-18.07.img.xz -d rpi3 -e minimal -v 18.07 -k email@server.org -t
```

## getarmprofiles
This script will just clone or update the current profile list in `/usr/share/biglinux-arm-tools/profiles/`.
So nothing fancy.

This would enable users to clone the profiles repository, make any changes they would like to their images and then build them locally.
So if you made changes to the profiles yourself, don't run `getarmprofiles` and you will still have your edits.

But if you messed up your profiles somehow, you can start with the repo ones with:
```
sudo getarmprofiles -f
```
