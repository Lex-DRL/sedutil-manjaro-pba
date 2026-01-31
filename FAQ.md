# FAQ

## Where are builds for BIOS and/or 32-bit systems?
Not in this repo. At this point _(early 2026)_, only really old hardware uses legacy BIOS instead of UEFI. And with such old PCs, official PBAs work just fine.

## How to use?
The same way you're supposed to, according to [the official docs](https://github.com/Drive-Trust-Alliance/sedutil/wiki/Encrypting-your-drive), but when it comes to `--loadPBAimage` step, use my PBAs instead of the bundled ones... Yes, you'd need to copy them on a second USB stick and mount it during setup process, which requires some familiarity with linux and terminal.

> [!WARNING]
> Currently, there's a chicken and egg problem: to "flash" the drive with this PBA... you still need to use the official rescue images **for the initial setup process itself**. And those images use the same boot process as the official PBAs. So, if the official PBAs won't work on your hardware, the rescue images won't work for you either.

## Then... still, how to use it, if I can't boot from the official rescue images?
There are two solutions at the moment, both are somewhat-hacky:

#### A bit "more official", but hardware-dependent solution
- Perform the entire setup process on a PC which **CAN** boot from the official resue images, but use my PBA image.
- When you're done, just take the SSD from the "setup PC" and install it into the main PC you intend to use it in.
- **TEST THAT IT DOES SUCCESSFULLY DECRYPT THERE** - before partitioning it and loading it with data.

#### A bit more technical solution
Forget about the official rescule images altogether, and instead perform the setup process while booting from a live image of a regular Linux distro _(I recommend an Arch-based user-friendly one, like **[Manjaro](https://manjaro.org/)**)_.

While in live environment, you have two sub-options:
- just enable AUR in pamac (the bundled package manager in Manjaro) and install `sedutil` AUR package to get sedutil binaries used for the setup process only (the encrypted drive will use its own binaries bundled with the PBA image).
  - Keep in mind that this way, you'll get the latest (somewhat-unstable) version of sedutil binaries, from the `1.4x` branch.
- just manually get the `sedutil-cli` binary of a desired version (preferably, the same one as in the PBA you're going to use). One of the easiest ways to do it is just [building this repo](#how-can-i-get-a-newer-pba-with-morebetter-drivers): as a subproduct, the build script will provide the extracted binaries, neatly grouped into a folder for you (under `bld/mnt/SEDUTIL_BIN`).
  - Don't forget to `cd` into that dir and call `./sedutil-cli` (explicitly, the one from THIS directory), not just `sedutil-cli`.

## Why so complicated?
I hacked together this repo really fast and dirty, just for myself + decided to share (and backup) it here, nothing more.

In the future (if I get some time to improve it), I was intending to [turn **the PBA image itself** into the rescue image](/TODO.md), too - so it would be able to also boot into a "special" setup mode, where it would just "clone" itself into the SSD you set up encryption on.

## Why this repo at all? Shouldn't the official repo just release a new PBA?
atm the `sedutil` repo [is almost abandonware](https://github.com/Drive-Trust-Alliance/sedutil/issues/445#issuecomment-1671023291). The lastest stable version (1.20) still does its job amazingly well... but it's not reasonable to expect maintainers to actually release any newer boot images any time soon.

## Then why wouldn't big hardware vendors maintain it?
I'm puzzled by the same question.

<details>
  <summary>My highly opinionated and hot personal take on the matter</summary>
  
  > `sedutil` is developed by Drive-Trust-Alliance, which, [according to its website](https://www.drivetrust.com/members/), originally partnered with uber-giants like [Micron](https://www.micron.com/) and [Oracle](https://www.oracle.com/). Also, `sedutil` is **THE ONLY** OS-agnostic, somewhat-complete and somewhat-official (even recommended on [Arch wiki](https://wiki.archlinux.org/title/Self-encrypting_drives)) way of using OPAL 2.0. And hardware vendors like Samsung or WD claim OPAL support in their drives, in official specs. However, it looks silly to me that they advertize OPAL support while giving their regular (non-enterprize) customers **NO** way of actually using it.
  > 
  > To add insult to injury, maintaining `sedutil` in minimally usable state _(doing the same thing I did here: just releasing images with updated drivers, and **MAYBE** patching some critical bugs from time to time)_ would cost basically nothing to any of these mega-corporations.
  > 
  > So I have no idea why I, as an end user, have to spend a significant amount of time fixing something that's supposed to just work out of the box if it's claimed as a product feature. To me, the whole situation looks like just another example of corporate greed at its finest.
</details>

However, I must add that there are different perspectives at the issue, and [I've been challanged about my position as being unreasonable](https://github.com/Drive-Trust-Alliance/sedutil/issues/516#issuecomment-3584392419) (and I see the opponent's point, too).

## What's changed, compared to official PBAs?
Beyond using Manjaro's boot system - only the initial text on decryption screen:
- The exact build version of the currently booted PBA is shown. Helps a lot when you have various PBA versions on different SED-encrypted drives.
- Device list is shown BEFORE decryption, too. For many years, I've been annoyed by the lack of it (to be able to see if all the drives are connected properly BEFORE attempting to decrypt them).

## Why is version name so long?
Example: `1.20-kernel-6.12.48-1-Manjaro-25.0.10-script-1.0.0`

It explicitly tells versions of all the components this image consists of:
- The first number (`1.20`) is the version of `sedutil` binaries included (the "core" of the decryption process).
- `...-kernel-6.12.48-1` suffix clarifies a specific linux kernel.
- `...-Manjaro-25.0.10` is a release version of Manjaro this image was built under.
- `...-script-1.0.0` is a version of build script from this repo the image is built with. The script is also included into the image itself.

## If PBAs from this repo are designed for newer hardware, why are there images with older `1.15` and `1.15.1` versions of `sedutil`?
From my experience, different `sedutil` versions have issues working with different hardware.

For example, the official `1.20` PBA freezes post-decryption _(so, it can't reboot into OS without a hard reset)_ on `MSI Pro Z690-A WiFi` motherboard in my desktop PC, while the older `1.15` PBA works just fine on this motherboard, and also loads faster.
But my another PC (MSI laptop), even when using the updated PBAs from this repo, prints warnings and errors on `1.15` and `1.15.1`.

## So, which version should I download?
First, try the very last build. It should work the same for older PCs, but also have better compatibility with the newest ones.

If (**AND ONLY IF**) you face any issues with it _(unreasonably long boot, some drives not being detected, error messages printed, etc.)_, you could try lower `sedutil` versions, while still sticking to the latest kernel/Manjaro/build script, unless you have a very specific reason not to _(for example, you don't like the features of updated script, or the most recent Manjaro has broken support for some rare hardware, and haven't patched it yet)_.

## Why are these PBAs so big?
In short, "good enough for me".

I'm not a low-level Linux developer. I just coded the build script in this repo to make SED-encrypted SSDs work on my new laptop (`MSI Vector 16 HX A2XW`), and I relied on Manjaro defaults as much as possible. There's a ton of ways to optimize the image size... but come on. It's 32MiB vs 80MiB. Official specs of OPAL require shadow MBR area to be at least 128Mb, so it fits there anyway. And doing the PBA "properly" would require **A LOT** more time invested by me.

Besides, this bigger size is mostly caused by more drivers included. imo, better safe than sorry about missing drivers.

## What drivers are included?
- Everything that comes with `linux-firmware-other` package from the official Manjaro repositories.
- Also, microcode updates for both intel/AMD is included, too. Not sure if it helps, but it won't hurt, and costs effectively nothing to include.

Theoretically, it means that these images should be compatible with **ANY** modern laptop or desktop PC. If Manjaro can boot on it, PBAs from this repo should boot, too.

... and if they don't _(because I haven't released a new build for a while)_, the task of building a newer PBA is a matter of running **one** script, which supposedly "just works".

## How can I get a newer PBA with more/better drivers?
If none of [the published PBAs](https://github.com/Lex-DRL/sedutil-manjaro-pba/releases) work for you _(you have a **much** newer hardware, we're talking years here)_, you can build a more up-to-date image yourself.
- Boot into your own Manjaro instance _(no need to install it, live boot from USB should be perfectly fine, too)_.
- Download [the `build.sh` script](https://github.com/Lex-DRL/sedutil-manjaro-pba/blob/main/build.sh). I highly suggest saving it into an empty folder.
- `[Optional]` Open it with a text editor (Kate) and modify the `SEDUTIL_VER=...` line. Three versions are available: `1.15`, `1.15.1`, `1.20`
  - Alternatively, you can comment out the line / set it to empty string or any other value - to use the most recent `sedutil` from AUR instead. However, keep in mind that [the latest `1.49.x` branch is unstable atm (Nov-Dec 2025)](https://github.com/Drive-Trust-Alliance/sedutil/issues).
- Open terminal: `Ctrl+Alt+T` or just `F12`
- Just to be safe, pre-update the running Manjaro before the main build: `sudo pacman -Syyu`
  - no need to enable AUR in pamac.
- `cd` into the folder you saved the script to, and execute `/bin/sh ./build.sh`
- If prompted, type the password for `sudo`.
- Wait till completion. If everything goes fine, you'll get a new image in the same directory.

Except for `sedutil` itself, this image will contain the latest versions of all the dependencies available at build time. After build completes, the `bld` folder can be deleted. But you might want to keep it to speed up subsequent builds, which could be useful for...

## I have multiple SED-encrypted drives. Will all of them have EFI partition with the same UUID?
Yes, if all of them are flashed with the same PBA image. But it shouldn't be a problem.

<details>
  <summary>Explanation</summary>
  
  > When a SED-encrypted drive is in a locked state, the entire contents of it are read-only: both EFI partition and the rest of "empty" (encrypted) space.
  > 
  > So, after "flashing" the drive with PBA (after loading it into so-called "shadow MBR"), you can't modify EFI partition in any way. Thus, even though multiple drives flashed with the same image would have EFI with same UUID, it's not just UUID. Such EFI partitions are **entirely identical**, byte-to-byte, and they can't be changed - no matter how long you use a drive.
  > 
  > *... except for data rot at the lowest hardware level, due to phenomenon like cosmic rays, but it's a **whole** another topic. And it's **astronomically** unlikely to happen for such a small image.*
</details>

**TL;DR: it doesn't matter which to boot from. They're identical.**

But if you're still worrying or your motherboard is very picky about it, nothing stops you from building the same PBA version multiple times, one right after another _(renaming the output image between the builds, of course)_. No need to delete the created `bld` directory, it's handled correctly. The builds would be identical, except for the EFI UUIDs, which are random.

## Why Manjaro? There are distros suiting the purpose of building a tiny boot disk much better!
Arch-based distros have benefits of:
- The most up-to-date package versions being available as soon as possible.
- Any software missing in official repositories would likely be in AUR, which makes it extremely easy to install.
- It has [Arch Wiki](https://wiki.archlinux.org/title/Main_page), an exceptionally complete source of info for anything Linux-related, which came very handy during development of this repo.

## But why _MANJARO_, specifically? Why not `${distroname}`? Why not pure Arch? I use Arch, btw!
Among Arch-based distros, I'm most familiar with Manjaro and I like it. Simple as that.

As for Arch itself... despite many attempts, I still haven't managed to install a fully working Arch instance with a user-friendly GUI, while I could be up and running with Manjaro in literally 5 minutes _(download the latest ISO, copy it to a [Ventoy](https://www.ventoy.net/)-formatted drive I already have, and just boot it)_.

Also, keep in mind that I made this build script for my own use, and originally, I wasn't intending to share anything with anyone. But the build process turned out as much more convoluted than what I thought, so... here we are. Take it or leave it. Or fork it. Or do your own PBA from scratch, using "the right" distro. 🤷🏻‍♂️
