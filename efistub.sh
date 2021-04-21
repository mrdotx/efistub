#!/bin/sh

# path:   /home/klassiker/.local/share/repos/efistub/efistub.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/efistub
# date:   2021-04-21T10:40:51+0200

config_directory="$(dirname "$0")/entries"

script=$(basename "$0")
help="$script [-h/--help] -- script to create efi boot entries with efibootmgr
  Usage:
    $script [config directory]

  Settings:
  [config directory] = directory with config files
                       (default: $config_directory)

  Examples:
    $script /boot/EFI/loader"

# efibootmgr functions
get_entries() {
    efibootmgr \
        | grep "\*" \
        | sed 's/^Boot//g;s/\*.*//g'
}

get_entry() {
    efibootmgr \
        | grep "$1$" \
        | sed 's/^Boot//g;s/\*//g'
}

delete_boot_entries() {
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
    printf "   "
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
    printf "   %s\n" "$boot_order"
    efibootmgr \
        --bootorder "$boot_order" \
        --quiet
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
    *)
        if [ ! "$(id -u)" = 0 ]; then
            printf "this script needs root privileges to run\n"
            exit 1
        else
            [ -n "$1" ] \
                && config_directory="$1"

            printf ":: delete boot numbers\n   "
            delete_boot_entries
            printf "\n"

            printf ":: create boot entries\n"
            create_boot_entries
            printf "\n"

            printf ":: create boot order\n"
            create_boot_order
        fi
esac
