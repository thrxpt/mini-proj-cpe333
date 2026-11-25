# Screenshot Checklist: miniramfs (S4)

Environment for every screenshot: WSL2 Ubuntu-24.04 booted with **kernel `6.8.12-fuse2005`**
(`C:\Users\ACER\.wslconfig` → `kernel=C:\\Users\\ACER\\kernel-fuse2005`, then `wsl --shutdown`).
Run everything from the `mini-project-2/` folder with `sudo`.

**Rules for every image**
- The terminal must show the **command line** and its **output** in the same frame. Don't crop the prompt.
- Font ≥ 14 pt, dark background, window ≥ 100 columns wide.
- File names: `docs/screenshots/S4-<no>-<name>.png` (for example `S4-03-test-pass.png`).
- When you finish a shot, tick `[x]` in this file.

Reference logs (text, for the report/appendix): `tests/test_result.log`, `docs/screenshots/logs/*.log`

---

## ฟิวส์: Core & Kernel (for the Demo/code section)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-01 | `uname -r && cat /proc/version` | `6.8.12-fuse2005` (the kernel we built ourselves) | [ ] |
| S4-02 | `cd src && make && modinfo miniramfs.ko \| head -8` | `LD [M] ... miniramfs.ko` with no error, and `vermagic: 6.8.12-fuse2005` | [ ] |
| S4-03 | `sudo bash tests/demo.sh` (record the whole clip; also grab a still at step [2]) | heading `[2] Operation 1: MOUNT` + `none on /mnt/test type miniramfs` | [ ] |
| S4-04 | Open `src/miniramfs.c` around `miniramfs_write` / `miniramfs_read` | `copy_from_user`, `copy_to_user`, the `-EFBIG` check | [ ] |

## อุ๋งอิ๋ง: Test & Demo (for the test-results section)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-05 | `sudo bash tests/test_miniramfs.sh` (upper part) | `[PASS] TC-01` … `[PASS] TC-06` all lines | [ ] |
| S4-06 | same run (EDGE part) | `[PASS] EDGE-7` (unlink open file), `EDGE-8` (rmdir non-empty → ENOTEMPTY), `EDGE-9` (EFBIG), `EDGE-10` (2 processes) | [ ] |
| S4-07 | same run (end) | `[PASS] TC-07 umount && rmmod`, `no Oops/BUG/WARNING`, `=== RESULT: 36 passed, 0 failed ===` | [ ] |
| S4-08 | `sudo bash tests/leak_test.sh` | `round 50/50 ok`, the slabinfo before/after table, `RESULT: PASS - no measurable leak after 50 rounds` | [ ] |

## พิ้ง: Report 2 (Chapter 3 Re-build Kernel / Chapter 4 results)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-09 | `type C:\Users\ACER\.wslconfig` (PowerShell) + `wsl -d Ubuntu-24.04 uname -r` | the line `kernel=...kernel-fuse2005` and the output `6.8.12-fuse2005` | [ ] |
| S4-10 | `grep -E "DEBUG_FS=\|SLUB_DEBUG=\|KMEMLEAK" /boot/config-6.8.12-fuse2005` | `# CONFIG_DEBUG_KMEMLEAK is not set` (the reason we use slabinfo + counters instead) | [ ] |
| S4-11 | `sudo insmod src/miniramfs.ko && grep miniramfs /proc/filesystems && lsmod \| grep miniramfs` | `nodev miniramfs` and the module in lsmod | [ ] |

## พอช: Report 1 (Introduction / VFS theory)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-12 | `sudo mount -t miniramfs none /mnt/test && df -T /mnt/test && mount \| grep miniramfs` | type `miniramfs` registered with VFS like a normal fs | [ ] |
| S4-13 | `stat /mnt/test/docs/note.txt` (after creating the file) | inode number, Size, Links: VFS inode metadata | [ ] |

## ผึ้ง: Video & Slide (stills from demo.sh for the slides)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-14 | demo.sh step [5]–[6] | `echo ... >`, `>>`, then `cat` shows `CPE333 OS` / `Line 2` | [ ] |
| S4-15 | demo.sh step [7] | `ls -la /mnt/test/docs` shows `.` `..` `empty.txt` (0) `note.txt` (17) `sub` | [ ] |
| S4-16 | demo.sh step [8] | `head: error writing ... File too large` and the file is exactly `1048576` bytes (no crash) | [ ] |
| S4-17 | demo.sh step [9] | after `umount`, `ls /mnt/test` is empty (data lived only in RAM) | [ ] |

## เจแปน: QA (cross-check theory ↔ results)

| # | Command | What must be visible in the image | Done |
|:--|:--|:--|:--:|
| S4-18 | `sudo dmesg \| grep -E "miniramfs:" \| tail` | `mounted`, `unmounted (live files=0, live bytes=0)`, `module unloaded (live files=0, live bytes=0)` | [ ] |
| S4-19 | `sudo dmesg \| grep -ciE "oops\|bug:\|call trace"` | the output is `0` | [ ] |
| S4-20 | `cat docs/screenshots/logs/leak_test.log` (bottom part) | the Slab / inode_cache / dentry / kmalloc-16 rows with small deltas, below the threshold (+900) | [ ] |

---

### S4 results summary (2026-11-25, kernel 6.8.12-fuse2005)

| Item | Result | Log |
|:--|:--|:--|
| TC-01 … TC-07 + EDGE-1 … EDGE-10 | 36/36 PASS | `tests/test_result.log` |
| Memory leak, 50 rounds × 300 files | PASS: live files=0, live bytes=0; slab deltas are noise (did not grow at 100 rounds) | `logs/leak_test.log`, `logs/leak_test_100rounds.log` |
| kmemleak | not available (`CONFIG_DEBUG_KMEMLEAK` off): used slabinfo + counters in the module instead | `logs/leak_test.log` |
| Oops / BUG / WARNING | 0 for the whole session | `logs/dmesg_session_all.log`, `logs/dmesg_test.log` |
| demo.sh | 10 steps, all 7 operations, ≈ 2 min (`DELAY=6`) | `logs/demo_output.log`, `logs/dmesg_demo.log` |
