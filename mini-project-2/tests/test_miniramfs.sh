#!/usr/bin/env bash
# Test script for miniramfs  (TC-01 .. TC-07 + edge cases)
# Run as root from the src/ directory after `make`:
#     sudo bash ../tests/test_miniramfs.sh
# Output is also saved to test_result.log for the report.

KO="${KO:-./miniramfs.ko}"
MNT="${MNT:-/mnt/test}"
LOG="test_result.log"
PASS=0; FAIL=0

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
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

echo "--- tree ---"; ls -laR "$MNT"

# TC-07 unmount + remove module
check TC-07 "umount"                   "umount $MNT"
check TC-07 "rmmod"                    "rmmod miniramfs"
echo "--- dmesg (last 15 miniramfs lines) ---"
dmesg | grep -i miniramfs | tail -15
rm -f /tmp/mrf_big

echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
