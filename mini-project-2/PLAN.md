# แผนการดำเนินงาน Mini-Project 2: Mini RAM-Based File System

**รายวิชา:** CPE333 Operating Systems
**หัวข้อ:** I/O and File System (Linux VFS RAM-Based Filesystem)
**สมาชิกในทีม (6 คน):** เจแปน, อุ๋งอิ๋ง, ผึ้ง, พอช, พิ้ง, ฟิวส์

---

## 1. ภาพรวมเป้าหมายและข้อกำหนด (Project Requirements)

* **เป้าหมายหลัก:** สร้างและ Re-build Kernel Files / Kernel Module เพื่อจำลองระบบไฟล์บน RAM ผ่าน Linux Virtual File System (VFS)
* **ฟีเจอร์ขั้นต่ำที่ต้องรองรับ (7 Operations):**
  1. `Mount`: เชื่อมต่อระบบไฟล์เข้ากับ Directory เป้าหมาย (`mount -t <fs_name> none /mnt/...`)
  2. `Unmount`: ยกเลิกการเชื่อมต่อระบบไฟล์ (`umount /mnt/...`)
  3. `Create file`: สร้างไฟล์ใหม่ภายในระบบไฟล์ (เช่น `touch`, `echo >`)
  4. `Read file`: อ่านข้อมูลจากไฟล์ (เช่น `cat`)
  5. `Write file`: เขียนข้อมูลลงในไฟล์ (จัดการ Offset และขนาดข้อมูลบน RAM)
  6. `Create directory`: สร้างโฟลเดอร์ย่อย (เช่น `mkdir`)
  7. `List directory contents`: แสดงรายการไฟล์และโฟลเดอร์ภายใน (เช่น `ls -la`)
* **สิ่งที่ต้องส่งมอบ (Deliverables):**
  1. **Source Code & Demo:** โค้ดทำงานได้จริงโดยไม่เกิด Kernel Panic พร้อมสคริปต์ทดสอบ
  2. **Presentation Video:** ความยาว **7–11 นาที** (อธิบายแนวคิด VFS + Re-build Kernel + สถาปัตยกรรม + Demo + ผลทดสอบ)
  3. **Report:** ความยาว **ไม่เกิน 25 หน้า** (ไม่รวมภาคผนวก / Appendix)

---

## 2. การแบ่งหน้าที่ในทีมและจุดส่งต่อข้อมูล (Role & Handoff)

แบ่งหน้าที่ความรับผิดชอบหลักและบทบาทในคลิปนำเสนอ (อัปเดตสลับหน้าที่ระหว่าง **เจแปน** และ **ฟิวส์** เรียบร้อยแล้ว):

| สมาชิก | หน้าที่หลัก (Main Role) | ขอบเขตงานที่รับผิดชอบ | บทบาทในคลิปนำเสนอ (7–11 นาที) |
| :--- | :--- | :--- | :--- |
| **ฟิวส์** | **Core & Kernel** *(สลับมาจากเจแปน)* | พัฒนาโค้ดหลักฝั่ง Kernel (`Makefile`, `super_block`, `inode`, `dentry`, `file_operations`), จัดการ Memory ใน RAM และแก้บั๊ก Kernel | **พูดช่วง Demo / อธิบายโค้ด:** อธิบายการทำงานของโค้ดส่วนสำคัญ และโชว์การรัน Demo ระบบจริง |
| **อุ๋งอิ๋ง** | **Test & Demo** | เตรียม VM/สภาพแวดล้อมทดสอบ, เขียน Shell Script ทดสอบทั้ง 7 ฟีเจอร์และ Edge Cases, เก็บ Log (`dmesg`) และ Screenshots | **พูดช่วง Test เทียบผลลัพธ์:** นำเสนอผลการรัน Test Cases และเปรียบเทียบผลลัพธ์ที่ได้ |
| **ผึ้ง** | **Video & Slide** | ออกแบบ Slide นำเสนอหลัก, รวบรวมคลิปจากสมาชิกทุกคนมาตัดต่อให้กระชับและคุมเวลาให้อยู่ในช่วง 7–11 นาที | **พูดสรุปภาพรวม ข้อจำกัด และปิดท้าย:** สรุปผลสำเร็จ ข้อจำกัดของระบบ และกล่าวปิดการนำเสนอ |
| **พอช** | **Report 1** | เขียนรายงานบทที่ 1 (บทนำ/วัตถุประสงค์), บทที่ 2 (ทฤษฎี VFS และโครงสร้างข้อมูล) และจัดรูปเล่มภาพรวม | **พูดช่วง Intro + เกริ่นคร่าว ๆ:** เปิดคลิป แนะนำหัวข้อ ปัญหา และเป้าหมายของ Mini-Project 2 |
| **พิ้ง** | **Report 2** | เขียนรายงานบทที่ 3 (ขั้นตอน Re-build Kernel, สถาปัตยกรรมระบบ), บทที่ 4–5 และรวบรวม Appendix (คุมไม่เกิน 25 หน้า) | **พูดอธิบายการ Re-build Kernel และโครงสร้างการทำงาน:** อธิบายขั้นตอนการเตรียม/Build Kernel และ Architecture ของ VFS |
| **เจแปน** | **QA & Slide** *(สลับมาจากฟิวส์)* | ตรวจสอบความถูกต้องทางเทคนิคของ Slide และบทพูด, ตรวจเช็กความสอดคล้องระหว่างทฤษฎีกับโค้ด/ผลทดสอบจริง | **พูดช่วงเชื่อมโยงทฤษฎีเข้ากับการทดลองและตัวอย่างการใช้งาน:** เชื่อมหลักการของ VFS/RAMFS เข้ากับผลรันและ Use Case จริง |

### จุดส่งต่อข้อมูลระหว่างทีม (Handoff Checklist)
* **ฟิวส์ (Core & Kernel) $\rightarrow$ ส่งให้ อุ๋งอิ๋ง, พิ้ง, เจแปน:**
  * โค้ด `miniramfs.c` และ `Makefile` ที่คอมไพล์ผ่านแล้ว พร้อมขั้นตอนการ Build
  * แผนผังฟังก์ชันและ Struct หลักที่ใช้ (เพื่อให้ **พิ้ง** เขียนบทที่ 3 และ **เจแปน** ตรวจความถูกต้อง)
* **อุ๋งอิ๋ง (Test & Demo) $\rightarrow$ ส่งให้ พิ้ง, เจแปน, ผึ้ง:**
  * ตารางผลทดสอบ (Pass/Fail) และ Screenshots ตอนรันคำสั่งสำเร็จ (ให้ **พิ้ง** ใส่บทที่ 4 และ **ผึ้ง** ใส่สไลด์)
* **เจแปน (QA & Slide) $\rightarrow$ ส่งให้ ผึ้ง และทุกคน:**
  * ตรวจสอบสคริปต์พูดและสไลด์ของทุกคนก่อนอัดคลิปจริง เพื่อให้เนื้อหาเชื่อมโยงกันไม่ซ้ำซ้อน

---

## 3. แผนพัฒนาโค้ดแบบเป็นขั้นตอน (Development Milestones — รับผิดชอบหลัก: ฟิวส์ & อุ๋งอิ๋ง)

### Phase 1: เตรียมเครื่องและศึกษาต้นแบบ
* [ ] ติดตั้งแพ็กเกจที่จำเป็น (`build-essential`, `linux-headers-$(uname -r)`, `gcc`, `make`)
* [ ] ศึกษาโครงสร้าง VFS จากเอกสารทางการ (`docs.kernel.org/filesystems/vfs.html`)
* [ ] ศึกษาโค้ดต้นแบบ `fs/ramfs/inode.c` ของ Linux Kernel เพื่อดูวิธีผูก `inode_operations` และ `file_operations`
* [ ] วางโครงสร้างไฟล์ `Makefile`, `miniramfs.h`, `miniramfs.c`

### Phase 2: Milestone 1 — Mount & Unmount
* [ ] เขียน `module_init` และ `module_exit` ให้ `insmod` / `rmmod` (หรือ Build เข้า Kernel) ผ่าน
* [ ] สร้าง `struct file_system_type` (กำหนด `.name = "miniramfs"`, `.mount`, `.kill_sb = kill_litter_super`)
* [ ] เขียนฟังก์ชัน `fill_super` เพื่อสร้าง Root Inode (`/`) และ Root Dentry (`d_make_root`)
* [ ] **เกณฑ์ผ่าน:** สามารถรัน `mount -t miniramfs none /mnt/test` ตรวจสอบด้วย `mount` หรือ `df -T` แล้วเห็นชื่อ filesystem และ `umount` ออกได้สะอาด

### Phase 3: Milestone 2 — Directory Operations (`mkdir` & `ls`)
* [ ] Implement ฟังก์ชัน `.mkdir` ใน `dir_inode_operations` เพื่อสร้าง Inode ชนิด Directory (`S_IFDIR | mode`) และผูกกับ `dentry` (`d_instantiate`)
* [ ] Implement ฟังก์ชันแสดงรายการไฟล์ใน `dir_file_operations` (ใช้ `.iterate_shared = simple_readdir` หรือวนอ่าน `dentry`)
* [ ] **เกณฑ์ผ่าน:** เข้าไปใน `/mnt/test` แล้วรัน `mkdir dir1 dir2` และ `ls -la` เห็นโฟลเดอร์และ `.` `..` ครบถ้วน

### Phase 4: Milestone 3 — File Operations (`create`, `write`, `read`)
* [ ] Implement ฟังก์ชัน `.create` ใน `dir_inode_operations` เพื่อสร้างไฟล์เปล่า (`S_IFREG | mode`)
* [ ] ออกแบบโครงสร้างเก็บข้อมูลใน RAM (สร้าง `struct miniramfs_file_data` เก็บ `char *data` และ `size_t capacity` ผูกไว้กับ `inode->i_private`)
* [ ] Implement `.write`: รับข้อมูลจาก User space ด้วย `copy_from_user`, ขยาย buffer ด้วย `krealloc` หากข้อมูลเกินขนาดเดิม, อัปเดตตำแหน่ง `*ppos` และขนาดไฟล์ `inode->i_size`
* [ ] Implement `.read`: ตรวจสอบขอบเขต `*ppos` เทียบกับ `inode->i_size` แล้วคัดลอกข้อมูลจาก Kernel space ไป User space ด้วย `copy_to_user`
* [ ] **เกณฑ์ผ่าน:** รัน `echo "hello os" > file.txt` และ `cat file.txt` ได้ผลลัพธ์ตรงตามที่เขียน

### Phase 5: Integration, Memory Cleanup & Edge Cases
* [ ] คืนหน่วยความจำที่จองไว้ใน `i_private` (`kfree`) ผ่านฟังก์ชัน `.evict_inode` ใน `super_operations` เพื่อป้องกัน Memory Leak ตอน `umount`
* [ ] ทดสอบ Edge Cases: เขียนต่อท้าย (`>>`), เขียนทับ (`>`), อ่านไฟล์ว่าง, สร้างไฟล์ในโฟลเดอร์ย่อยหลายชั้น

---

## 4. คู่มือเทคนิคและข้อควรระวัง (Technical Cheat Sheet)

| VFS Object | หน้าที่หลักในระบบไฟล์ | Struct / Operation สำคัญที่ต้องใช้ |
| :--- | :--- | :--- |
| **`super_block`** | เก็บข้อมูลภาพรวมของระบบไฟล์ที่ถูก Mount 1 ครั้ง | `struct super_operations` (เช่น `.statfs`, `.evict_inode`), `fill_super()` |
| **`inode`** | เก็บ Metadata ของไฟล์/โฟลเดอร์ (สิทธิ์, ขนาด, เวลา, Pointer ข้อมูล) | `struct inode_operations` (`.create`, `.lookup`, `.mkdir`), `new_inode()` |
| **`dentry`** | เชื่อม "ชื่อไฟล์" เข้ากับ `inode` และสร้างโครงสร้างต้นไม้โฟลเดอร์ | `d_make_root()`, `d_instantiate()`, `d_add()` |
| **`file`** | เก็บสถานะตอนไฟล์ถูกเปิดใช้งานจริง (เช่น File Offset `*ppos`) | `struct file_operations` (`.read`, `.write`, `.open`, `.iterate_shared`) |

**ข้อควรระวังสำคัญสำหรับ Kernel Programming:**
1. **ห้ามเข้าถึง Pointer ของ User Space โดยตรง:** ในฟังก์ชัน `read` และ `write` ต้องใช้ `copy_to_user()` และ `copy_from_user()` เท่านั้น มิฉะนั้นจะเกิด Kernel Oops / Panic
2. **การเปลี่ยนผ่านของ Kernel API:** Kernel เวอร์ชันใหม่ ๆ (เช่น 5.x - 6.x) มีการเปลี่ยน Signature ของฟังก์ชันใน `inode_operations` (เช่น เพิ่มพารามิเตอร์ `struct mnt_idmap *idmap` หรือ `struct user_namespace *mnt_userns`) ให้เช็กจาก Header ของเครื่องที่ใช้คอมไพล์เป็นหลัก (`/usr/src/linux-headers-$(uname -r)/include/linux/fs.h`)
3. **การคืนหน่วยความจำ:** ทุกครั้งที่ `kmalloc`/`krealloc` ข้อมูลไฟล์ใน RAM ต้องมั่นใจว่ามีการ `kfree` เมื่อลบไฟล์หรือตอน Unmount

---

## 5. แผนการทดสอบระบบ (Test Plan — รับผิดชอบหลัก: อุ๋งอิ๋ง)

| Test ID | หัวข้อการทดสอบ | คำสั่งที่ใช้ทดสอบ (Shell Command) | ผลลัพธ์ที่คาดหวัง (Expected Result) |
| :--- | :--- | :--- | :--- |
| **TC-01** | โหลดโมดูลและ Mount | `insmod miniramfs.ko && mount -t miniramfs none /mnt/test` | Mount สำเร็จ ตรวจสอบด้วย `mount` พบ `miniramfs` |
| **TC-02** | สร้าง Directory | `mkdir /mnt/test/docs /mnt/test/docs/sub` | สร้างโฟลเดอร์หลักและโฟลเดอร์ซ้อนได้โดยไม่ Error |
| **TC-03** | แสดงรายการไฟล์ | `ls -la /mnt/test` | แสดงรายการ `.` `..` และโฟลเดอร์ `docs` ถูกต้อง |
| **TC-04** | สร้างไฟล์และเขียนข้อมูล | `echo "CPE333 OS" > /mnt/test/docs/note.txt` | สร้างไฟล์และบันทึกข้อความลง RAM สำเร็จ |
| **TC-05** | อ่านข้อมูลจากไฟล์ | `cat /mnt/test/docs/note.txt` | แสดงข้อความ `CPE333 OS` ตรงตามที่เขียน |
| **TC-06** | เขียนต่อท้ายและเขียนทับ | `echo "Line 2" >> note.txt` และทดสอบเขียนทับด้วย `>` | ขนาดไฟล์ (`ls -l`) อัปเดตถูกต้อง ข้อมูลไม่เพี้ยน |
| **TC-07** | Unmount และถอดโมดูล | `umount /mnt/test && rmmod miniramfs` | Unmount สำเร็จ ไม่เกิด Memory Leak หรือ Kernel Panic |

---

## 6. โครงสร้างรายงาน (Report Outline — ไม่เกิน 25 หน้า)

แบ่งความรับผิดชอบระหว่าง **พอช (Report 1)** และ **พิ้ง (Report 2)** โดยคุมความยาวรวมให้อยู่ในช่วง **20–24 หน้า** (ไม่รวม Appendix):

1. **บทที่ 1 บทนำ (2–3 หน้า) — [พอช]:** ที่มาและความสำคัญของ File System, วัตถุประสงค์ และขอบเขตของ Mini RAM-Based File System
2. **บทที่ 2 ทฤษฎีที่เกี่ยวข้อง (4–5 หน้า) — [พอช]:**
   * สถาปัตยกรรมของ **Linux Virtual File System (VFS)** และการทำงานของ System Call
   * อธิบาย 4 โครงสร้างหลักของ VFS: `super_block`, `inode`, `dentry`, `file`
   * แนวคิดของ `ramfs` และการจัดการหน่วยความจำ Kernel Space vs User Space
3. **บทที่ 3 การออกแบบและพัฒนาระบบ (6–8 หน้า) — [พิ้ง]:**
   * ขั้นตอนการเตรียมสภาพแวดล้อมและ Re-build Kernel / Kernel Module
   * แผนภาพการทำงาน (Architecture Diagram / Flowchart) ของแต่ละ Operation ทั้ง 7 ตัว
   * อธิบายโครงสร้างข้อมูลและการจัดการ RAM ในโค้ด พร้อม Code Snippet ส่วนสำคัญ (โค้ดเต็มไว้ใน Appendix)
4. **บทที่ 4 การทดสอบและผลลัพธ์ (4–5 หน้า) — [พิ้ง + ข้อมูลจากอุ๋งอิ๋ง]:**
   * ตาราง Test Cases ทั้ง 7 ข้อ (จากหัวข้อที่ 5) พร้อมสถานะ Pass/Fail และเปรียบเทียบผลลัพธ์
   * ภาพหน้าจอการรันคำสั่งจริงใน Terminal และข้อความจาก `dmesg`
5. **บทที่ 5 สรุปผล ปัญหาที่พบ และแนวทางพัฒนาต่อ (2–3 หน้า) — [พิ้ง + พอช]:**
   * สรุปสิ่งที่ได้เรียนรู้, ปัญหาที่เจอระหว่างทำ (เช่น Kernel Panic, Header Version) และข้อจำกัดของระบบ
6. **ภาคผนวก (Appendix - ไม่นับรวมใน 25 หน้า) — [พิ้ง]:** Source Code ฉบับเต็ม (`miniramfs.c`, `Makefile`, `test_miniramfs.sh`)

---

## 7. ลำดับการพูดในคลิปและแบ่งเวลา (Video Script Timeline — เป้าหมาย 9.5 นาที)

ตั้งเป้าความยาวรวมไว้ที่ **9–10 นาที** เพื่อให้อยู่กึ่งกลางเกณฑ์ **7–11 นาที** อย่างปลอดภัย (รวบรวมและตัดต่อโดย **ผึ้ง**):

1. **[0:00 - 1:15] ช่วงที่ 1: Intro & เกริ่นนำ (1 นาที 15 วินาที) — พูดโดย: พอช**
   * แนะนำสมาชิก หัวข้อโปรเจกต์ (I/O and File System) เป้าหมายของ Mini RAM-Based File System และฟีเจอร์หลักทั้ง 7 ข้อ
2. **[1:15 - 3:00] ช่วงที่ 2: การ Re-build Kernel และโครงสร้างการทำงาน (1 นาที 45 วินาที) — พูดโดย: พิ้ง**
   * อธิบายขั้นตอนการ Re-build / Compile Kernel และโครงสร้างสถาปัตยกรรม Linux VFS (`super_block`, `inode`, `dentry`, `file`) ที่ออกแบบไว้
3. **[3:00 - 5:15] ช่วงที่ 3: Demo ระบบจริง & อธิบายโค้ด (2 นาที 15 วินาที) — พูดโดย: ฟิวส์** *(สลับกับเจแปน)*
   * เปิดโค้ดอธิบายจุดสำคัญ (เช่น การผูก VFS Operations, `copy_from_user`/`copy_to_user`) พร้อมโชว์การรัน Demo สดตั้งแต่ `mount`, `mkdir`, เขียน/อ่านไฟล์ จนถึง `umount`
4. **[5:15 - 7:00] ช่วงที่ 4: การทดสอบและเปรียบเทียบผลลัพธ์ (1 นาที 45 วินาที) — พูดโดย: อุ๋งอิ๋ง**
   * พาไล่ดูผลการทดสอบตาม Test Cases (TC-01 ถึง TC-07) เปรียบเทียบผลลัพธ์ที่คาดหวังกับผลจริงบน Terminal และ `dmesg`
5. **[7:00 - 8:30] ช่วงที่ 5: เชื่อมโยงทฤษฎีเข้ากับการทดลองและตัวอย่างการใช้งาน (1 นาที 30 วินาที) — พูดโดย: เจแปน** *(สลับกับฟิวส์)*
   * วิเคราะห์เชื่อมโยงว่าสิ่งที่เกิดขึ้นตอนรันจริงสะท้อนหลักการของ VFS และ RAM-based storage อย่างไร พร้อมยกตัวอย่าง Use Case การนำไปใช้งานจริง (เช่น Cache/Temp storage ความเร็วสูง)
6. **[8:30 - 9:30] ช่วงที่ 6: สรุปภาพรวม ข้อจำกัด และปิดท้าย (1 นาที) — พูดโดย: ผึ้ง**
   * สรุปภาพรวมความสำเร็จของโปรเจกต์ ข้อจำกัดของระบบไฟล์บน RAM (เช่น ข้อมูลหายเมื่อรีบูต/Unmount, จำกัดขนาดตาม RAM) และกล่าวปิดคลิป