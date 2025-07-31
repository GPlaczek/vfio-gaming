#!/bin/bash

# https://github.com/tianocore/edk2/discussions/4662

QEMU_VM_NAME=${QEMU_VM_NAME:-qemu_vm}

ASSETS_DIR=${HOME}/.local/share/${QEMU_VM_NAME}
RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp}/${QEMU_VM_NAME}

OVMF_PATH=${ASSETS_DIR}/ovmf.fd
C_DRIVE_PATH=${ASSETS_DIR}/${QEMU_VM_NAME}.qcow2
D_DRIVE_PATH=/dev/nvme0n1p4

MONITOR_SOCK=${RUNTIME_DIR}/monitor.sock
SPICE_SOCK=${RUNTIME_DIR}/spice.sock

LOOKING_GLASS_PATH=/dev/shm/looking-glass

mkdir -p -- "${RUNTIME_DIR}"

start() {
    qemu-system-x86_64 \
        -machine q35 -enable-kvm -m 16G -mem-prealloc \
        -smp cores=4,threads=2,sockets=1 \
        -cpu host,hv_vpindex,hv_time,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_runtime,hv_synic,hv_stimer,host-phys-bits-limit=0x28 \
        -rtc base=localtime \
        -daemonize \
        -vga std \
        -monitor unix:"${MONITOR_SOCK}",server=on,wait=off \
        -spice unix=on,addr="${SPICE_SOCK}",disable-ticketing=on \
        -device virtio-serial-pci \
        -bios "${OVMF_PATH}" \
        -drive format=qcow2,file="${C_DRIVE_PATH}" \
        -drive file="${D_DRIVE_PATH}",format=raw,media=disk,if=virtio \
        -device qemu-xhci \
        -device usb-host,hostbus=0,hostport=8 \
        -device usb-host,hostbus=1,hostport=4 \
        -net user,smb="${HOME}/${QEMU_VM_NAME}/mnt" \
        -net nic,model=virtio \
        -device ich9-intel-hda \
        -device ich9-intel-hda,addr=1f.1 \
        -audiodev pa,id=snd0,server=unix:${XDG_RUNTIME_DIR:-/tmp}/pulse/native,out.mixing-engine=off \
        -device hda-output,audiodev=snd0 \
        -device vfio-pci,host=01:00.0,x-vga=on \
        -device vfio-pci,host=01:00.1 \
        -device vmbus-bridge,irq=7 \
        -device ivshmem-plain,memdev=ivshmem \
        -object memory-backend-file,size=128M,share=on,mem-path="${LOOKING_GLASS_PATH}",id=ivshmem
}

stop() {
    echo system_powerdown | socat UNIX-CONNECT:"${MONITOR_SOCK}" - >/dev/null 2>&1
}

connect() {
    looking-glass-client -c "${SPICE_SOCK}" -p 0
}

$@
