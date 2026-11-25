# CPE333 Operating Systems: Mini-Projects

Department of Computer Engineering, Faculty of Engineering, KMUTT

This repo holds both mini-projects of the course. Each one lives in its own folder, and each folder has a `README.md` with the details.

| Project | Topic | Folder | Status |
|:--|:--|:--|:--|
| **Mini-Project 1** | Ubuntu Kernel Compilation and Installation | [`mini-project-1/`](mini-project-1/) | Build + boot passed (`6.8.12-fuse2005`) |
| **Mini-Project 2** | Mini RAM-Based File System on Linux VFS | [`mini-project-2/`](mini-project-2/) | Code and tests passed (36/36, no leak); screenshots/report/video pending |

```
.
├── README.md                     ← this file
├── mini-project-1/
│   ├── README.md                 ← summary, build result, spec
│   ├── Kernel-Compilation-Worklog.md
│   └── images/                   ← screenshots by spec section
└── mini-project-2/
    ├── README.md                 ← build & test instructions
    ├── PLAN.md                   ← team roles, test plan, video script
    ├── src/                      ← miniramfs.c, Makefile
    ├── tests/                    ← test_miniramfs.sh, leak_test.sh, demo.sh
    └── docs/                     ← assignment, architecture, TESTING, screenshots/ + logs/
```

---

## Mini-Project 1: Ubuntu Kernel Compilation and Installation

Compile and install a Linux kernel on Ubuntu 24.04 LTS, check that it boots, and test rolling back to the old kernel. Done by **Fuse**.

| Environment | Build time | Kernel | Boot / Rollback |
|:--|:--|:--|:--|
| WSL2 Ubuntu 24.04, Ryzen 7 8840U, 16 vCPU / 15 GiB | ~27 min (`-j16`) | `6.8.12-fuse2005` | Passed |

- Worklog: [`mini-project-1/Kernel-Compilation-Worklog.md`](mini-project-1/Kernel-Compilation-Worklog.md)
- Screenshots: [`mini-project-1/images/`](mini-project-1/images/)
- Full spec + deliverables checklist: [`mini-project-1/README.md`](mini-project-1/README.md)

---

## Mini-Project 2: Mini RAM-Based File System (`miniramfs`)

A kernel module that registers a new file system with Linux VFS and keeps all data in RAM. It is built on top of the kernel from Mini-Project 1 (`6.8.12-fuse2005`).

**Supports all 7 operations:** mount, umount, create file, read, write, mkdir, list directory. It also supports unlink, rmdir, rename and truncate. The maximum file size is 1 MiB (writing past that returns `EFBIG`).

```bash
cd mini-project-2/src && make
cd .. && sudo bash tests/test_miniramfs.sh   # TC-01..TC-07 + EDGE-1..10
sudo bash tests/leak_test.sh                 # 50 rounds mount/umount, compares slabinfo
sudo bash tests/demo.sh                      # ~2 min demo for the video
```

| Test | Result |
|:--|:--|
| TC-01 … TC-07 + EDGE-1 … EDGE-10 | 36/36 PASS |
| Memory leak (50 rounds × 300 files) | PASS: `live files=0, live bytes=0`, no growth in slab |
| Kernel Oops / BUG / WARNING | 0 |

- Build/test details: [`mini-project-2/README.md`](mini-project-2/README.md)
- Screenshots each member needs to take: [`mini-project-2/docs/screenshots/CHECKLIST.md`](mini-project-2/docs/screenshots/CHECKLIST.md)

---

## Members

| Name | Student ID |
|------|------------|
| Kamonnat Seetakai | 67070501001 |
| Benyapha Rattanakhunodom | 67070501030 |
| Pawarisa Thongchua | 67070501032 |
| Chanya Poolketkij | 67070501058 |
| Theeraphat Jaingam | 67070501063 |
| Onsinee Chotchuangsakulchai | 67070501078 |
