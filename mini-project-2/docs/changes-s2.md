# S2 — Compile miniramfs against 6.8.12-fuse2005

## Build setup
- Added `src/Makefile` (out-of-tree kbuild, `KDIR=/home/fuse2005/kernel-build/linux-6.8.12`).
- Compiler: gcc 13.3.0. Result: `miniramfs.ko`, vermagic `6.8.12-fuse2005 SMP preempt mod_unload modversions`.
- `make` and `make W=1`: **0 compiler warnings, 0 errors** (only "clock skew" notes from building on OneDrive/drvfs, not from the code).

## Signatures verified in `$KDIR/include/linux/fs.h` (6.8.12)
| Used in miniramfs.c | fs.h line | Result |
|---|---|---|
| `.create(struct mnt_idmap *, struct inode *, struct dentry *, umode_t, bool)` | 2044 | matches |
| `.mkdir(struct mnt_idmap *, ..., umode_t)` returns `int` | 2050 | matches (returns `struct dentry *` only from 6.15) |
| `.setattr(struct mnt_idmap *, struct dentry *, struct iattr *)` | 2057 | matches |
| `.getattr = simple_getattr` | 3216 | matches |
| `.rename = simple_rename(struct mnt_idmap *, ...)` | 3227 | matches |
| `.link/.unlink/.rmdir = simple_*` | 3220-3222 | matches |
| `setattr_prepare/setattr_copy(struct mnt_idmap *, ...)` | 3299/3301 | matches |
| `inode_init_owner(struct mnt_idmap *, ...)`, `nop_mnt_idmap` | 1911 | matches |
| `simple_inode_init_ts`, `inode_set_ctime_current`, `inode_set_mtime_to_ts` | 1625 / 1524 / 1571 | exist in 6.8, signatures match |
| `file_system_type.mount`, `mount_nodev`, `kill_litter_super` | 2457 / 2483 / 2491 | exist in 6.8 (removed in later kernels in favour of `fs_context`) |

## Source changes
**None required.** The skeleton already follows the 6.8 API (mnt_idmap, timestamp helpers, int-returning mkdir).

## Notes for the "ปัญหาที่พบ" chapter
1. No `Makefile` existed; `KDIR` must point to the *built* 6.8.12 tree (needs `Module.symvers`, `.config`).
2. `.ko` is built with `CONFIG_MODVERSIONS=y` and vermagic `6.8.12-fuse2005`, so it only loads on that exact kernel.
3. At the time of testing the WSL2 distro was running `6.18.58.1-microsoft-standard-WSL2`, because `kernel=` in `C:\Users\ACER\.wslconfig` is commented out. `insmod` would be rejected until WSL boots the custom kernel.
4. Building on `/mnt/c/...` (OneDrive) gives "clock skew" warnings; harmless, but building in the Linux filesystem avoids them.

## Runtime — status (kernel 6.8.12-fuse2005 booted, built in /tmp/b on ext4)
- `tests/test_miniramfs.sh`: **21 passed, 0 failed** (log: `docs/test_result.log`).
- Test-script fix: TC-01 "fs visible in mount" grepped `miniramfs on /mnt/test`, but `mount` prints
  `none on /mnt/test type miniramfs`; pattern corrected (no change to miniramfs.c).
- 20x `insmod -> mount -> umount -> rmmod` loop: 0 failures, module count 0 afterwards, no oops/BUG in dmesg.
