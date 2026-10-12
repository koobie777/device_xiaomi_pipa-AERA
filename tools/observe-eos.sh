#!/usr/bin/env bash
# Read-only pipa observations from the installed EndeavourOS system.
# No sudo calls, mounts, repairs, formatting, partition writes, reboots,
# slot changes, credential files, or pstore deletion. Output goes to stdout.
# If permissions hide evidence, the user may explicitly run this with sudo.

section() {
    printf '\n===== %s =====\n' "$1"
}

show_command() {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
}

observe() {
    local observation_status
    show_command "$@"
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Unavailable command: %s\n' "$1"
        return 0
    fi
    "$@" 2>&1
    observation_status=$?
    if [ "$observation_status" -ne 0 ]; then
        printf '[incomplete: command returned %s; continuing]\n' "$observation_status"
    fi
    return 0
}

# /etc/fstab and /proc/mounts both use source,target,type,options fields.
# Only emit active entries; redact credential option values and URL userinfo.
# Do not fall back to printing raw configuration if awk is unavailable.
observe_mount_table() {
    local observation_file="$1"
    printf 'Read %s through credential redaction (awk); comments omitted.\n' "$observation_file"
    if [ ! -r "$observation_file" ]; then
        printf '[unavailable or unreadable: %s]\n' "$observation_file"
        return 0
    fi
    if ! command -v awk >/dev/null 2>&1; then
        printf '[awk unavailable; raw configuration is not printed]\n'
        return 0
    fi
    awk '
        /^[[:space:]]*#/ || NF < 4 { next }
        {
            source = $1
            sub(/:\/\/[^\/@]*@/, "://<redacted>@", source)
            sub(/^\/\/[^\/@]*@/, "//<redacted>@", source)
            count = split($4, options, ",")
            safe_options = ""
            for (i = 1; i <= count; i++) {
                option = options[i]
                if (tolower(option) ~ /^(password|passwd|pass|username|user|credentials|credential|secret|token|access_key|secret_key|key)=/) {
                    sub(/=.*/, "=<redacted>", option)
                }
                safe_options = safe_options (i > 1 ? "," : "") option
            }
            printf "%s %s %s %s", source, $2, $3, safe_options
            for (i = 5; i <= NF; i++) {
                if ($i ~ /^#/) break
                printf " %s", $i
            }
            printf "\n"
        }
    ' "$observation_file" 2>&1
}

section 'Identity and current kernel'
observe date -u '+%Y-%m-%dT%H:%M:%SZ'
observe id
observe uname -a
if [ "$(id -u 2>/dev/null)" != 0 ]; then
    printf 'Running without root. Restricted evidence may be incomplete; this script never invokes sudo.\n'
fi
observe cat /proc/cmdline

section 'Block layout and actual mounts'
if command -v lsblk >/dev/null 2>&1; then
    show_command lsblk -o NAME,KNAME,TYPE,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,RO
    if ! lsblk -o NAME,KNAME,TYPE,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,RO 2>&1; then
        observe lsblk -o NAME,TYPE,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT,RO
    fi
else
    printf '[lsblk unavailable]\n'
fi
observe_mount_table /etc/fstab
observe_mount_table /proc/mounts

section 'Read-only filesystem signatures for named pipa partitions'
printf 'Probe only existing block devices selected by partition name; no device-number assumptions.\n'
for partition_label in userdata metadata linux cust rawdump; do
    partition_path=''
    for by_name_directory in /dev/disk/by-partlabel /dev/block/by-name /dev/block/bootdevice/by-name; do
        candidate_path="$by_name_directory/$partition_label"
        if [ -b "$candidate_path" ]; then
            partition_path="$candidate_path"
            break
        fi
    done
    if [ -z "$partition_path" ]; then
        printf '%s: no matching block device found\n' "$partition_label"
        continue
    fi
    observe readlink -f "$partition_path"
    observe blkid -p -c /dev/null -o export -- "$partition_path"
done
printf 'An unavailable signature may reflect access restrictions or Android metadata encryption; it does not prove damage.\n'

section 'Preserved pstore records (never cleared or deleted)'
for pstore_directory in /sys/fs/pstore /var/lib/systemd/pstore; do
    printf '\nDirectory: %s\n' "$pstore_directory"
    if [ ! -d "$pstore_directory" ]; then
        printf '[directory absent]\n'
        continue
    fi
    observe ls -ld -- "$pstore_directory"
    if [ ! -r "$pstore_directory" ] || [ ! -x "$pstore_directory" ]; then
        printf '[directory is not readable/searchable with current permissions]\n'
        continue
    fi
    observe ls -l -- "$pstore_directory"
    pstore_records=0
    for pstore_file in "$pstore_directory"/*; do
        [ -f "$pstore_file" ] || continue
        pstore_records=$((pstore_records + 1))
        printf '\nRecord: %s\n' "$pstore_file"
        if [ ! -r "$pstore_file" ]; then
            printf '[record is not readable with current permissions]\n'
            continue
        fi
        observe wc -c -- "$pstore_file"
        printf 'Last 524288 bytes at most; original file remains intact.\n'
        observe tail -c 524288 -- "$pstore_file"
        printf '\n'
    done
    if [ "$pstore_records" -eq 0 ]; then
        printf '[no regular pstore records found; no conclusion about earlier boots]\n'
    fi
done

section 'Recent accessible kernel journal'
observe journalctl --no-pager -k -b -n 200 -o short-monotonic

section 'End of read-only observations'
printf 'No mount, repair, format, partition write, reboot, slot change, credential-file read, or pstore removal requested.\n'
printf 'InfinityX had not booted after the earlier Linux setup; this report does not assume the AERA RAM test caused a regression.\n'
