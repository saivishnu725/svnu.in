# 00 - writing a pci driver for qemu

## abstract

i have been poking at the linux kernel for a while now, mostly sending small fixes and figuring out how patches make their way in. but i haven't written a driver that actually talks to a device. so i thought i'd try that.

there is one small problem: i don't have a pci device sitting around waiting for me to write a driver for it. and i would rather not learn what a bad kernel pointer does on my actual machine. enter [qemu](https://www.qemu.org/).

qemu can emulate a whole computer, including a little pci device called [edu](https://www.qemu.org/docs/master/specs/edu.html). it exists for people learning to write drivers. it has registers to read and write, can raise interrupts, and can move data using dma. no shopping required. my wallet approves.

## the idea

i want to build a small linux guest, plug the edu device into it, and write a kernel module that talks to it. the driver will have to find the device on the pci bus and figure out how to communicate with it. eventually i want a userspace program to be able to ask it to do things too.

i'll be using the edu specification as a datasheet and going through this one piece at a time. this is a learning project, so expect some mistakes, some digging around, and hopefully a working driver at the end of it. the advantage of doing this in a virtual machine is that when i inevitably break something, i can just restart the guest. hopefully.

this series is also a way to keep track of what i learn and why the code is there. otherwise i will look at it in a month and wonder who wrote it. spoiler: it was me.

see you in [[03_qemu_pci_driver_setup|the next one]], where i set up the lab and get the driver talking to edu.

laters!
svnu©️ 11-November-2026
