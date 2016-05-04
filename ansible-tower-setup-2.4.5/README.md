Ansible Tower Deployment
========================

This collection of files provides a complete set of playbooks for deploying
the Ansible Tower software to a single-server installation. It is also to
install Tower to the local machine, or to a remote machine reachable by SSH.

For quickly getting started with installation and setup instructions, refer to:

- Ansible Tower Quick Installation Guide -- http://docs.ansible.com/ansible-tower/latest/html/quickinstall/index.html
- Ansible Tower Quick Setup Guide -- http://docs.ansible.com/ansible-tower/latest/html/quickstart/index.html

For more indepth documentation, refer to:

- Ansible Tower Installation and Reference Guide -- http://docs.ansible.com/ansible-tower/latest/html/installandreference/index.html
- Ansible Tower User Guide -- http://docs.ansible.com/ansible-tower/latest/html/userguide/index.html 
- Ansible Tower Administration Guide -- http://docs.ansible.com/ansible-tower/latest/html/administration/index.html
- Ansible Tower API Guide -- http://docs.ansible.com/ansible-tower/latest/html/towerapi/index.html


To install or upgrade, start by running ./configure in this directory. After
doing so, run ./setup.sh.

> *WARNING*: The playbook will overwrite the content
> of `pg_hba.conf` and strip all comments from `supervisord.conf`.  Run this
> only on a clean virtual machine if you are not ok with this behavior.
