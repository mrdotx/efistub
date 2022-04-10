# efistub

![screenshot](screenshot.png)

shell script to create efi boot entries with efibootmgr

| folder name | comment                                                                 |
| :---------- | :---------------------------------------------------------------------- |
| entries     | config files for boot entries, the order of the files is the boot order |

| name            | comment                                                                       |
| :-------------- | :---------------------------------------------------------------------------- |
| efistub.sh      | script that deletes all boot entries from efi and create new ones from config |
| 99-efistub.hook | hook to update efi boot entries on kernel update with pacman                  |

## config files

values and defaults:

- label=Linux
- disk=/dev/sda
- partition=1
- loader=/vmlinuz-linux
- options=

## install pacman hook

- copy 99-efistub.hook to folder /etc/pacman.d/hooks
