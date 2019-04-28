#!/bin/bash

# find the directory containing this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ANSIBLE_DIR="$DIR/ansible"

cd ${ANSIBLE_DIR}

function is_installed {
  command -v $1 >/dev/null 2>&1
}

# make sure we're not running as root

if [[ "$USER" == "root" ]]; then
  echo "please don't run this script as the root user"
  echo "in order to set things up properly,"
  echo "you need to run with your main login account"
  exit 1
fi

# install ansible if missing
if ! is_installed ansible-playbook ; then
	echo "ansible not found, installing. you may be prompted for your password."
	sudo apt-get install -y ansible
fi


echo "installing configuration with ansible. this may take a little while."
echo "please enter your password when prompted."

exec ansible-playbook playbook.yml -i hosts -K -e "login_user=$USER" $@
