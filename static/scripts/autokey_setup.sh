#! /bin/sh

if [ $# -ne 2 ]; then
    echo "wrong number of parameters"
fi

SystemUsername=$1
GitHubUsername=$2

# create the script
sudo cat > /usr/local/bin/autokey.sh <<- END_TEXT
#! /bin/sh

case "$1" in
    $SystemUsername)
        wget --quiet -O - https://github.com/$GitHubUsername.keys
        ;;
    *)
        echo
        ;;
esac
END_TEXT

# mark it executable and remove write permissions
sudo chmod u+x,o-w /usr/local/bin/autokey.sh

# append our parameters to the config file
sudo cat >> /etc/ssh/sshd_config <<- END_TEXT
AuthorizedKeysCommand=/usr/local/bin/autokey.sh
AuthorizedKeysCommandUser=root
END_TEXT

# restart the sshd service to apply our config changes
sudo systemctl restart sshd.service