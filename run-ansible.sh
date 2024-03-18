#!/bin/bash

# find the directory containing this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ANSIBLE_DIR="$DIR/ansible"

cd ${ANSIBLE_DIR}

function is_installed {
  command -v $1 >/dev/null 2>&1
}

function install_if_missing {
  local cmd=$1
  if ! is_installed $cmd; then
    echo "$cmd not found, installing"
    echo "you may be prompted for your password"
    sudo apt-get install -y $cmd
  fi
}

# make sure we're not running as root

if [[ "$USER" == "root" ]]; then
  echo "please don't run this script as the root user"
  echo "in order to set things up properly,"
  echo "you need to run with your main login account"
  exit 1
fi

# make sure we have the minimum packages to run ansible
install_if_missing git
install_if_missing python3
install_if_missing ansible

if ! grep user $HOME/.gitconfig >/dev/null 2>&1; then
	echo "You must configure git with your name and email before running"
	echo
	echo "Run these commands (replace values with your info):"
	echo
	echo "git config --global user.name 'Your Name'"
	echo "git config --global user.email 'your@email.com'"
	exit 1
fi

echo "installing configuration with ansible. this may take a little while."
echo "please enter your password when prompted."

exec ansible-playbook playbook.yml -i hosts -K -e "login_user=$USER" $@
