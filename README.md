# single_gpu_passthrough

This is a fast guide and a repo to save all my configs after succesfully achieved a Single GPU passthrough using Qemu + KVM and libvirt hooks for swapping the graphics card between guest and host

## PC Specs

    ██████████████████  ████████   retama@retama-desktop 
    ██████████████████  ████████   --------------------- 
    ██████████████████  ████████   OS: Manjaro Linux x86_64 
    ██████████████████  ████████   Host: MS-7B79 4.0 
    ████████            ████████   Kernel: 5.10.56-1-MANJARO 
    ████████  ████████  ████████   Uptime: 1 hour, 16 mins 
    ████████  ████████  ████████   Packages: 1066 (pacman) 
    ████████  ████████  ████████   Shell: bash 5.1.8 
    ████████  ████████  ████████   Resolution: 3839x1080 
    ████████  ████████  ████████   DE: Plasma 5.22.4 
    ████████  ████████  ████████   WM: KWin 
    ████████  ████████  ████████   Theme: Breath2 [Plasma], Breath [GTK2/3] 
    ████████  ████████  ████████   Icons: breath2 [Plasma], breath2 [GTK2/3] 
    ████████  ████████  ████████   Terminal: konsole 
                                   Terminal Font: Noto Mono 10 
                                   CPU: AMD Ryzen 7 3700X (16) @ 3.600GHz 
                                   GPU: NVIDIA GeForce GTX 1070 
                                   Memory: 2496MiB / 16015MiB 

## Steps to achieve

Here im gonna explain the basics steps i followed to achieve the passthrough, but there are way better explanations of how to do this if you have diferent specs than mine:
* [Some Ordinary Gamers Tutorial](https://www.youtube.com/watch?v=BUSrdUoedTo)
* [Arch Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
* [Single GPU passthrough guide of joeknock90](https://github.com/joeknock90/Single-GPU-Passthrough)

### First step: Enable IOMMU

Use your favourite text editor and add `amd_iommu=on` or `intel_iommu=on` ased on which proccessor brand you have into your bootloader config. 

In my case i use grub and the file where you need to put those lines is in `/etc/default/grub` (In the case of GRUB the line where you need to input the iommu enable is in `GRUB_CMDLINE_LINUX_DEFAULT`

Mine looks like this: `GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on  udev.log_priority=3"`

After adding that apply changes to file with `sudo grub-mkconfig -o /boot/grub/grub.cfg` and reboot

### Second step: Check GPU IOMMU group

As said in the arch wiki execute the next script and remember or save which iommu id your GPU is in.
  
    #!/bin/bash
    shopt -s nullglob
    for g in `find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V`; do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done;
    done;
    
 In my case my output is :
 
    IOMMU Group 16:
        27:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1070] [10de:1b81] (rev a1)
        27:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)

Save this in a file or just remember it for later

### Step Three. Install Software:
You need the next packages:
* qemu
* libvirt
* edk2-ovmf
* virt-manager
* ebtables
* dnsmasq
* Your corresponding Nvidia drivers

After installing all of the packages, you need to enable some services so they automatically start when you boot your machine:


    sudo systemctl enable libvirtd.service
    sudo systemctl start libvirtd.service
    sudo systemctl enable virtlogd.socket
    sudo systemctl start virtlogd.socket
    sudo virsh net-autostart default
    sudo virsh net-start default
    
### Step Four: Patch GPU firmware
This depends on the GPU you have. Check out if you need to , but it's a really common step.

You need to download your GPU rom firmware from a page like [TechPowerUp](https://www.techpowerup.com/vgabios/)

After downloading your firmware, open it in a hex editor, and search in text mode for the word VIDEO. Then find the first character U before the VIDEO result, and delete from the U character to the beggining of the hex file (Leaving the U character, don't erase it). As you can see in the photo this is how it looks in the HEX editor: 

![rom_patch](https://user-images.githubusercontent.com/61742928/128759022-27fc35dc-8c2c-4e43-bc11-1ac3a3260a7d.png)

Once the file has been modified, save it in a path you remember in my case i stored it in my home directory

### Step Five: Install the desired OS in a VM
Just create a normal VM and install, just make sure to tick this box of _customize before install_ when you are in the last step:

![virtual_manager](https://user-images.githubusercontent.com/61742928/128759447-d13964cb-b786-488a-bf87-2cbbf3991a8d.png)

Its important to select the next config for _Chipset_ and _Firmware_ fields in Overview tab:

![vm_config](https://user-images.githubusercontent.com/61742928/128759711-8cfecd43-a4cb-407c-af1f-3fc8d9ba1e4b.png)

Boot the VM and just install normally the OS.

### Step Six: Install libvirt-hooks:
First create the directory where the hooks are going to be installed:

    sudo mkdir /etc/libvirt/hooks

Donwload the hooks  

    sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' \
     -O /etc/libvirt/hooks/qemu
     
And give the required permissions:
    
    sudo chmod +x /etc/libvirt/hooks/qemu

Then restart the service :

    sudo service libvirtd restart

### Step Seven: Create directory herarchy for the VM and hooks to work

Im gonna upload in this repo the hierarchy i used (Take in mind i have a win10 machine thats why the folder under qemu.d is called win10. You should change the win10 name of the folder for the name of the VM you are using.

The final hierarchy should look like this:
    
    /etc/libvirt/hooks/
    ├── kvm.conf
    ├── qemu
    └── qemu.d
        └── win10
            ├── prepare
            │   └── begin
            │       └── start.sh
            └── release
                └── end
                    └── revert.sh

Make sure to give `chmod +x` to start and revert scripts

Also kvm.conf file is gonna use the iommu group value from you graphics card. As i told you in step 2, in my case it looked like: 

    IOMMU Group 16:
    27:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1070] [10de:1b81] (rev a1)
    27:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)

So in that file i saved a variable that is going to be used in start and revert scripts that should match you iommu grouping id. In my case:

    VIRSH_GPU_VIDEO = pci_0000_27_00_0 -> 27:00.0 VGA compatible controller 
    VIRSH_GPU_AUDIO = pci_0000_27_00_1 ->  127:00.1 Audio device

For ending this part you need to take in mind that my start and revert scripts are thought for a NVIDIA graphics card, search for info if you have an amd, but it shouldn't be too different.

## Final Step: Pass the GPU to virtual machine

Just open virtual machine manager and add your graphics card, you should see something like this:

 ![pci_pass_vm](https://user-images.githubusercontent.com/61742928/128762571-12bab68a-e851-4daa-89f3-2f6056f67253.png)
 
 As you can see i have both PCI (Audio an video output of GPU ) passed. 
 
 Finally click on both (Audio and video) XML of the graphics card and add a line with your patched rom path, in my case i have it under `/home/retama/patch.rom`:
 
![xml_bios_config_vm](https://user-images.githubusercontent.com/61742928/128763555-1fa265ff-878c-4236-b66e-bc2663aba3f4.png)

Also make sure to add the vendor id line in the overview as show in here: 

![vendor_id_xml](https://user-images.githubusercontent.com/61742928/128765548-ef98639d-5ccb-45c6-8a9a-e05f6f242ab3.png)

The value can be whatever you want in my case i used test as value.

Before turning it on make sure to elminiate the splice display and Video QXL so it doesnt use an virtualized GPU

You can now boot the machine and everything should work normally, dont forget to install inside the vm your grpahics card drivers as if it was your Host OS
