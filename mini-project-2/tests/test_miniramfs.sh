#!/usr/bin/env bash
# Test script for miniramfs  (TC-01 .. TC-07 + edge cases)
# Run as root (from any directory) after `make` in src/:
#     sudo bash tests/test_miniramfs.sh
# Output : tests/test_result.log
# dmesg  : docs/screenshots/logs/dmesg_test.log

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
KO="${KO:-$ROOT/src/miniramfs.ko}"
MNT="${MNT:-/mnt/test}"
LOG="$HERE/test_result.log"
LOGDIR="$ROOT/docs/screenshots/logs"
PASS=0; FAIL=0
MAX=1048576                                   # MINIRAMFS_MAX_FILE (1 MiB)

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
mkdir -p "$LOGDIR"
exec > >(tee "$LOG") 2>&1

check() {  # check <TC-ID> <description> <command...>
  local id="$1" desc="$2"; shift 2
  if eval "$@" >/dev/null 2>&1; then
    echo "[PASS] $id  $desc"; PASS=$((PASS+1))
  else
    echo "[FAIL] $id  $desc   (cmd: $*)"; FAIL=$((FAIL+1))
  fi
}

echo "=== miniramfs test  $(date) | kernel $(uname -r) ==="
lsmod | grep -q '^miniramfs' && { umount "$MNT" 2>/dev/null; rmmod miniramfs; }
echo "miniramfs-test-start" > /dev/kmsg
mkdir -p "$MNT"

# TC-01 load module + mount
check TC-01 "insmod + mount"          "insmod $KO && mount -t miniramfs none $MNT"
check TC-01 "fs visible in mount"     "mount | grep -q 'on $MNT type miniramfs'"
check TC-01 "fs visible in /proc/filesystems" "grep -q miniramfs /proc/filesystems"

# TC-02 create directories
check TC-02 "mkdir docs + nested sub" "mkdir $MNT/docs $MNT/docs/sub"

# TC-03 list directory
check TC-03 "ls -la shows . .. docs"  "ls -la $MNT | grep -q ' docs\$' && ls -la $MNT | grep -q ' \.\.\$'"

# TC-04 create + write
check TC-04 "echo > file"             "echo 'CPE333 OS' > $MNT/docs/note.txt"
check TC-04 "touch empty file"        "touch $MNT/docs/empty.txt && test -f $MNT/docs/empty.txt"

# TC-05 read
check TC-05 "cat returns written text" "[ \"\$(cat $MNT/docs/note.txt)\" = 'CPE333 OS' ]"
check TC-05 "read empty file = 0 bytes" "[ \$(cat $MNT/docs/empty.txt | wc -c) -eq 0 ]"

# TC-06 append / overwrite
echo "Line 2" >> "$MNT/docs/note.txt"
check TC-06 "append (>>) size = 17"   "[ \$(stat -c %s $MNT/docs/note.txt) -eq 17 ]"
check TC-06 "append content"          "[ \"\$(sed -n 2p $MNT/docs/note.txt)\" = 'Line 2' ]"
echo "new" > "$MNT/docs/note.txt"
check TC-06 "overwrite (>) size = 4"  "[ \$(stat -c %s $MNT/docs/note.txt) -eq 4 ]"
check TC-06 "overwrite content"       "[ \"\$(cat $MNT/docs/note.txt)\" = 'new' ]"

# Edge cases
check EDGE-1 "deep nesting (5 levels)" "mkdir -p $MNT/a/b/c/d/e && echo deep > $MNT/a/b/c/d/e/f.txt && [ \"\$(cat $MNT/a/b/c/d/e/f.txt)\" = deep ]"
check EDGE-2 "large write 512 KiB"     "head -c 524288 /dev/urandom > /tmp/mrf_big && cp /tmp/mrf_big $MNT/big.bin && cmp /tmp/mrf_big $MNT/big.bin"
check EDGE-3 "file > 1 MiB rejected"   "! head -c 2097152 /dev/zero > $MNT/toobig.bin"
check EDGE-4 "unlink file"             "rm $MNT/docs/empty.txt && ! test -e $MNT/docs/empty.txt"
check EDGE-5 "rmdir empty dir"         "mkdir $MNT/tmpd && rmdir $MNT/tmpd"
check EDGE-6 "read missing file fails" "! cat $MNT/nope.txt"

# EDGE-7 unlink a file that is still open: name disappears, open fd still works
echo "still here" > "$MNT/open.txt"
exec 3>>"$MNT/open.txt"                       # keep it open (append mode)
rm "$MNT/open.txt"
check EDGE-7 "unlinked name gone"       "! test -e $MNT/open.txt"
check EDGE-7 "open fd still readable"   "[ \"\$(cat /proc/$$/fd/3)\" = 'still here' ]"
echo "more" >&3
check EDGE-7 "open fd still writable"   "[ \$(stat -L -c %s /proc/$$/fd/3) -eq 16 ]"
exec 3>&-                                     # last close -> evict_inode frees buffer

# EDGE-8 rmdir on non-empty dir must fail with ENOTEMPTY
check EDGE-8 "rmdir non-empty fails"    "! rmdir $MNT/docs"
check EDGE-8 "error is ENOTEMPTY"       "rmdir $MNT/docs 2>&1 | grep -q 'not empty'"
check EDGE-8 "dir + contents intact"    "test -d $MNT/docs/sub && [ \"\$(cat $MNT/docs/note.txt)\" = new ]"

# EDGE-9 write past 1 MiB limit -> EFBIG, no panic
ERR=$(head -c 2097152 /dev/zero 2>&1 > "$MNT/max.bin")
check EDGE-9 "write 2 MiB -> 'File too large' (EFBIG)" "echo '$ERR' | grep -q 'File too large'"
check EDGE-9 "file capped at exactly 1 MiB"            "[ \$(stat -c %s $MNT/max.bin) -eq $MAX ]"
check EDGE-9 "write at offset 1 MiB -> EFBIG"          "dd if=/dev/zero of=$MNT/max.bin bs=1 count=1 seek=$MAX conv=notrunc 2>&1 | grep -q 'File too large'"
check EDGE-9 "fs still usable after EFBIG"             "echo ok > $MNT/after.txt && [ \"\$(cat $MNT/after.txt)\" = ok ]"
rm -f "$MNT/max.bin" "$MNT/toobig.bin"

# EDGE-10 two processes writing concurrently
LA=$(printf 'A%.0s' $(seq 1 63)); LB=$(printf 'B%.0s' $(seq 1 63))
head -c 600000 /dev/urandom > /tmp/mrf_p1; head -c 600000 /dev/urandom > /tmp/mrf_p2
( for i in $(seq 1 2000); do echo "$LA"; done >> "$MNT/shared.txt" ) & P1=$!
( for i in $(seq 1 2000); do echo "$LB"; done >> "$MNT/shared.txt" ) & P2=$!
cp /tmp/mrf_p1 "$MNT/p1.bin" & P3=$!
cp /tmp/mrf_p2 "$MNT/p2.bin" & P4=$!
wait $P1 $P2 $P3 $P4        # not bare `wait`: that would also wait for the tee logger
check EDGE-10 "O_APPEND same file: size = 4000 x 64"  "[ \$(stat -c %s $MNT/shared.txt) -eq 256000 ]"
check EDGE-10 "2000 A-lines + 2000 B-lines, none torn" "[ \$(grep -cx '$LA' $MNT/shared.txt) -eq 2000 ] && [ \$(grep -cx '$LB' $MNT/shared.txt) -eq 2000 ]"
check EDGE-10 "parallel writes to 2 files intact"     "cmp /tmp/mrf_p1 $MNT/p1.bin && cmp /tmp/mrf_p2 $MNT/p2.bin"

echo "--- tree ---"; ls -laR "$MNT" | grep -v '^$' | head -60

# TC-07 unmount + remove module
check TC-07 "umount && rmmod"          "umount $MNT && rmmod miniramfs"
check TC-07 "module gone"              "! lsmod | grep -q '^miniramfs'"
check TC-07 "all buffers freed (live files=0, live bytes=0)" "dmesg | grep 'miniramfs: module unloaded' | tail -1 | grep -q 'live files=0, live bytes=0'"
dmesg | tac | sed '/miniramfs-test-start/q' | tac > "$LOGDIR/dmesg_test.log"
check TC-07 "no Oops/BUG/WARNING in dmesg" "! grep -qE 'Oops|BUG:|WARNING:|Call Trace|general protection' $LOGDIR/dmesg_test.log"

echo "--- dmesg (since test start) ---"
cat "$LOGDIR/dmesg_test.log"
rm -f /tmp/mrf_big /tmp/mrf_p1 /tmp/mrf_p2

echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
