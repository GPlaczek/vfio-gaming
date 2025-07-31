# VFIO gaming

The following is a guide for setting up a Windows virtual machine with GPU passthrough for gaming. It is tailored for my specific hardware so bare in mind that you will have to make some adjustments to make it work on different hardware. This guide is written to work on Arch Linux and is inspired by the following archwiki page:
https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
It involves some extra steps to make the setup work without the need to run the qemu process as root. It also launches qemu directly, `libvirt` is not involved on any step, nor is it required to complete the setup.

## Launching qemu

The virtual machine itself can be started using the `qemu.sh` script. This script defines a lot of qemu parameters, I'll explain some of them in the following sections.

### Audio support

To make audio work in the virtual machine, you need to pass in the pulseaudio server socket to the virtual machine. Normally, it is an UNIX socket located somewhere in the `XDG_RUNTIME_DIR` (locations may be different on different linux distros). Keep in mind that if you want to run the qemu process as a `root`, you'll need to either pass a complete path to the pulseaudio socket (`$(realpath $XDG_RUNTIME_DIR/pulse/native)`) instead or configure pulseaudio to allow for explicit system-wide access.
```
-audiodev pa,id=snd0,server=unix:${XDG_RUNTIME_DIR:-/tmp}/pulse/native,out.mixing-engine=off
-device hda-output,audiodev=snd0
```

### USB devices

To pass USB devices (like gamepads) to the virtual machine, you need the following qemu parameters:
```
-device qemu-xhci
-device usb-host,hostbus=0,hostport=8
-device usb-host,hostbus=1,hostport=4
```
These make USB devices connected to two specific ports in your PC available to the virtual machine. Do note that these port numbers may vary, you need to find your own port numbers.

### Looking glass

Looking glass can be used for high-fps video streaming from the virtual machine. For more information see https://looking-glass.io/.
```
-device ivshmem-plain,memdev=ivshmem
-object memory-backend-file,size=128M,share=on,mem-path="${LOOKING_GLASS_PATH}",id=ivshmem
```
Do keep in mind that you need a HDMI/DisplayPort dummy plug connected to your GPU for this to work.

## GPU passthrough

Setting up a GPU passthrough involves several steps, most of them are well-documented on the [archwiki page](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_IOMMU). To summarize, these are the steps that need to be done:

### Kernel parameters

To enable iommu, add the following to the `GRUB_CMDLINE_LINUX_DEFAULT` variable:
```
intel_iommu=on iommu=pt
```
To specify PCI devices, add the following arguments to `GRUB_CMDLINE_LINUX_DEFAULT`:
```
vfio-pci.ids=cafe:1234,dead:beef
```
Update these numbers with your devices' device and vendor ids. Keep in mind that if your GPU defines two devices (e.g. one for audo and one for video), you need to pass both of them to the virtual machine. The devices specified here will be claimed by the `vfio_pci` driver (if the rest of the configuration is right).

### Kernel modules

All modprobe configurations are in the `modprobe.d` directory.
* `blacklist-nouveau.conf` - blacklists `nvidia` and `nouveau` modules to prevent them from claiming the GPU
* `iommu_unsafe_interrupts.conf` - needed for iommu to work properly
* `kvm.conf` - prevents windows guest from crashing on some occasions
* `vfio.conf` - ensures that `vfio_pci` claims the GPU before the `nvidia` driver attempts to

### Initramfs

On Arch linux, add the following modules and hooks to `/etc/mkinitcpio.conf`:
```
MODULES=(... vfio_pci vfio vfio_iommu_type1 ...)
HOOKS=(... modconf ...)
```
Remember to regenerate the initramfs using the following command afterwards:
```
mkinitcpio -P
```

## Rootless

Running this setup as a non-root user requires some additional configuration.
This could be more convenient but is rather a matter of preference.

### User groups

My way of allowing user access to certain devices is to create a dedicated user group and assign desired devices to this group. I also define udev rules that set ownership of these devices. These rules are in the `rules.d` directory.
```
SUBSYSTEM=="block", KERNEL=="nvme0n1p4", GROUP="qemu-local-vms"
SUBSYSTEM=="vfio", GROUP="qemu-local-vms"
```
TODO: improve the way of detecting block devices and PCI devices.

### Ulimit

On Arch linux, limits for locked memory regions are too low to lock enough memory for my GPU. These limits can be increased by including the following lines in the `/etc/security/limits.conf` (replace `<user>` with your user name):
```
<user>	hard	memlock	29360128
<user>	soft	memlock	29360128
```
The value of these limits varies depending on what GPU you use, it is easy to find the right value by trial and error.

# Contributing

If my guide helped you in any way and you would like to improve it, feel free to open an issue or a pull request.
