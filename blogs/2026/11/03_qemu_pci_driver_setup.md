<!-- series: qemu edu pci driver -->

# 01 - setting up the qemu edu lab

welcome back. in [[02_qemu_pci_driver_intro|the last post]] i decided to write a pci driver for qemu's edu device. first i need somewhere to run it and a way to tell if the device is even listening.

## step 1 - a tiny linux guest

i used a separate worktree of my linux source (~/src/linux; story for another series) and built an x86-64 kernel into a separate directory. the lab used `v7.4-rc1`. keeping the build separate also means my other kernel work doesn't move the ground under this module.

```sh
git -C ~/src/linux worktree add --detach ~/edu-lab/linux v7.4-rc1
cd ~/edu-lab
make -C linux O="$PWD/build" x86_64_defconfig
make -C linux O="$PWD/build" -j"$(nproc)"
```

the guest also needs a userspace. i used a statically linked busybox binary in `rootfs/bin/busybox` and a small `/init`. an initramfs is a cpio archive that the kernel unpacks into memory and uses as its initial root filesystem. `/init` is the first userspace process it runs.

```sh
#!/bin/busybox sh
/bin/busybox --install -s
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo "svnu edu lab up"
exec setsid cttyhack sh
```

busybox provides the shell and the little commands i need. it has to be static here because i didn't put any shared libraries in the guest. `exec` replaces init with the shell; if the first process exits, the kernel is not particularly happy.

i packed the rootfs and booted it directly, no disk image or bootloader needed:

```sh
cd rootfs
find . -print0 | cpio --null -o -H newc --owner root:root | gzip -9 > ../initramfs.cpio.gz
cd ..
qemu-system-x86_64 -enable-kvm -cpu host -m 512M -smp 2 \
    -kernel build/arch/x86/boot/bzImage -initrd initramfs.cpio.gz \
    -append "console=ttyS0 nokaslr" -device edu -nographic
```

`-device edu` adds our pretend pci card. the serial console and `-nographic` put the guest in the terminal. inside the guest, `lspci -nn` showed `1234:11e8`. the card exists. well, as much as an emulated card can exist.

## step 2 - hello from the kernel

before talking to the device i built a hello-world module. a module is code loaded into the running kernel, so no `printf` or libc here. `pr_info` writes to the kernel log instead.

```c
static int __init hello_init(void)
{
    pr_info("hello from the kernel\n");
    return 0;
}

static void __exit hello_exit(void)
{
    pr_info("goodbye from the kernel\n");
}

module_init(hello_init);
module_exit(hello_exit);
MODULE_LICENSE("GPL");
```

the module makefile points at the same build directory as the kernel the guest boots:

```makefile
obj-m := hello.o edu.o
KDIR := ../build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
```

then the little loop that i would become very familiar with: build the module, copy it into the rootfs, repack the initramfs, boot and load it.

```sh
make -C driver
cp driver/hello.ko rootfs/root/
./mkinitramfs.sh
./run.sh
# inside the guest
insmod /root/hello.ko
dmesg | tail
rmmod hello
```

## step 3 - finding edu

pci devices have vendor and device IDs in their configuration space. linux discovers the devices and matches those IDs against the driver's table. for edu they are `0x1234` and `0x11e8`.

```c
static const struct pci_device_id edu_ids[] = {
    { PCI_DEVICE(0x1234, 0x11e8) },
    { }
};
MODULE_DEVICE_TABLE(pci, edu_ids);

static struct pci_driver edu_driver = {
    .name = "edu",
    .id_table = edu_ids,
    .probe = edu_probe,
    .remove = edu_remove,
};
module_pci_driver(edu_driver);
```

when a matching device binds, the kernel calls `edu_probe()` with a `struct pci_dev`. `edu_remove()` runs when the device is unbound or the driver is unloaded. the empty entry marks the end of the table. my first probe just printed a message; seeing it meant linux had found both my module and the right device.

## step 4 - talking through bar0

edu exposes its registers through BAR0, a pci memory resource. this is memory-mapped I/O (MMIO): accesses to the mapped region talk to the device instead of ordinary RAM. the [edu spec](https://www.qemu.org/docs/master/specs/edu.html) tells us what lives at each offset.

after enabling the device, i claimed BAR0 and mapped it. the snippets here leave out error handling so the flow is easier to see; the actual driver checks each operation and unwinds on failure.

```c
pci_enable_device(pdev);
pci_request_region(pdev, 0, "edu");
bar = pci_iomap(pdev, 0, 0);
pci_set_drvdata(pdev, bar);
```

`bar` is a `void __iomem *`, not an ordinary pointer to RAM. i use the kernel's I/O accessors to read and write the registers:

```c
u32 id = ioread32(bar + 0x00);
iowrite32(0x12345678, bar + 0x04);
u32 liveness = ioread32(bar + 0x04);
```

`0x00` is the identification register. `0x04` is a liveness check: write a 32-bit value and the device returns its bitwise inverse. the guest log said:

```text
identification: 0x010000ed
liveness: wrote 0x12345678, read 0xedcba987
```

it inverted my number. communication! not exactly a riveting conversation, but we have to start somewhere.

on removal the mapping, region and device are released in reverse order: `pci_iounmap()`, `pci_release_region()` and `pci_disable_device()`. failure paths need to release only the resources they actually acquired.

## step 5 - factorial by polling

edu can calculate a factorial. write a number to offset `0x08`, wait for the busy bit at `0x20` to clear, then read the result from `0x08`.

```c
iowrite32(5, bar + 0x08);
ret = readl_poll_timeout(bar + 0x20, status,
                         !(status & 0x01), 100, 1000000);
if (ret)
    /* handle timeout */;
factorial = ioread32(bar + 0x08);
```

this checks every 100 microseconds, with a one second timeout. the result was `5! = 120`. i now have an entire virtual computer to do something my calculator can do. progress.

i also managed to fall through into the error cleanup after a successful probe. the calculation worked, but unloading produced warnings because the resources had already been released. a `return 0` before the cleanup labels fixed that: successful probe keeps the resources until `remove`.

polling works, but the device can also tell us when it is done. that's where [[04_qemu_pci_driver_msi_dma|the next post]] starts.

laters!
svnu©️ 11-November-2026
