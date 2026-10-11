#!/usr/bin/env bash
# The aera-16.0 manifest points AERA-owned projects at git@github.com:, so
# repo sync tries SSH for them and stalls on host-key prompts. `repo init -u
# https://...` only overrides the manifest repo's own URL, not the per-project
# remotes defined inside it.
#
# The repos are public, so no key is needed -- rewrite SSH GitHub URLs to HTTPS.
#
# NOTE: both rewrites target the same config key
# (url.https://github.com/.insteadof), so the second MUST use --add or it
# silently replaces the first.
set -euo pipefail

ROOT="$HOME/android/AERA_16.0"
export PATH="$HOME/bin:$PATH"

echo "### All remotes declared in the manifest"
sed -n 's/.*<remote *name="\([^"]*\)".*/remote: \1/p;s/.*fetch="\([^"]*\)".*/  fetch: \1/p' \
    "$ROOT/.repo/manifests/default.xml" 2>/dev/null | head -30 || echo "(unreadable)"

echo
echo "### Resetting and applying both SSH->HTTPS rewrites"
git config --global --unset-all url."https://github.com/".insteadOf 2>/dev/null || true
git config --global --add url."https://github.com/".insteadOf "git@github.com:"
git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/"
echo "configured:"
git config --global --get-all url."https://github.com/".insteadOf | sed 's/^/  /'

echo
echo "### Pre-trusting github.com host keys"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts
if ! ssh-keygen -F github.com >/dev/null 2>&1; then
    ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    echo "  added github.com"
else
    echo "  github.com already known"
fi

echo
echo "### Verifying AERA repos now resolve over HTTPS"
ok=0
for r in android_bootable_recovery android_vendor_recovery android_manifest; do
    if git ls-remote "git@github.com:AERA-Recovery/$r.git" aera-16.0 >/dev/null 2>&1; then
        echo "  ok   $r"
        ok=$((ok + 1))
    else
        echo "  FAIL $r"
    fi
done

echo
if [ "$ok" -eq 3 ]; then
    echo "RESULT: rewrite works -- resume sync-aera.sh (repo sync is resumable)"
else
    echo "RESULT: rewrite still failing -- do not resync yet"
fi
exit 0
