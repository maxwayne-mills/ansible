Ansible uses the yaml file format for creation od documents used by ansible.

YAML is very sensitive to white-space, and uses that to group different pieces of information together.
You should use only spaces and not tabs and you must use consistent spacing for your file to be read correctly.
Items at the same level of indentation are considered sibling elements.

Ad-hoc commands

run uptime command using root user and key file for authentication
ansible all -m shell -a 'uptime' -i inventory -u root --private-key ../vagrant-env/digital_ocean/id_rsa
ansible_howto.txt
