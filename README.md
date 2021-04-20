# efistub

shell script to create efi boot entries with efibootmgr

| folder name | comment                                                                     |
| :---------- | :-------------------------------------------------------------------------- |
| entries     | config files for the boot entries, the order of the files is the boot order |

| name         | comment                                                                       |
| :----------- | :---------------------------------------------------------------------------- |
| efistub.conf | general config file to define efi disk and partition                          |
| efistub.sh   | script that deletes all boot entries from efi and create new ones from config |
