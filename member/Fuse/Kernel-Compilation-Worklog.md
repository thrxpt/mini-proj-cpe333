# Kernel Compilation & Installation Worklog
- **Author:** Onsinee Chotchuangsakulchai (Fuse), Student ID: 67070501078
- **Branch:** Fuse
- **OS Target:** Ubuntu 24.04 LTS (VMware / VirtualBox / WSL2)
- **Date:** 2026-09-22
- **Build Host:** WSL2 `Ubuntu-24.04`, user `fuse2005`
- **Kernel Target:** `6.8.12` vanilla from kernel.org (same `6.8` series as Ubuntu 24.04, whose packaged kernel is `6.8.0-139.139`)
- **Custom suffix:** `-fuse2005` → `6.8.12-fuse2005`
- **Result:** SUCCESS — my machine is now running `6.8.12-fuse2005`

---

## Task Checklist
- [x] 1. System Environment Setup
- [x] 2. Kernel Compilation and Installation Procedure
- [x] 3. System Verification and Boot Testing
- [x] 4. Technical Challenges and Problem Resolution
- [x] 5. Comparison & Conclusion

---

## 1. System Environment Setup

### 1.1 Hardware Specifications and VM Allocation

**My host machine (measured on 2026-09-22 in WSL2):**
- CPU: `AMD Ryzen 7 8840U w/ Radeon 780M Graphics`, 8 Cores / 16 Threads
- `Architecture: x86_64, CPU(s): 16, Thread(s) per core: 2, Core(s) per socket: 8`
- Virtualization: `AMD-V`, Hypervisor vendor: `Microsoft`, type: `full` (WSL2)
- Caches: L1d/L1i `256 KiB x8`, L2 `8 MiB x8`, L3 `16 MiB x1`
- RAM: `15Gi` total, `14Gi` available
- Swap: `4.0Gi`
- Disk `/` (`/dev/sdd`): `1007G` total, `953G` available — plenty for a kernel build (~20 GB needed)

**VM spec I recommend for reproducing this on VMware/VirtualBox:**
- CPU Cores: 4–8 vCPU (minimum 2)
- RAM: 8 GB minimum (8–16 GB recommended; I built with 15 GiB and `-j16`)
- Disk: 60 GB minimum (80–100 GB recommended; source is 136 MB but the build tree grows to ~12 GB plus 2.3 GB of installed modules)
- OS ISO: `ubuntu-24.04.x-desktop-amd64.iso` or the server ISO
- My actual WSL2 environment: 16 vCPU, 15 GiB RAM, 1007G virtual disk

**Commands I used to check the system:**
```bash
lscpu
free -h
df -h
cat /etc/os-release
uname -r
nproc
gcc --version
make --version
```

### 1.2 OS / Toolchain (my actual outputs, trimmed)

```
$ cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.4 LTS"
VERSION="24.04.4 LTS (Noble Numbat)"

$ uname -r   # BEFORE reboot
6.6.87.2-microsoft-standard-WSL2   # stock WSL2 kernel

$ uname -r   # AFTER reboot
6.8.12-fuse2005

$ free -h
Mem:  15Gi total, 14Gi available
Swap: 4.0Gi

$ df -h / → /dev/sdd 1007G, 953G available
$ nproc → 16
$ gcc --version → gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
$ make --version → GNU Make 4.3
```

### 1.3 Build dependencies

I checked and found these already installed on my machine: `build-essential`, `gcc 13.3`,
`make 4.3`, `flex`, `bison 3.8.2`, `bc`, `rsync`, `cpio`, `perl`,
`libssl-dev 3.0.13`, `libelf-dev 0.190`, `libzstd-dev`, `xz-utils`, `zstd`,
`pahole`, `kmod`, and `openssl`.
`/proc/config.gz` was present (the running WSL2 kernel config), so I used it as my `.config` base.
`/boot/config*` did not exist, which is normal on WSL2 since there is no GRUB.

I then installed the remaining packages with `sudo apt install`:
`libncurses-dev`, `dwarves`, and `initramfs-tools 0.142ubuntu25.8`.

---

## 2. Kernel Compilation and Installation Procedure

What I did on my machine, step by step: checked the specs → checked dependencies →
downloaded the `linux-6.8.12` source → configured it with my `-fuse2005` tag →
ran `make -j16` (about 27 minutes) → ran `modules_install` and `make install` →
pointed `.wslconfig` at the new kernel → `wsl --shutdown` → rebooted into
`uname -r = 6.8.12-fuse2005`. Each step below shows my real commands and outputs.

### 2.1 Install dependencies

The full dependency install (works on both a real Ubuntu 24.04 VM and WSL2):
```bash
sudo apt update
sudo apt install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev \
  bc rsync cpio perl dwarves pahole libzstd-dev xz-utils zstd kmod \
  initramfs-tools debhelper fakeroot
```

### 2.2 Download kernel source (2026-09-22 15:48)

I chose vanilla `6.8.12` because Ubuntu 24.04 Noble ships the `6.8` series
(`linux-generic` → `6.8.0-139.139`), and the vanilla tarball builds the same way
on both WSL2 and a VM.

```bash
mkdir -p ~/kernel-build && cd ~/kernel-build
wget --continue https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.12.tar.xz
# → 142594556 bytes (136M), downloaded in ~47 seconds
tar -xf linux-6.8.12.tar.xz
```

### 2.3 Configure (2026-09-22 15:48)

```bash
cd ~/kernel-build/linux-6.8.12
zcat /proc/config.gz > .config.wsl2-base
cp .config.wsl2-base .config
make olddefconfig
./scripts/config --set-str CONFIG_LOCALVERSION '-fuse2005'
grep LOCALVERSION .config   # CONFIG_LOCALVERSION="-fuse2005"
# → release name becomes 6.8.12-fuse2005, .config is 210K
```

I based my config on the running WSL2 kernel config so all Hyper-V/9p graphics
options stay enabled. On a VMware/VirtualBox VM I would instead run
`cp /boot/config-$(uname -r) .config && make olddefconfig` (or `make defconfig`).

### 2.4 Compile (started 15:48, `bzImage` done 16:13, modules done ~16:15)

```bash
nohup make -j16 > ~/kernel-build/build.log 2>&1 &
# I monitored progress with: tail -f ~/kernel-build/build.log
# The build went through: host scripts → io_uring/crypto → drivers/*
#   → net/fs → drm (amdgpu/nouveau) → efi stub → vmlinux link (BTF)
#   → module link (LD/BTF [M] *.ko) → done
```

My build results:
- `arch/x86/boot/bzImage` — 16M
- `vmlinux` — 376M, `System.map` — 7.9M
- 920 x `*.ko` modules, with no real errors in `build.log`

### 2.5 Install

```bash
sudo make modules_install
# → installed to /lib/modules/6.8.12-fuse2005 (2.3G), DEPMOD ok, exit 0

sudo make install
# → /boot/vmlinuz-6.8.12-fuse2005 (16M)
# → /boot/initrd.img-6.8.12-fuse2005 (218M, generated by update-initramfs)
# → /boot/System.map-6.8.12-fuse2005 and config-6.8.12-fuse2005
# → dkms autoinstall finished, vmlinuz/initrd.img symlinks updated, exit 0
```

**Booting the new kernel on WSL2** (WSL2 has no GRUB, so I load the kernel via `.wslconfig`):
```bash
cp /boot/vmlinuz-6.8.12-fuse2005 /mnt/c/Users/ACER/kernel-fuse2005
```
`C:\Users\ACER\.wslconfig`:
```
[wsl2]
kernel=C:\\Users\\ACER\\kernel-fuse2005
```
```powershell
wsl --shutdown
wsl -d Ubuntu-24.04 -- uname -r   # → 6.8.12-fuse2005
```

On a VMware/VirtualBox VM the last step is instead:
`sudo update-initramfs -c -k 6.8.12-fuse2005 && sudo update-grub && sudo reboot`.

---

## 3. System Verification and Boot Testing

My verification outputs after rebooting:

```bash
$ uname -r
6.8.12-fuse2005
$ uname -a
Linux Onsinee-Labtop 6.8.12-fuse2005 #1 SMP PREEMPT_DYNAMIC Tue Sep 22 16:12:02 +07 2026 x86_64 GNU/Linux
$ cat /proc/version
Linux version 6.8.12-fuse2005 (fuse2005@Onsinee-Labtop) (gcc 13.3.0, GNU ld 2.42) #1 SMP PREEMPT_DYNAMIC ...
$ ls /lib/modules/ → 6.6.87.2-microsoft-standard-WSL2 + 6.8.12-fuse2005
$ ls -lh /boot/ → vmlinuz-6.8.12-fuse2005 (16M), initrd.img-6.8.12-fuse2005 (218M), System.map, config
$ dmesg | head -1 → Linux version 6.8.12-fuse2005 ... Hypervisor detected: Microsoft Hyper-V
$ uptime → system up and functional right after reboot
```

- [x] `bzImage` built with no errors
- [x] `modules_install` and `make install` both exited 0
- [x] After reboot, `uname -r` shows `6.8.12-fuse2005`
- [x] `dmesg` is clean (only harmless WSL2/Hyper-V notices about the legacy timer, ACPI _OSC, and a WSL network check)
- [ ] Screenshots to add under `member/Fuse/Image/` (terminal `uname` capture for WSL2 / GRUB menu for VM)

To roll back to the stock kernel: delete `C:\Users\ACER\.wslconfig`, run `wsl --shutdown`,
and WSL2 boots `6.6.87.2-microsoft-standard-WSL2` again.

---

## 4. Technical Challenges and Problem Resolution

| # | Issue I ran into | How I solved it |
|---|------------------|-----------------|
| 1 | WSL2 runs `6.6.87.2-microsoft-standard-WSL2`, not a generic Ubuntu `6.8` kernel, so the normal GRUB reboot flow does not apply | I used `/proc/config.gz` as my config base and boot the new kernel through `.wslconfig` instead of GRUB; I documented the GRUB path separately for VMs |
| 2 | My user needed a `sudo` password, so dependency installs had to be interactive | The pre-installed packages already covered the build, and I installed the rest (`libncurses-dev`, `dwarves`, `initramfs-tools`) with `sudo apt install` while the build was running |
| 3 | A background `make` can die when its parent shell exits | I launched it with `nohup ... &` logging to `build.log` and confirmed from a fresh shell that it kept running until it finished |
| 4 | A full Ubuntu-style config is slow on small lab VMs | I used `olddefconfig` from the lean WSL2 base plus `-j16`, which gave me `bzImage` in ~27 minutes; on a 2-vCPU machine I would use `localmodconfig` and `ccache` |
| 5 | Searching `build.log` for "error" gave false hits (filenames like `error_private`, `uterror`) | I filtered those out and confirmed there were zero real `Error`/`failed`/`undefined` lines |

---

## 5. Comparison & Conclusion

- **Stock vs custom:** the stock `6.6.87.2-microsoft-standard-WSL2` kernel vs my custom `6.8.12-fuse2005` (newer upstream 6.8 base, same WSL2 driver options, built with Ubuntu GCC 13.3.0 and tagged `-fuse2005`). My boot log confirms the Hyper-V/WSL2 integration still works.
- **VM vs WSL2:** a VM gives the full GRUB/initramfs/dkms boot test with snapshots; WSL2 gave me a fast 16-core build (~27 minutes vs hours on a 2-vCPU VM) but boots via a `.wslconfig` kernel replacement instead of GRUB. I executed the WSL2 path end to end.
- **Cost:** 136 MB download → ~12 GB build tree + 2.3 GB installed modules + 218 MB initramfs; about 30 minutes wall-clock with `-j16` and 15 GiB RAM. On a 2-vCPU/4 GB lab VM I would expect 2–4x longer.
- **Conclusion:** I compiled, installed, and booted my custom kernel `6.8.12-fuse2005` on Ubuntu 24.04 (WSL2). `uname -r`, `/proc/version`, `dmesg`, and the module tree all confirm the new kernel is live. Remaining work: add screenshots to `member/Fuse/Image/`, and repeat the GRUB path once on a VMware/VirtualBox VM with the same source and config method.

### My method vs the other group's method

Another group built the kernel the official Ubuntu way (`apt source` + ABI bump to `999`
+ `fakeroot debian/rules binary` producing `.deb` packages installed with `dpkg -i`).
I did not use that method — I used the vanilla kernel.org path described above, running
every step myself from download to a successful boot, with my commands and outputs logged
in sections 2.1–2.5. The table below only compares the two approaches.

| Aspect | My method — vanilla kernel.org (this worklog) | Other group — Ubuntu `debian/rules` |
|---|---|---|
| Source | `linux-6.8.12.tar.xz` from kernel.org (136 MB) | `apt source` of the Ubuntu-patched kernel |
| Version tag | `CONFIG_LOCALVERSION=-fuse2005` → `6.8.12-fuse2005` | ABI `999` in the changelog → e.g. `6.8.0-999.48` |
| Config | `.config` from `/proc/config.gz` + `make olddefconfig` | `fakeroot debian/rules editconfigs` (menuconfig) |
| Build | `make -j16` → `bzImage` + modules (~27 min for me) | `fakeroot debian/rules binary` → `.deb` packages (1–3 h, ~30 GB disk) |
| Install | `make modules_install` + `make install` (WSL2 via `.wslconfig`) | `sudo dpkg -i linux-*.deb` → `update-grub` → reboot |
| Verify | `uname -r` against my `.config`/`Makefile` version | `uname -r` against the changelog ABI |
| Strengths | Fast and simple, ideal for a lab/WSL2 machine | Official Ubuntu packaging, reproducible `.deb` files |
| Trade-offs | No `.deb` packages; manual initramfs/GRUB handling | Slow and heavy; `apt source` of the running kernel fails on WSL2 (the stock kernel is `microsoft-standard`, not in the Ubuntu archive) |

_Reference for the other group's method: [How to build an Ubuntu Linux kernel](https://ubuntu.com/kernel/docs/how-to/develop-customise/build-kernel/)_

---

## Appendix — Useful commands

```bash
# monitor a build
tail -f ~/kernel-build/build.log
du -sh ~/kernel-build/linux-6.8.12/
ls -lh ~/kernel-build/linux-6.8.12/arch/x86/boot/bzImage

# verify the running kernel
uname -r && cat /proc/version && ls /lib/modules/ && dmesg | head -5

# roll back to the stock WSL2 kernel (on Windows)
# delete C:\Users\ACER\.wslconfig, then: wsl --shutdown
```
