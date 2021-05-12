#!/bin/sh

# path:   /home/klassiker/.local/share/repos/efistub/efistub.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/efistub
# date:   2021-05-12T20:50:13+0200

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

get_boot_next() {
    boot_next=$( \
        efibootmgr \
            | grep "BootNext" \
            | cut -d ' ' -f2 \
    )
    efibootmgr \
        | grep "Boot$boot_next\* " \
        | sed 's/^Boot//g;s/\*//g'
}

get_entries() {
    efibootmgr \
        | grep "\* " \
        | sed 's/^Boot//g;s/\*.*//g'
}

get_entry() {
    efibootmgr \
        | grep "\* $1$" \
        | sed 's/^Boot//g;s/\*//g'
}

delete_boot_entries() {
    printf "  -> "
    for i in $(get_entries)
    do
        printf "%s " "$i"
        efibootmgr \
            --bootnum "$i" \
            --delete-bootnum \
            --quiet
    done
    printf "\n"
}

create_boot_entry() {
    printf "  -> "
    efibootmgr \
        --create \
        --label "$1" \
        --disk "$2" \
        --part "$3" \
        --loader "$4" \
        --unicode "$5" \
        --quiet
    get_entry "$1"
}

create_boot_order() {
    boot_order="$(pivot "$(get_entries)" ",")"
    efibootmgr \
        --bootorder "$boot_order" \
        --quiet >/dev/null 2>&1
}

create_boot_entries() {
    for f in "$config_directory"/*.conf; do
        # shellcheck disable=SC1090
        . "$f"
        # shellcheck disable=SC2154
        create_boot_entry \
            "${label:=Linux}" \
            "${disk:=/dev/sda}" \
            "${partition:=1}" \
            "${loader:=/vmlinuz-linux}" \
            "$(pivot "$options" " ")"
        unset label disk partition loader options
    done
}

# helper functions
check_root() {
        [ ! "$(id -u)" = 0 ] \
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

        boot_next="$(get_boot_next)"
        [ -n "$boot_next" ] \
            && boot_next=$(printf " -> %s" "$boot_next")
        printf "==> boot next%s\n" "$boot_next"
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
