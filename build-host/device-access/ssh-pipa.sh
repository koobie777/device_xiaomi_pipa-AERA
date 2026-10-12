#!/usr/bin/env bash
# SSH to the pipa tablet from WSL.
#
# The Windows OpenSSH client is 9.5 while the tablet runs OpenSSH 10.6, and the
# Windows client reached "Server accepts key" and then failed -- i.e. the key
# was authorized but the exchange still broke. WSL has a much newer client, so
# try from here before blaming the server.
#
# Usage: ssh-pipa.sh [command...]
set -o pipefail

KEY_SRC=/mnt/c/Users/CJ/pipa-eos/ssh/pipa_ed25519
KEY=~/.ssh/pipa_ed25519
HOST=koobie777@192.168.40.86

mkdir -p ~/.ssh
# The key cannot be used from /mnt/c: that mount is 0777 and ssh refuses a
# world-readable private key.
cp -f "$KEY_SRC" "$KEY"
chmod 600 "$KEY"

echo "### local ssh client"
ssh -V 2>&1

echo
echo "### connecting to $HOST"
if [ "$#" -eq 0 ]; then
    set -- 'whoami; hostname; uname -r; echo "--- shell ---"; echo $SHELL'
fi

ssh -i "$KEY" \
    -o StrictHostKeyChecking=accept-new \
    -o BatchMode=yes \
    -o ConnectTimeout=20 \
    "$HOST" "$@"
rc=$?
echo
echo "### exit $rc"
exit "$rc"
