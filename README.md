# sedutil-Manjaro-PBA
Manjaro-based PBA images for [sedutil](https://github.com/Drive-Trust-Alliance/sedutil).

## TL;DR
Images in this repo should work on modern PCs, while being compatible with all the same OPAL-supporting drives the official PBA images compatible with.

Go to [releases](https://github.com/Lex-DRL/sedutil-manjaro-pba/releases) section 👉🏻 and download one.

## Purpose of the repo
[Pre-built boot images in the official sedutil repo](https://github.com/Drive-Trust-Alliance/sedutil/wiki/Executable-Distributions) haven't been updated for quite a while now (the latest [v1.20 PBA](https://github.com/Drive-Trust-Alliance/exec/releases/tag/1.20.0) - Aug 2021). Thus, they don't support modern hardware (especially laptops), and you might end up with a PC which is unable to decrypt its SSDs simply because none of the official PBAs can boot on this PC.

However, the actual `sedutil` binaries (executables) work just fine, as well as the encrypted drives themselves. It's the **bootable image** what needs updating. Specifically, drivers in it. So, I took a modern Arch-based Linux distro ([Manjaro](https://manjaro.org/)) and built entirely new PBA images based on it. Therefore:
- The whole "wrapper", the whole foundation of the image uses Manjaro's boot process, so these images should be compatible with any modern PCs.
- But the actual `sedutil` executables called on boot (to decrypt the drives) are the same ones from the official PBAs.

## FAQ

### How to use?
The same way you supposed to, according to [the official docs](https://github.com/Drive-Trust-Alliance/sedutil/wiki/Encrypting-your-drive), but when it comes to `--loadPBAimage` step, use my PBAs instead of the bundled ones... yes, you'd need to copy them on a second USB stick and mount it during setup process.

### Where are builds for BIOS and/or 32-bit systems?
Not in this repo. At this point _(late 2025, almost 2026)_, only quite old hardware uses legacy BIOS instead of UEFI. And with such old PCs, official PBAs work just fine.

### What's changed?
Beyond using Manjaro's boot system - only the decryption screen:
- The exact build version of the currently booted PBA is shown. Helps a lot when you have various PBA versions on different SED-encrypted drives.
- Device list is shown BEFORE decryption, too. For many years, I've been annoyed by the lack of it (to be able to see if all the drives are connected properly BEFORE attempting to decrypt them).

### Why is version name so long?
Example: `1.20-kernel-6.12.48-1-Manjaro-25.0.10-script-1.0.0`

It explicitly tells versions of all the components this image consists of:
- The first number (`1.20`) is the version of `sedutil` binaries included (the "core" of decryption process).
- `...-kernel-6.12.48-1` suffix clarifies a specific kernel.
- `...-Manjaro-25.0.10` is a release version of Manjaro this image was built under.
- `...-script-1.0.0` is a version of build script from this repo the image is built with. The script is also included into the image itself.

### If PBAs from this repo are designed for newer hardware, why are there images with older `1.15` and `1.15.1` versions of `sedutil`?
From my experience, various `sedutil` versions have issues working with various hardware. For example, the official `1.20` PBA freezes post-decryption (so, it can't reboot) on `MSI Pro Z690-A WiFi` motherboard in my desktop PC, while the older `1.15` works just fine, and also loads faster.
But my another PC (MSI laptop), even when using the updated PBAs from this repo, prints warnings and errors on `1.15` and `1.51.1`.

So, try the latest `sedutil` version first, and only if you have any issues (long boot, some drives not being detected, or error messages printed), try earliner ones.

### Why are these PBAs so big?
In short, "good enough for me".

I'm not a low-level Linux developer. I just coded the build script in this repo to make SED-encrypted SSDs work on my new laptop (`MSI Vector 16 HX A2XW`), and I relied on Manjaro defaults as much as possible. There's a ton of ways to optimize the image size... but come on. It's 32Mb vs 80Mb. Official specs of OPAL require shadow MBR area to be at least 128Mb, so it fits there anyway. And doing the PBA "properly" would require **A LOT** more time invested by me.

### What drivers are included?
Everything that comes with `linux-firmware-other` package from the official Manjaro repositories. Theoretically, it means that these images should be compatible with **ANY** modern laptop or desktop PC. If Manjaro can boot on it, PBAs from this repo should boot, too.

### How can I get a newer PBA with more/better drivers?
If none of [the published PBAs](https://github.com/Lex-DRL/sedutil-manjaro-pba/releases) work for you (you have even newer hardware), you can build a newer image yourself.
- Boot into your own Manjaro instance (no need to install it, live boot from USB is perfectly fine).
- Download [the `build.sh` script](https://github.com/Lex-DRL/sedutil-manjaro-pba/blob/main/build.sh)
- `[Optional]` Open it with a text editor (Kate) and modify the `SEDUTIL_VER=...` line. Three versions are available: `1.15`, `1.15.1`, `1.20`
  - Alternatively, you can comment out the line / set it to empty string or any other value - to use the most recent `sedutil` from AUR instead. However, keep in mind that [the latest `1.49.x` branch is unstable](https://github.com/Drive-Trust-Alliance/sedutil/issues).
- Open terminal, `cd` into the folder you saved the script to, and execute `/bin/sh ./build.sh`

Wait till completion. If everything goes fine, you'll get a new image in the same directory. This image is gonna be used with all the latest software available at build time.

### Why Manjaro? There are distros suiting the purpose of building a tiny boot disk much better!
Arch-based distros have benefits of:
- The most up-to-date package versions being availabla as soon as possible.
- Any software missing in official repositories would likely be in AUR, which is extremely easy to install.
- It has [Arch Wiki](https://wiki.archlinux.org/title/Main_page), an exceptionally complete soure of info for anything Linux-related, which came very handy during development of this repo.

### But why **Manjaro**, specifically? Why not `${distroname}`? Why not pure Arch? I use Arch, btw!
Among Arch-based distros, I'm most familiar with Manjaro and I like it. Simple as that.

As for Arch itself... I still haven't managed to istall a working Arch instance with user-friendly GUI, while I could be up and running with Manjaro in literally 5 minutes _(download the latest ISO, copy it to a [ventoy](https://www.ventoy.net/)-formatted drive I already have, and just boot it)_.
Also, keep in mind, that I made this build script for my own use, and I wasn't intending to share anything with anyone. But the task came out as much more convoluted than what I thought, so... here we are. Take it or leave it. Or fork it. Or do your own PBA from scratch, using on "the right" distro. 🤷🏻‍♂️

### TODO
1. The current PBAs don't have their respecitve "rescue system" images... because after some tests I decided it would be much better to use **THE SAME** image as both the unlocking PBA and as a rescue system to set up another drive from. Technically, nothing stops us from having a second boot option with shell, and dumping the same drive we've booted from into an image during setup process.
2. Official setup process is extremely user-unfriendly. Adding a setup script would be very handy.
