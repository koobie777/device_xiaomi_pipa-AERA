#!/usr/bin/env bash
# Block until sync-aera.sh has finished placing the device tree, then report.
#
# Watch the repo process itself, NOT git-remote-https: after the network phase
# repo moves to checkout, where no fetch helper is running, and keying off the
# helper reports a false failure. Don't scrape the progress line either -- repo
# rewrites it with carriage returns, so it never flushes and always looks
# frozen to a reader.
ROOT="$HOME/android/AERA_16.0"
MARKER="$ROOT/device/xiaomi/pipa/aera_pipa.mk"

repo_alive() { pgrep -f 'repo/main\.py.*sync' >/dev/null 2>&1; }

for i in $(seq 1 180); do   # up to ~90 min
    if [ -f "$MARKER" ]; then
        echo "SYNC COMPLETE (device tree placed) after ~$((i / 2)) min"
        du -sh "$ROOT" 2>/dev/null | awk '{print "tree: " $1}'
        exit 0
    fi
    if ! repo_alive; then
        # repo exited without the marker: either it failed, or the wrapper
        # script is between repo and the git clone step. Give it a moment.
        sleep 15
        if [ -f "$MARKER" ]; then
            echo "SYNC COMPLETE (device tree placed)"
            exit 0
        fi
        if ! repo_alive; then
            echo "repo exited and no device tree -- sync failed or was stopped"
            du -sh "$ROOT" 2>/dev/null | awk '{print "tree: " $1}'
            exit 1
        fi
    fi
    sleep 30
done
echo "TIMED OUT waiting for sync"
exit 2
