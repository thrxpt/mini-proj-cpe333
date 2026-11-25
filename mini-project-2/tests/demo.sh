#!/usr/bin/env bash
# miniramfs demo for the video (~2 min, 7 operations)
#   sudo bash tests/demo.sh            # normal pace
#   sudo DELAY=1 bash tests/demo.sh    # faster rehearsal
# Each step prints a heading, then "$ command", then its output.

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$HERE")" || exit 1        # run from repo root so paths stay short
KO="${KO:-src/miniramfs.ko}"
MNT="${MNT:-/mnt/test}"
DELAY="${DELAY:-6}"           # 20 commands x 6 s + headings ≈ 2 min

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0"; exit 1; }
B=$'\e[1;36m'; G=$'\e[1;32m'; Y=$'\e[0;33m'; N=$'\e[0m'
STEP=0

step() { STEP=$((STEP+1)); echo; echo "${B}━━━ [$STEP] $* ━━━${N}"; sleep 1; }
run()  { echo "${G}\$ $*${N}"; eval "$@"; sleep "$DELAY"; }
note() { echo "${Y}# $*${N}"; }

# clean start
umount "$MNT" 2>/dev/null; rmmod miniramfs 2>/dev/null; mkdir -p "$MNT"
clear
echo "${B}miniramfs — Mini RAM-Based File System demo   (kernel $(uname -r))${N}"
sleep 2

step "Load module"
run insmod "$KO"
run "grep miniramfs /proc/filesystems"

step "Operation 1: MOUNT"
run mount -t miniramfs none "$MNT"
run "mount | grep miniramfs"

step "Operation 2: CREATE DIRECTORY (mkdir)"
run mkdir "$MNT/docs" "$MNT/docs/sub"

step "Operation 3: CREATE FILE"
run touch "$MNT/docs/empty.txt"
run "ls -l $MNT/docs/empty.txt"
note "new empty file: size 0"

step "Operation 4: WRITE FILE"
run "echo 'CPE333 OS' > $MNT/docs/note.txt"
run "echo 'Line 2' >> $MNT/docs/note.txt"
note "append: size grows from 10 to 17 bytes"

step "Operation 5: READ FILE"
run cat "$MNT/docs/note.txt"

step "Operation 6: LIST DIRECTORY (ls)"
run ls -la "$MNT"
run ls -la "$MNT/docs"

step "Limit check: write > 1 MiB is rejected (EFBIG), no crash"
run "head -c 2M /dev/zero > $MNT/big.bin"
run "ls -l $MNT/big.bin"

step "Operation 7: UNMOUNT + remove module"
run umount "$MNT"
run "ls $MNT"
note "data lived only in RAM -> gone after umount"
run rmmod miniramfs

step "Kernel log (dmesg)"
run "dmesg | grep 'miniramfs:' | tail -5"
note "live files=0, live bytes=0  -> every buffer was freed (no leak)"
echo; echo "${G}Demo finished.${N}"
