#!/usr/bin/env bash
# Full A/B slot state. An A/B bootloader will refuse a slot marked unbootable
# and fall back, so "active" alone is not enough to boot it.
echo "===== qbootctl help (full) ====="
sudo qbootctl -h 2>&1

echo
echo "===== full slot dump ====="
sudo qbootctl 2>&1

echo
echo "===== explicit bootable checks ====="
echo -n "slot a bootable: "; sudo qbootctl -b a 2>&1
echo -n "slot b bootable: "; sudo qbootctl -b b 2>&1

echo
echo "===== current / active ====="
echo -n "current: "; sudo qbootctl -c 2>&1 | tail -1
echo -n "active:  "; sudo qbootctl -a 2>&1 | tail -1
