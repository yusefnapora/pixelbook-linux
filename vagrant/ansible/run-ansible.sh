#!/bin/bash

function ansible_installed {
  dnf list installed | grep ansible > /dev/null
}

if [ ! ansible_installed ]; then
	echo "ansible not found, installing"
	sudo dnf install -y ansible
fi

echo "running ansible. this will take about an hour on the first run"

exec ansible-playbook playbook.yml -i hosts -K -e "login_user=$USER"
