# DO NOT EDIT THIS FILE
#
# Please edit /boot/armbianEnv.txt to set supported parameters
#

setenv overlay_error "false"
# default values
setenv rootdev "/dev/mmcblk1p1"
setenv verbosity "1"
setenv console "both"
setenv bootlogo "false"
setenv rootfstype "ext4"
setenv docker_optimizations "on"

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc ${devnum}:1 partuuid; fi
if test "${devtype}" = "usb"; then part uuid usb ${devnum}:1 partuuid; fi
echo "devtype: ${devtype}    ${partuuid}"
if test "${console}" = "display"; then setenv consoleargs "console=tty1"; fi

if test "${console}" = "serial"; then setenv consoleargs "console=ttyAML0,115200"; fi
if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyAML0,115200 console=tty1"; fi
if test "${console}" = "serial"; then setenv consoleargs "console=ttyAML0,115200"; fi
if test "${bootlogo}" = "true"; then
	setenv consoleargs "splash plymouth.ignore-serial-consoles ${consoleargs}"
else
	setenv consoleargs "splash=verbose ${consoleargs}"
fi
if test "${disable_vu7}" = "false"; then setenv usbhidquirks "usbhid.quirks=0x0eef:0x0005:0x0004"; fi

setenv bootargs "root=PARTUUID=${partuuid} rootwait rootfstype=${rootfstype} ${consoleargs} consoleblank=0 coherent_pool=2M loglevel=${verbosity} ubootpart=${partuuid} libata.force=noncq usb-storage.quirks=${usbstoragequirks} ${usbhidquirks} ${extraargs} ${extraboardargs}"
if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=memory"; fi
echo "Mainline bootargs: ${bootargs}"

load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${scriptaddr} ${prefix}dtb/amlogic/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${scriptaddr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${scriptaddr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${scriptaddr} || setenv overlay_error "true"
	fi
done

if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
else
	if load ${devtype} ${devnum} ${scriptaddr} ${prefix}dtb/amlogic/overlay/${overlay_prefix}-fixup.scr; then
		echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
		source ${scriptaddr}
	fi
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${scriptaddr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${scriptaddr}
	fi
fi

booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
