#!/bin/sh

# path:   /home/klassiker/.local/share/repos/efistub/efistub.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/efistub
# date:   2025-05-29T05:07:07+0200

config_directory="$(dirname "$0")/entries"

script=$(basename "$0")
help="$script [-h/--help] -- script to create efi boot entries with efibootmgr
  Usage:
    $script <path> <entries> [-b]

  Settings:
  <path>    = directory with config files
              (default: $config_directory)
  <entries> = boot entries to delete
  [-b]      = set next boot entry

  Examples:
    $script
    $script /boot/entries
    $script 0000 0001 0002 0003
    $script /boot/entries 0000 0001 0002 0003
    $script -b"

# efibootmgr functions
get_entries() {
    case "$1" in
        --name)
            efibootmgr \
                | cut -d'	' -f1 \
                | grep "\* $2$" \
                | sed 's/^Boot//g;s/\*//g'
            ;;
        --hex)
            efibootmgr \
                | cut -d'	' -f1 \
                | grep "Boot$2\* " \
                | sed 's/^Boot//g;s/\*//g'
            ;;
        *)
            efibootmgr \
                | cut -d'	' -f1 \
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
    unset boot_next
}

set_boot_next() {
    efibootmgr \
        | cut -d'	' -f1 \
        | grep "\* " \
        | sed 's/^Boot/  -> /g;s/\*//g'
    printf "==> set boot next to XXXX (hex): " \
        && read -r boot_next \
        && efibootmgr \
            --bootnext "$boot_next" \
            --quiet
    unset boot_next
}

delete_boot_entries() {
    for i in $@
    do
        printf "  -> %s\n" "$(get_entries --hex "$i")"
        efibootmgr \
            --bootnum "$i" \
            --delete-bootnum \
            --quiet
    done
    unset i
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
    unset f
}

create_boot_order() {
    boot_order="$(pivot "$(get_entries)" ",")"
    efibootmgr \
        --bootorder "$boot_order" \
        --quiet >/dev/null 2>&1
        printf "  -> %s\n" "$boot_order"
    unset boot_order
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
        | while IFS= read -r line; do
            [ -n "$i" ] \
                && printf "%s" "$2" "$line"
            [ -z "$i" ] \
                && printf "%s" "$line" \
                && i=1
        done
    printf "\n"
    unset i
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

        [ -d "$1" ] \
            && config_directory="$1" \
            && shift

        if [ "$(find -L "$config_directory" \
                -maxdepth 1 \
                -type f \
                -name "*.conf" \
                -print \
                -quit | wc -l)" -eq 1 ]; then
            printf "==> delete old boot entries\n"
            delete_boot_entries "$@"
            printf "==> create new boot entries\n"
            create_boot_entries
            printf "==> create boot order\n"
            create_boot_order
        else
            printf "%s\n" "$help"
            printf "==> no .conf files found\n"
        fi
        ;;
esac
