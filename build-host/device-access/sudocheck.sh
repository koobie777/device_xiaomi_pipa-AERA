#!/usr/bin/env bash
# Why does passwordless sudo work interactively but not over a non-TTY ssh?
echo "===== whoami / tty ====="
whoami
tty || echo "(no tty -- this is the non-interactive case)"

echo
echo "===== sudo -n true ====="
sudo -n true
echo "rc=$?"

echo
echo "===== sudo -n true, stderr shown ====="
sudo -n true 2>&1 || true

echo
echo "===== sudo -n -l ====="
sudo -n -l 2>&1 | tail -8

echo
echo "===== does the drop-in exist? (dir is root-only, so this may fail) ====="
ls -l /etc/sudoers.d/ 2>&1 | tail -6

echo
echo "===== requiretty or env_reset in the main sudoers? ====="
sudo -n grep -iE 'requiretty|!requiretty|includedir' /etc/sudoers 2>&1 | tail -5 \
    || echo "  (cannot read /etc/sudoers without sudo)"

echo
echo "===== sudo version ====="
sudo -V 2>&1 | head -2
