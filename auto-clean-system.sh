sudo apt update
sudo apt upgrade
sudo apt autoremove --purge
sudo apt-get autoclean
sudo apt clean
sudo apt-get clean
sudo apt purge '~c'
dpkg --list | grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge
rm -rf ~/.cache/*
sudo find /tmp -type f -mtime +3 -delete
sudo find /var/tmp -type f -mtime +7 -delete
LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
    while read name rev; do
        snap remove "$name" --revision="$rev"
    done
