# สถาปัตยกรรม miniramfs (แผนผังฟังก์ชันและ struct)

เอกสารส่งต่อจากฟิวส์ (Core & Kernel) ให้พิ้ง (รายงานบทที่ 3) และเจแปน (QA)
ทุกชื่ออ้างอิงจาก `src/miniramfs.c` (kernel 6.8.12-fuse2005) ต้นแบบคือ `fs/ramfs/inode.c` ของ Linux

## 1. ภาพรวมชั้นการทำงาน

```
 user space   mount / mkdir / echo > / cat / ls / umount
      |                     system call
 -----v---------------------------------------------------------------
 VFS          ค้นหา path -> dentry -> inode แล้วเรียก operations ที่ fs ลงทะเบียนไว้
      |
 miniramfs    file_system_type ─ super_operations ─ inode_operations ─ file_operations
      |
 kernel RAM   inode, dentry (dcache) + buffer ข้อมูลไฟล์ (kmalloc/krealloc)
```

ไม่มีดิสก์จริง ทุกอย่างอยู่ใน RAM และหายไปทั้งหมดเมื่อ `umount`

## 2. Struct หลัก

| Struct | ของใคร | miniramfs ใช้ทำอะไร |
| :-- | :-- | :-- |
| `struct file_system_type miniramfs_fs_type` | kernel | ลงทะเบียนชื่อ `"miniramfs"` พร้อม `.mount = miniramfs_mount`, `.kill_sb = miniramfs_kill_sb` |
| `struct super_block` | kernel | หนึ่งตัวต่อการ mount; ตั้ง `s_magic = 0x4D52464C` ("MRFL"), `s_maxbytes = 1 MiB`, `s_op = &miniramfs_sops`, `s_root` |
| `struct inode` | kernel | หนึ่งตัวต่อไฟล์/โฟลเดอร์; `i_op`, `i_fop`, `i_size` และ `i_private` ชี้ไปที่ buffer ข้อมูล |
| `struct dentry` | kernel | ผูกชื่อไฟล์กับ inode; ถูก `dget()` ค้างไว้ไม่ให้หายจาก cache ตอน mount อยู่ |
| `struct file` | kernel | ไฟล์ที่ถูก open; มี `f_flags` (เช่น `O_APPEND`) และ offset `*ppos` |
| **`struct miniramfs_file_data`** | **เราเขียนเอง** | `char *data` (เนื้อหาไฟล์) + `size_t capacity` (ขนาดที่จองไว้) เก็บใน `inode->i_private` |

ค่าคงที่: `MINIRAMFS_MAX_FILE = 1 MiB` ต่อไฟล์, `MINIRAMFS_MIN_ALLOC = 64` byte

ความสัมพันธ์:

```
super_block ──s_root──> dentry "/" ──> inode (S_IFDIR, i_op = dir_iops, i_fop = simple_dir_operations)
                                         │
                         dentry "file.txt" ──> inode (S_IFREG, i_op = file_iops, i_fop = file_fops)
                                                  │ i_private
                                                  v
                                       miniramfs_file_data { data ──> [h e l l o ...], capacity }
```

## 3. ตาราง operations ที่ลงทะเบียน

| ตาราง | ฟิลด์ | ฟังก์ชัน | ทำงานเมื่อ |
| :-- | :-- | :-- | :-- |
| `miniramfs_fs_type` | `.mount` | `miniramfs_mount` → `mount_nodev(..., miniramfs_fill_super)` | `mount -t miniramfs` |
| | `.kill_sb` | `miniramfs_kill_sb` → `kill_litter_super` | `umount` |
| `miniramfs_sops` | `.statfs` | `simple_statfs` | `df` |
| | `.drop_inode` | `generic_delete_inode` | ไม่มีใครอ้างอิง inode แล้ว |
| | `.evict_inode` | `miniramfs_evict_inode` | inode ถูกทำลาย → `kfree` buffer |
| `miniramfs_dir_iops` | `.create` | `miniramfs_create` | `touch`, `echo > ใหม่` |
| | `.mkdir` | `miniramfs_mkdir` | `mkdir` |
| | `.lookup` | `simple_lookup` | เข้าถึง path |
| | `.unlink` / `.rmdir` / `.link` / `.rename` | `simple_*` | `rm`, `rmdir`, `ln`, `mv` (โบนัส) |
| `miniramfs_file_iops` | `.setattr` | `miniramfs_setattr` | `echo > เดิม` (O_TRUNC), `truncate` |
| | `.getattr` | `simple_getattr` | `stat`, `ls -l` |
| `miniramfs_file_fops` | `.read` | `miniramfs_read` | `cat` |
| | `.write` | `miniramfs_write` | `echo >`, `>>` |
| | `.open` / `.llseek` | `generic_file_open` / `generic_file_llseek` | open, seek |
| `simple_dir_operations` (ของ kernel) | `.iterate_shared` | `dcache_readdir` | `ls` (ให้ `.` `..` อัตโนมัติ) |

## 4. ลำดับการเรียกฟังก์ชันของ 7 operations

**1. Mount**
```
insmod  -> miniramfs_init -> register_filesystem
mount   -> miniramfs_mount -> mount_nodev -> miniramfs_fill_super
             -> ตั้งค่า super_block
             -> miniramfs_get_inode(S_IFDIR|0755)   (root inode)
             -> d_make_root                          (root dentry "/")
```

**2. Unmount**
```
umount  -> miniramfs_kill_sb -> kill_litter_super
             -> ปล่อย dentry ที่ dget() ค้างไว้ทั้งหมด
             -> inode ทุกตัว -> miniramfs_evict_inode -> kfree(data), kfree(fd)
rmmod   -> miniramfs_exit -> unregister_filesystem
```

**3. Create file** (`touch a.txt`)
```
miniramfs_create -> miniramfs_mknod(mode|S_IFREG)
  -> miniramfs_get_inode: new_inode, get_next_ino, inode_init_owner, simple_inode_init_ts
                          kzalloc(miniramfs_file_data) -> i_private
  -> d_instantiate(dentry, inode); dget(dentry)
```

**4. Write file** (`echo hi > a.txt`, `>> a.txt`)
```
(ถ้า O_TRUNC) miniramfs_setattr -> miniramfs_resize(0)
miniramfs_write
  -> inode_lock
  -> pos = O_APPEND ? i_size : *ppos ; เช็กไม่เกิน 1 MiB (-EFBIG)
  -> miniramfs_reserve(pos+len): krealloc ขยายแบบเท่าตัว (64 -> 128 -> ...) + memset 0 ส่วนใหม่
  -> copy_from_user(data+pos, buf, len)
  -> อัปเดต *ppos, i_size, mtime/ctime
  -> inode_unlock
```

**5. Read file** (`cat a.txt`)
```
miniramfs_read
  -> inode_lock_shared
  -> pos >= i_size ? return 0 (EOF)
  -> len = min(len, i_size - pos)
  -> copy_to_user(buf, data+pos, len); *ppos += len
  -> inode_unlock_shared
```

**6. Create directory** (`mkdir d`)
```
miniramfs_mkdir -> miniramfs_mknod(mode|S_IFDIR)  (i_op = dir_iops, i_fop = simple_dir_operations, nlink "." )
                -> inc_nlink(dir)                 (".." ของโฟลเดอร์ใหม่ชี้กลับ parent)
```

**7. List directory** (`ls -la`)
```
simple_dir_operations.iterate_shared = dcache_readdir
  -> ส่ง "." และ ".." แล้ววนรายการ dentry ลูกใน dcache (ไฟล์ทุกตัวอยู่ใน dcache เพราะถูก dget ค้างไว้)
```

## 5. การตัดสินใจออกแบบ (สำหรับอธิบายในรายงาน/คลิป)

| ประเด็น | วิธีที่ใช้ | เหตุผล |
| :-- | :-- | :-- |
| เก็บข้อมูลไฟล์ | buffer ต่อเนื่องเดียวต่อไฟล์ (`kmalloc`/`krealloc`) | เข้าใจง่าย อธิบายเรื่อง offset ได้ตรงๆ; ramfs จริงใช้ page cache แทน |
| ขยาย buffer | เพิ่มเป็นสองเท่า เริ่ม 64 byte | ลดจำนวนครั้งที่ต้อง realloc (amortized O(1)) |
| จำกัดขนาด | 1 MiB ต่อไฟล์ → `-EFBIG` | `kmalloc` จองหน่วยความจำต่อเนื่องก้อนใหญ่ไม่ได้ |
| ไบต์หลัง `i_size` | บังคับเป็น 0 เสมอ (`memset`) | เขียนข้าม offset หรือ truncate แล้วขยาย จะไม่เห็นข้อมูลเก่าค้าง |
| ไฟล์ไม่หายตอน mount อยู่ | `dget()` ค้าง dentry | ไม่มีดิสก์ให้โหลดกลับ ถ้า dentry ถูกทิ้งไฟล์จะหาย (แบบเดียวกับ ramfs) |
| คืนหน่วยความจำ | `evict_inode` + `kill_litter_super` | ไม่ leak ตอน `rm` และตอน `umount` |
| ความปลอดภัยของ pointer | `copy_to_user` / `copy_from_user` เท่านั้น | ห้ามแตะ pointer ของ user space ตรงๆ ใน kernel |
| การทำงานพร้อมกัน | `inode_lock` (write) / `inode_lock_shared` (read) | กัน race ระหว่างหลาย process ที่เขียนไฟล์เดียวกัน |

## 6. ข้อจำกัด (สำหรับบทสรุป)

- ข้อมูลหายเมื่อ umount/รีบูต (เป็นธรรมชาติของ RAM filesystem)
- ไฟล์ใหญ่สุด 1 MiB, ไม่จำกัดจำนวนไฟล์รวม (`df` แสดง 0 เพราะ `simple_statfs` ไม่นับพื้นที่)
- ไม่รองรับ `mmap`, symlink, device file (ไม่ได้ลงทะเบียน `.symlink`/`.mknod` จึงได้ error `Operation not permitted`)
- ใช้ API `.mount`/`mount_nodev` แบบเก่า ใช้ได้บน 6.8 แต่ kernel รุ่นใหม่ต้องย้ายไปใช้ `fs_context` (`init_fs_context`)
