<!-- series: qemu edu pci driver -->

# 02 - interrupts and dma with qemu edu

welcome back. [[03_qemu_pci_driver_setup|last time]] i got the edu device to calculate `5!` by repeatedly checking its status register. that works, but i wanted the device to tell the driver when it was done.

## step 6 - listening for an interrupt

an interrupt is the device getting the cpu's attention. edu supports MSI (message signaled interrupts), where the device signals an interrupt using a pci write. linux gives the driver an IRQ number and calls its handler when the interrupt arrives.

i added a per-device structure to hold the mapped BAR, IRQ and a completion. a completion lets one part of the kernel wait until another part signals that an event has happened.

```c
struct edu_device {
    void __iomem *bar;
    struct completion factorial_done;
    int irq;
};

init_completion(&edu->factorial_done);
pci_set_drvdata(pdev, edu);
```

`pci_set_drvdata()` lets `remove` get the same structure back with `pci_get_drvdata()`. the interrupt handler gets it through its `data` argument.

i asked for one MSI vector and registered a threaded handler:

```c
pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_MSI);
edu->irq = pci_irq_vector(pdev, 0);
request_threaded_irq(edu->irq, NULL, edu_irq_thread,
                     IRQF_ONESHOT, "edu", edu);
```

the handler reads edu's interrupt status, acknowledges the bits at `0x64`, and signals the completion if the factorial bit was set:

```c
static irqreturn_t edu_irq_thread(int irq, void *data)
{
    struct edu_device *edu = data;
    u32 status = ioread32(edu->bar + 0x24);

    if (!status)
        return IRQ_NONE;
    iowrite32(status, edu->bar + 0x64);
    if (status & 0x01)
        complete(&edu->factorial_done);
    return IRQ_HANDLED;
}
```

then probe can enable factorial interrupts, start the calculation and sleep until the handler wakes it up:

```c
iowrite32(0x80, edu->bar + 0x20); /* enable factorial interrupt */
iowrite32(5, edu->bar + 0x08);
if (!wait_for_completion_timeout(&edu->factorial_done,
                                 msecs_to_jiffies(1000)))
    /* handle timeout */;
factorial = ioread32(edu->bar + 0x08);
```

i gave it a timeout so a missing interrupt wouldn't leave probe waiting forever. which turned out to be a good idea, because the first attempt timed out. i tried five seconds too. still nothing. apparently waiting harder is not a debugging technique.

## step 7 - letting the device speak

the missing piece was bus mastering:

```c
pci_enable_device(pdev);
pci_set_master(pdev);
```

`pci_enable_device()` prepares the device for use; `pci_set_master()` allows it to initiate transactions on the pci bus. MSI is a device-initiated write, so the earlier CPU-initiated MMIO accesses could work while the interrupt did not. after adding that call, the log finally said:

```text
factorial: 5! = 120 (MSI)
```

on removal i disable the device's factorial interrupt, free the handler and vector, then unmap and release BAR0 and disable the device. the real code also unwinds these resources if probe fails. a successful result is nice; a successful unload is nicer.

## step 8 - giving edu some memory

next up: DMA, or direct memory access. instead of the cpu copying each byte to a device, the driver gives it a memory address and a length and lets the device do the transfer. edu has a separate internal buffer, so this is a different feature from the factorial calculation.

the address the device uses isn't necessarily the same as the pointer the cpu uses. an IOMMU, for example, can translate device addresses. the kernel's [DMA API](https://docs.kernel.org/core-api/dma-api-howto.html) gives us the right address instead of guessing from a C pointer.

by default edu supports 28-bit DMA addresses. i told the kernel about that limit and allocated a 64-byte coherent buffer:

```c
dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(28));
edu->dma_buf = dma_alloc_coherent(&pdev->dev, 64,
                                  &edu->dma_handle, GFP_KERNEL);
```

`dma_buf` is the cpu pointer; `dma_handle` is the address to give edu. coherent memory handles cache visibility for this allocation, though it doesn't remove the need to order operations properly. the address changed between module loads, which was a good reminder to use the returned handle every time.

## step 9 - the round trip

edu's internal 4 KiB DMA buffer starts at device address `0x40000`. it has source, destination, count and command registers at `0x80`, `0x88`, `0x90` and `0x98`. i wrote a transfer function to choose a direction and poll the command register until the start bit clears:

```c
if (to_ram) {
    iowrite32(0x40000, edu->bar + 0x80);
    iowrite32((u32)edu->dma_handle, edu->bar + 0x88);
    command = 0x01 | 0x02;
} else {
    iowrite32((u32)edu->dma_handle, edu->bar + 0x80);
    iowrite32(0x40000, edu->bar + 0x88);
    command = 0x01;
}
iowrite32(64, edu->bar + 0x90);
iowrite32(command, edu->bar + 0x98);
ret = readl_poll_timeout(edu->bar + 0x98, status,
                         !(status & 0x01), 1000, 1000000);
```

bit `0x01` starts the transfer; `0x02` selects device-to-guest RAM. the 28-bit mask makes the cast to `u32` fit here. the DMA test uses polling; the factorial path still uses MSI.

to check that anything actually moved, i filled guest memory with a pattern, copied it to edu, cleared guest memory, and copied it back:

```c
buf = edu->dma_buf;
for (i = 0; i < 64; i++)
    buf[i] = i;

edu_dma_transfer(edu, false); /* guest RAM -> edu */
memset(buf, 0, 64);
edu_dma_transfer(edu, true);  /* edu -> guest RAM */

for (i = 0; i < 64; i++)
    if (buf[i] != i)
        /* report mismatch */;
```

the actual test checks both transfer return values before moving on. if a transfer times out, the driver retains the buffer and asks for a guest reboot: a timeout alone doesn't prove that the device has stopped using the memory. on a normal unload it frees the coherent buffer.

and the guest finally gave me this:

```text
allocated 64-byte DMA buffer, DMA address: 0x0000000005c1d000
identification: 0x010000ed
liveness: wrote 0x12345678, read 0xedcba987
factorial: 5! = 120 (MSI)
DMA round trip: 64 bytes verified
svnu: edu device removed
```

the tests currently run during probe, when the module is loaded. there isn't a userspace interface yet, so that's what i want to work on next, along with a test program to exercise the driver. for now, the bytes made it there and back and the module unloaded without warnings. i'll take it.

## disclaimer

all of this is still pretty new to me. i followed a bunch of tutorials to get here, and i'm not well versed enough to remember all the inputs, defines and function names on my own yet. i do get the overall flow though, and i think with enough practice i'll eventually be able to write all of this without a tutorial open beside me. i'm excited to finish this series and make more projects along the way. hopefully with fewer mysterious timeouts.

laters!
svnu©️ 11-November-2026
