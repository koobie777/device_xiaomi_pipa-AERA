#!/usr/bin/env bash
# Prepare an Ubuntu 24.04 WSL2 box for building AERA Recovery for pipa.
set -euo pipefail

echo "### Updating apt"
sudo apt-get update -qq

echo "### Installing AOSP build dependencies"
# Ubuntu 24.04 dropped libncurses5 and lib32ncurses5-dev; the AOSP prebuilts
# that want libncurses.so.5 are handled by the symlink step below instead.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    bc bison build-essential ccache curl flex fontconfig git git-lfs gnupg gperf \
    imagemagick lib32readline-dev lib32z1-dev libdw-dev libelf-dev \
    libgl1-mesa-dev liblz4-tool libncurses-dev libsdl1.2-dev libssl-dev \
    libxml2 libxml2-utils lzop openjdk-21-jdk-headless pngcrush \
    python3 python3-pip python-is-python3 rsync schedtool squashfs-tools \
    unzip x11proto-dev xsltproc zip zlib1g-dev zstd \
    libc6-dev-i386 lib32stdc++6 libncurses6 libtinfo6

echo "### Shimming libncurses.so.5 for legacy AOSP prebuilts"
# Several AOSP host prebuilts are linked against the SONAMEs Ubuntu 24.04 no
# longer ships. The ABI is compatible enough for these tools in practice.
arch_dir=/usr/lib/x86_64-linux-gnu
for pair in "libncurses.so.6:libncurses.so.5" \
            "libtinfo.so.6:libtinfo.so.5" \
            "libncursesw.so.6:libncursesw.so.5"; do
    src="${pair%%:*}"
    dst="${pair##*:}"
    if [ -e "$arch_dir/$src" ] && [ ! -e "$arch_dir/$dst" ]; then
        sudo ln -sf "$arch_dir/$src" "$arch_dir/$dst"
        echo "  linked $dst -> $src"
    fi
done

echo "### Installing the repo tool"
mkdir -p ~/bin
if [ ! -x ~/bin/repo ]; then
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
    chmod a+x ~/bin/repo
fi
grep -q 'HOME/bin' ~/.profile 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile
export PATH="$HOME/bin:$PATH"

echo "### Configuring git"
git config --global user.name "koobie777"
git config --global user.email "cdrennon@gmail.com"
git config --global color.ui auto
# repo sync of an Android tree opens a lot of packs at once.
git config --global core.packedGitLimit 512m
git config --global core.packedGitWindowSize 512m
git config --global pack.deltaCacheSize 2047m
git config --global pack.packSizeLimit 2047m
git config --global pack.windowMemory 1024m

echo "### Configuring ccache (50G, on the ext4 volume)"
mkdir -p ~/.ccache
ccache -M 50G >/dev/null
ccache -o compression=true
grep -q 'USE_CCACHE' ~/.profile 2>/dev/null || {
    echo 'export USE_CCACHE=1' >> ~/.profile
    echo 'export CCACHE_EXEC=/usr/bin/ccache' >> ~/.profile
}

echo
echo "### Versions"
echo -n "repo:   "; ~/bin/repo --version 2>/dev/null | head -1 || echo "(installed, needs a tree)"
echo -n "git:    "; git --version
echo -n "java:   "; java -version 2>&1 | head -1
echo -n "python: "; python3 --version
echo -n "ccache: "; ccache --version | head -1
echo -n "cores:  "; nproc
echo
echo "### Done."
