#!/usr/bin/env bash
# Memory-leak test for miniramfs (S4)
#   mount -> create ROUND_DIRS dirs x ROUND_FILES files (with data) -> umount
#   repeated ROUNDS times; compare /proc/meminfo Slab + /proc/slabinfo before/after.
#   kmemleak is used automatically if the kernel has it (/sys/kernel/debug/kmemleak).
#
# Run as root from src/ after `make`:   sudo bash ../tests/leak_test.sh
# Log: docs/screenshots/logs/leak_test.log

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
KO="${KO:-$ROOT/src/miniramfs.ko}"
MNT="${MNT:-/mnt/test}"
ROUNDS="${ROUNDS:-50}"
DIRS="${DIRS:-20}"           # dirs per round
FILES="${FILES:-15}"         # files per dir  -> 300 files/round
LOGDIR="$ROOT/docs/screenshots/logs"
LOG="$LOGDIR/leak_test.log"
CACHES='^(inode_cache|dentry|kmalloc-(16|32|64|128|256|512|1k|2k|4k|8k)) '

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
mkdir -p "$LOGDIR" "$MNT"
exec > >(tee "$LOG") 2>&1

KML=/sys/kernel/debug/kmemleak
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null

snap() {   # snap <tag> : drop caches, record Slab + slab objects
  sync; echo 3 > /proc/sys/vm/drop_caches; sleep 1
  grep -E '^(MemFree|Slab|SReclaimable|SUnreclaim):' /proc/meminfo > "/tmp/mrf_mem_$1"
  grep -E "$CACHES" /proc/slabinfo | awk '{print $1, $2}' > "/tmp/mrf_slab_$1"
}

echo "=== miniramfs leak test  $(date) | kernel $(uname -r) ==="
echo "rounds=$ROUNDS  per round: $DIRS dirs x $FILES files (+ 1x 200 KiB file per dir)"
lsmod | grep -q '^miniramfs' || insmod "$KO" || exit 1
echo "miniramfs-leaktest-start" > /dev/kmsg

if [ -w "$KML" ]; then
  echo "kmemleak: available -> clearing"; echo clear > "$KML"; HAVE_KML=1
else
  echo "kmemleak: NOT available (CONFIG_DEBUG_KMEMLEAK not set) -> using slabinfo + module counters"
fi

# warm-up round so first-use allocations (caches, per-cpu) don't count as leak
mount -t miniramfs none "$MNT" && mkdir "$MNT/w" && echo w > "$MNT/w/f" && umount "$MNT"
snap before

PAYLOAD="$(head -c 3000 /dev/urandom | base64 -w0 | head -c 3000)"   # ~3 KB text
head -c 204800 /dev/urandom > /tmp/mrf_200k
t0=$(date +%s)
for r in $(seq 1 "$ROUNDS"); do
  mount -t miniramfs none "$MNT" || { echo "mount failed at round $r"; exit 1; }
  for d in $(seq 1 "$DIRS"); do
    mkdir -p "$MNT/d$d/sub"
    for f in $(seq 1 "$FILES"); do printf '%s\n' "$PAYLOAD" > "$MNT/d$d/f$f.txt"; done
    cp /tmp/mrf_200k "$MNT/d$d/sub/big.bin"
    rm "$MNT/d$d/f1.txt"                       # some unlink while mounted too
  done
  n=$(find "$MNT" -type f | wc -l)
  umount "$MNT" || { echo "umount failed at round $r"; exit 1; }
  [ $((r % 10)) -eq 0 ] && echo "round $r/$ROUNDS ok ($n files written)"
done
echo "elapsed: $(( $(date +%s) - t0 )) s"
snap after

echo; echo "--- /proc/meminfo (kB) ---"
printf '%-14s %12s %12s %10s\n' field before after delta
join <(sort /tmp/mrf_mem_before) <(sort /tmp/mrf_mem_after) |
  awk '{printf "%-14s %12d %12d %+10d\n",$1,$2,$4,$4-$2}'

echo; echo "--- /proc/slabinfo active objects ---"
printf '%-14s %10s %10s %8s\n' cache before after delta
LEAK=0
# objects created in total: (files + 2 dirs + big.bin) per dir; a leak of even 5% of them
# would exceed THR. Smaller +/- deltas are normal system churn (journald, page cache, ...).
CREATED=$((ROUNDS * DIRS * (FILES + 3))); THR=$((CREATED / 20))
while read -r name b a; do
  d=$((a - b)); printf '%-14s %10d %10d %+8d\n' "$name" "$b" "$a" "$d"
  case "$name" in inode_cache|dentry|kmalloc-16) [ "$d" -gt "$THR" ] && LEAK=1 ;; esac
done < <(join <(sort /tmp/mrf_slab_before) <(sort /tmp/mrf_slab_after))
echo "objects created: $CREATED inodes/dentries/file_data  -> leak threshold: +$THR (5%)"

rmmod miniramfs
echo; echo "--- dmesg (module counters) ---"
dmesg | tac | sed '/miniramfs-leaktest-start/q' | tac | grep -E 'miniramfs: (unmounted|module unloaded)' | tail -3
last=$(dmesg | grep 'miniramfs: module unloaded' | tail -1)
echo "$last" | grep -q 'live files=0, live bytes=0' || LEAK=1

if [ -n "$HAVE_KML" ]; then
  echo scan > "$KML"; sleep 5; echo scan > "$KML"
  echo "--- kmemleak ---"; cat "$KML"
  grep -q miniramfs "$KML" && LEAK=1
fi

OOPS=$(dmesg | tac | sed '/miniramfs-leaktest-start/q' | tac | grep -cE 'Oops|BUG:|WARNING:|Call Trace|general protection')
echo "kernel Oops/BUG/WARNING lines: $OOPS"; [ "$OOPS" -eq 0 ] || LEAK=1
rm -f /tmp/mrf_mem_* /tmp/mrf_slab_* /tmp/mrf_200k

if [ "$LEAK" -eq 0 ]; then echo "=== RESULT: PASS - no measurable leak after $ROUNDS rounds ==="
else echo "=== RESULT: FAIL - possible leak / kernel error ==="; exit 1; fi
