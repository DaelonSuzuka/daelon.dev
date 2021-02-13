#! /bin/sh

# this is a shell script to install automated ssh key management
# only tested on ubuntu 20.04

# /etc/ssh/sshd_config
sudo cat >> test1 <<- END_TEXT
AuthorizedKeysCommand=/usr/local/bin/autokey.sh
AuthorizedKeysCommandUser=root
END_TEXT

# /usr/locan/bin/autokey.sh
sudo cat >> test2 <<- END_TEXT
#!/bin/sh

[ $# -ne 1 ] && { echo "Usage: $0 userid" >&2; exit 1; }

case "$1" in
    daelon)
        # this is just a joke; don't take this seriously, and if you
        # do, make sure you have some sort of cache in case your
        # internet goes kaputt
        curl -sf https://api.github.com/users/DaelonSuzuka/keys |
        jq -r '.[].key'
        ;;
    *)
        keyfile="/var/lib/keys/$1.pub"
        [ -f $keyfile ] && cat $keyfile
esac
END_TEXT