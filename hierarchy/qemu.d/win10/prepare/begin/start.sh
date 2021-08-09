set -x

source "/etc/libvirt/hooks/kvm.conf"

systemctl stop sddm.service


echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

sleep 10

modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r drm_kms_helper
modprobe -r nvidia
modprobe -r i2c_nvidia_gpu
modprobe -r drm
modprobe -r nvidia_uvm

virsh nodev-detach $VIRSH_GPU_VIDEO
virsh nodev-detach $VIRSH_GPU_AUDIO

modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
