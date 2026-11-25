# Environment (S1)

| Item | Version |
| :-- | :-- |
| OS | Ubuntu 24.04.4 LTS on WSL2 (Windows 11) |
| Running kernel | `6.8.12-fuse2005` (`Linux 6.8.12-fuse2005 #3 SMP PREEMPT_DYNAMIC Sun Oct 4 2026 x86_64`) |
| Kernel image | `C:\Users\ACER\kernel-fuse2005` (set via `kernel=` in `C:\Users\ACER\.wslconfig`) |
| gcc | 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) — same as `CONFIG_CC_VERSION_TEXT` of the kernel |
| ld / make | GNU ld 2.42 / GNU Make 4.3 |
| Build tree (`KDIR`) | `/lib/modules/6.8.12-fuse2005/build` -> `/home/fuse2005/kernel-build/linux-6.8.12` |
| Build tree contents | `Module.symvers`, `.config`, `include/generated/{autoconf,utsrelease}.h`, `scripts/mod/modpost` all present |
| Kernel config | `CONFIG_MODULES=y`, `CONFIG_MODULE_UNLOAD=y`, `CONFIG_MODVERSIONS=y` |

## Notes

- `.wslconfig` must contain `kernel=C:\Users\ACER\kernel-fuse2005` (uncommented), then `wsl --shutdown`.
  Otherwise WSL boots stock `6.18.58.1-microsoft-standard-WSL2`, whose `/lib/modules/*/build` has no
  `Module.symvers`/`.config`, and a module built for 6.8.12 will not load (vermagic mismatch).
- Two header trees exist: `6.8.12-fuse2005` (source tree, used) and `6.8.12-fuse2005-fuse2005`
  (`/usr/src/linux-headers-...`, from a later `make bindeb-pkg`; not the running kernel).
- If the build tree is incomplete: `cd ~/kernel-build/linux-6.8.12 && make modules_prepare`.
- `sudo` in WSL asks for a password; from Windows use `wsl -u root` for insmod/rmmod.

## Hello module test (`/tmp/hello`, not in repo)

```
make            -> hello.ko  (vermagic: 6.8.12-fuse2005 SMP preempt mod_unload modversions)
insmod hello.ko -> OK, lsmod shows hello
dmesg | tail    -> hello: loading out-of-tree module taints kernel.
                   hello: loaded
rmmod hello     -> OK, dmesg: hello: unloaded
```

Result: PASS.
