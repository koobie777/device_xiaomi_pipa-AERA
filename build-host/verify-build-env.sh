#!/usr/bin/env bash
# Verify the WSL build environment is ready for an AERA recovery build.
# Run as: wsl -d Ubuntu-24.04 -- bash /mnt/c/Users/CJ/pipa-eos/aera/verify-build-env.sh
missing=0

echo "=== packages ==="
for p in bc bison build-essential ccache curl flex git git-lfs gnupg gperf \
         imagemagick libdw-dev libelf-dev libgl1-mesa-dev liblz4-tool \
         libncurses-dev libssl-dev libxml2-utils lzop \
         openjdk-21-jdk-headless python3 python-is-python3 rsync \
         schedtool squashfs-tools unzip x11proto-dev xsltproc zip \
         zlib1g-dev zstd libc6-dev-i386; do
    if dpkg -s "$p" >/dev/null 2>&1; then
        printf 'ok   %s\n' "$p"
    else
        printf 'MISS %s\n' "$p"
        missing=$((missing + 1))
    fi
done

echo
echo "=== ncurses .5 shims (legacy AOSP prebuilts) ==="
for l in libncurses.so.5 libtinfo.so.5 libncursesw.so.5; do
    if [ -e "/usr/lib/x86_64-linux-gnu/$l" ]; then
        printf 'ok   %s\n' "$l"
    else
        printf 'MISS %s\n' "$l"
        missing=$((missing + 1))
    fi
done

echo
echo "=== tools ==="
if [ -x "$HOME/bin/repo" ]; then echo "ok   repo at $HOME/bin/repo"; else echo "MISS repo"; missing=$((missing + 1)); fi
printf 'git     %s\n' "$(git --version 2>/dev/null)"
printf 'java    %s\n' "$(java -version 2>&1 | head -1)"
printf 'python  %s\n' "$(python3 --version 2>/dev/null)"
printf 'ccache  %s\n' "$(ccache --version 2>/dev/null | head -1)"

echo
echo "=== git identity ==="
printf 'name    %s\n' "$(git config --global user.name)"
printf 'email   %s\n' "$(git config --global user.email)"

echo
echo "=== resources ==="
printf 'cores   %s\n' "$(nproc)"
free -g | awk '/^Mem:/ {printf "mem     %s GiB total, %s available\n", $2, $7} /^Swap:/ {printf "swap    %s GiB\n", $2}'
df -h / | awk 'NR==2 {printf "disk    %s free of %s on %s\n", $4, $2, $1}'

echo
if [ "$missing" -eq 0 ]; then
    echo "RESULT: build environment READY"
else
    echo "RESULT: $missing item(s) missing"
fi
exit 0
