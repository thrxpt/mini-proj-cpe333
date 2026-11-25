# คู่มือทดสอบ miniramfs และเก็บภาพสำหรับรายงาน

สำหรับทุกคนในทีมที่ต้องรันเทสเองและแคปหน้าจอใส่รายงาน/สไลด์
ตัวอย่างผลที่ถูกต้องดูได้ใน `docs/test_result.log`

## 0. เลือกเครื่องที่จะใช้

โมดูล kernel ต้อง build กับ **kernel ตัวที่กำลังรันอยู่** เท่านั้น (`.ko` ของคนอื่นใช้ข้ามเครื่องไม่ได้)

| ทางเลือก | ใช้ได้ไหม | หมายเหตุ |
| :-- | :-- | :-- |
| **A. เครื่องฟิวส์** (WSL2 + kernel `6.8.12-fuse2005`) | ได้ ทดสอบแล้ว | ง่ายสุด ใช้ตอนอัด Demo |
| **B. VM Ubuntu 24.04** (VirtualBox/VMware, kernel `6.8.0-xx-generic`) | น่าจะได้ ยังไม่ได้ทดสอบ | API ของ 6.8 ตรงกับโค้ด ต้องติดตั้ง headers (ข้อ 1) |
| C. WSL2 ปกติ (kernel `6.18.x-microsoft-standard-WSL2`) | **ไม่ได้** | headers ไม่ครบ (ไม่มี `Module.symvers`) และ kernel ใหม่กว่าที่โค้ดรองรับ |

> ห้ามทดสอบบนเครื่องจริงที่มีงานสำคัญ: บั๊กใน kernel module ทำให้เครื่องค้างได้ ใช้ WSL2 หรือ VM เท่านั้น

## 1. เตรียมเครื่อง (ครั้งแรกครั้งเดียว)

```bash
uname -r                 # A: 6.8.12-fuse2005   B: 6.8.0-xx-generic
sudo apt update
sudo apt install -y build-essential git
sudo apt install -y linux-headers-$(uname -r)     # เฉพาะทางเลือก B
ls /lib/modules/$(uname -r)/build/Module.symvers  # ต้องมีไฟล์นี้
```

เครื่องฟิวส์ (A): ถ้า `uname -r` ขึ้น `6.18...` แปลว่า WSL บูต kernel ผิดตัว
ให้เช็ก `C:\Users\ACER\.wslconfig` ว่ามีบรรทัด `kernel=C:\\Users\\ACER\\kernel-fuse2005` (ไม่มี `#` นำหน้า) แล้วสั่ง `wsl --shutdown` ใน PowerShell และเปิด WSL ใหม่

## 2. ดึงโค้ดและ build

**ต้อง build บน filesystem ของ Linux** (`~` หรือ `/tmp`) ไม่ใช่ `/mnt/c/...`
(ถ้า build บนไดรฟ์ Windows/OneDrive จะเจอ "clock skew" และ `Module.symvers` ว่าง)

```bash
cd ~
git clone https://github.com/thrxpt/mini-proj-cpe333.git
cd mini-proj-cpe333 && git switch mini-project-2
cd mini-project-2/src
make                      # ได้ miniramfs.ko, ต้องไม่มี error
modinfo miniramfs.ko | grep vermagic   # ต้องตรงกับ uname -r
```

## 3. รันเทสทีละขั้น (สำหรับแคปภาพ)

รันใน `mini-project-2/src` ทีละบล็อก แคปหลังจบแต่ละบล็อก (Windows: `Win+Shift+S`)

| ภาพ | คำสั่ง | สิ่งที่ต้องเห็นในภาพ |
| :-- | :-- | :-- |
| 01-env | `uname -r` · `gcc --version \| head -1` | เวอร์ชัน kernel และ gcc |
| 02-build | `make` · `modinfo miniramfs.ko \| grep -E 'description\|vermagic'` | `LD [M] ... miniramfs.ko`, vermagic ตรง kernel |
| 03-mount | `sudo insmod miniramfs.ko` · `lsmod \| grep miniramfs` · `sudo mkdir -p /mnt/test` · `sudo mount -t miniramfs none /mnt/test` · `mount \| grep miniramfs` · `df -T /mnt/test` · `sudo dmesg \| tail -2` | `none on /mnt/test type miniramfs`, dmesg `module loaded` / `mounted` |
| 04-mkdir-ls | `sudo mkdir /mnt/test/dir1 /mnt/test/dir2 /mnt/test/dir1/sub` · `ls -la /mnt/test` | `.` `..` `dir1` `dir2` |
| 05-file-ops | `echo 'hello os' \| sudo tee /mnt/test/file.txt` · `cat /mnt/test/file.txt` · `echo 'line 2' \| sudo tee -a /mnt/test/file.txt` · `cat /mnt/test/file.txt` · `sudo touch /mnt/test/empty` · `wc -c /mnt/test/empty` | อ่านได้ตรงกับที่เขียน, append ต่อท้าย, ไฟล์ว่าง = 0 byte |
| 06-umount-rmmod | `cd ~` · `sudo umount /mnt/test` · `sudo rmmod miniramfs` · `lsmod \| grep -c miniramfs` · `sudo dmesg \| tail -4` | `0`, dmesg `unmounted` / `module unloaded` |

หมายเหตุ: ใช้ `sudo tee` แทน `sudo echo ... >` เพราะ `>` ถูกทำโดย shell ของเรา (ไม่ใช่ root)

## 4. รันเทสอัตโนมัติ (TC-01..07 + Edge cases)

```bash
cd ~/mini-proj-cpe333/mini-project-2/src
sudo bash ../tests/test_miniramfs.sh      # ผลเก็บใน test_result.log
```

ต้องได้ `=== RESULT: 21 passed, 0 failed ===` แคปภาพนี้เป็น 07-test-suite
สคริปต์จะ insmod/mount เอง จึงต้อง **ไม่มี** miniramfs โหลดค้างก่อนรัน (`lsmod | grep miniramfs` ต้องว่าง)

## 5. ปัญหาที่เจอบ่อย

| อาการ | สาเหตุ | วิธีแก้ |
| :-- | :-- | :-- |
| `insmod: ERROR: ... Invalid module format` | build กับ kernel อื่น | เช็ก `uname -r` เทียบ `modinfo ... vermagic` แล้ว `make clean && make` ใหม่ |
| `make: *** /lib/modules/.../build: No such file or directory` | ไม่มี headers | `sudo apt install linux-headers-$(uname -r)` หรือ `make KDIR=<path ของ build tree>` |
| `umount: /mnt/test: target is busy` | มี shell อยู่ใน `/mnt/test` | `cd ~` ก่อน umount |
| `rmmod: ERROR: Module miniramfs is in use` | ยังไม่ได้ umount | `sudo umount /mnt/test` ก่อน |
| `mount: unknown filesystem type 'miniramfs'` | ยังไม่ได้ insmod | `sudo insmod miniramfs.ko` |
| `make` ขึ้น "clock skew detected" | build บน `/mnt/c` | ย้ายไป build ใน `~` |
| `sudo` ถามรหัสผ่าน | ปกติ | ใส่รหัสผ่าน Ubuntu ของตัวเอง |

## 6. คืนสภาพเครื่องหลังทดสอบ

```bash
cd ~; sudo umount /mnt/test 2>/dev/null; sudo rmmod miniramfs 2>/dev/null
lsmod | grep -c miniramfs     # ต้องได้ 0
```
