#!/bin/sh

# path:   /home/klassiker/.local/share/repos/efistub/efistub.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/efistub
# date:   2021-04-20T17:24:17+0200

workdir="$(dirname "$0")"

# source general config file
. "$workdir/efistub.conf"

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
        --disk "$loader_disk" \
        --part "$loader_partition" \
        --create \
        --label "$1" \
        --loader "$2" \
        --unicode "$3" \
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
    for boot_entry in "$workdir"/entries/*.conf; do
        # shellcheck disable=SC1090
        . "$boot_entry"
        # shellcheck disable=SC2154
        create_boot_entry \
            "$label" \
            "$loader" \
            "$(pivot "$options" " ")"
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
if [ ! "$(id -u)" = 0 ]; then
    printf "this script needs root privileges to run\n"
    exit 1
else
    printf ":: delete boot numbers\n   "
    delete_boot_entries
    printf "\n"

    printf ":: create boot entries\n"
    create_boot_entries
    printf "\n"

    printf ":: create boot order\n"
    create_boot_order
fi
