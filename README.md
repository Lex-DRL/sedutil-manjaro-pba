# sedutil-Manjaro-PBA
Manjaro-based PBA images for [sedutil](https://github.com/Drive-Trust-Alliance/sedutil). UEFI-only.

## TL;DR
Images in this repo should work on modern PCs, while being compatible with all the same OPAL-supporting drives the official PBA images are compatible with.

Go to [releases](https://github.com/Lex-DRL/sedutil-manjaro-pba/releases) section 👉🏻 and download one.

## Purpose of the repo
[Pre-built boot images in the official sedutil repo](https://github.com/Drive-Trust-Alliance/sedutil/wiki/Executable-Distributions) haven't been updated for quite a while now (the latest [v1.20 PBA](https://github.com/Drive-Trust-Alliance/exec/releases/tag/1.20.0) - Aug 2021). Thus, they don't support modern hardware (especially laptops), and you might end up with a PC which is unable to decrypt its SSDs simply because none of the official PBAs can boot on this PC.

However, the actual `sedutil` binaries (executables) work just fine, as well as the encrypted drives themselves. It's the **bootable image** that needs updating. Specifically, drivers in it. So, I took a modern Arch-based Linux distro ([Manjaro](https://manjaro.org/)) and built entirely new PBA images based on it. Therefore:
- The whole "wrapper", the whole foundation of the image uses Manjaro's boot process, so these images should be compatible with any modern PCs.
- But the actual `sedutil` executables called on boot (to decrypt the drives) are the same ones from the official PBAs.

Basically, my PBA builds are just images of a boot EFI partition for freshly installed Manjaro... without Manjaro itself, but with `sedutil`.

## FAQ

If you have any further questions / unsure about this repo, please refer to [FAQ](/FAQ.md).
