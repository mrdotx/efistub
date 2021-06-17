#!/bin/sh

# path:   /home/klassiker/.local/share/repos/efistub/efistub.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/efistub
# date:   2021-06-17T12:59:43+0200

config_directory="$(dirname "$0")/entries"

script=$(basename "$0")
help="$script [-h/--help] -- script to create efi boot entries with efibootmgr
  Usage:
    $script <path> [-b] [hex]

  Settings:
  <path> = directory with config files
           (default: $config_directory)
  [-b]   = set next boot entry

  Examples:
    $script /boot/EFI/loader
    $script -b"

# efibootmgr functions
get_entries() {
    case "$1" in
        --name)
            efibootmgr \
                | grep "\* $2$" \
                | sed 's/^Boot//g;s/\*//g'
            ;;
        --hex)
            efibootmgr \
                | grep "Boot$2\* " \
                | sed 's/^Boot//g;s/\*//g'
            ;;
        *)
            efibootmgr \
                | grep "\* " \
                | sed 's/^Boot//g;s/\*.*//g'
            ;;
    esac
}

get_boot_next() {
    boot_next=$( \
        efibootmgr \
            | grep "BootNext" \
            | cut -d ' ' -f2 \
    )
    get_entries --hex "$boot_next"
}

set_boot_next() {
    efibootmgr \
        | grep "\* " \
        | sed 's/^Boot/  -> /g;s/\*//g'
    printf "==> set boot next to XXXX (hex): " \
        && read -r boot_next \
        && efibootmgr \
            --bootnext "$boot_next" \
            --quiet
}

delete_boot_entries() {
    for i in $(get_entries)
    do
        printf "  -> %s\n" "$(get_entries --hex "$i")"
        efibootmgr \
            --bootnum "$i" \
            --delete-bootnum \
            --quiet
    done
}

create_boot_entries() {
    for f in "$config_directory"/*.conf; do
        . "$f"
        efibootmgr \
            --create \
            --label "${label:=Linux}" \
            --disk "${disk:=/dev/sda}" \
            --part "${partition:=1}" \
            --loader "${loader:=/vmlinuz-linux}" \
            --unicode "$(pivot "${options:=}" " ")" \
            --quiet
        printf "  -> %s\n" "$(get_entries --name "$label")"
        unset label disk partition loader options
    done
}

create_boot_order() {
    boot_order="$(pivot "$(get_entries)" ",")"
    efibootmgr \
        --bootorder "$boot_order" \
        --quiet >/dev/null 2>&1
}

# helper functions
check_root() {
    [ "$(id -u)" -ne 0 ] \
        && printf "this script needs root privileges to run\n" \
        && exit 1
}

pivot() {
    printf "%s\n" "$1" \
        | awk '{gsub(/^ +| +$/,"")} !/^($|#)/ {print $0}' \
        | {
            while IFS= read -r line; do
                if [ -n "$entry" ]; then
                    entry="$entry$2$(printf "%s" "$line")"
                else
                    entry="$(printf "%s" "$line")"
                fi
            done
            printf "%s\n" "$entry"
        }
}

# main
case "$1" in
    -h | --help)
        printf "%s\n" "$help"
        ;;
    -b)
        check_root

        printf "==> boot next\n"
        set_boot_next
        printf "  -> %s\n" "$(get_boot_next)"
        ;;
    *)
        check_root

        [ -n "$1" ] \
            && config_directory="$1"

        printf "==> delete old boot entries\n"
        delete_boot_entries
        printf "==> create new boot entries\n"
        create_boot_entries
        create_boot_order
esac
