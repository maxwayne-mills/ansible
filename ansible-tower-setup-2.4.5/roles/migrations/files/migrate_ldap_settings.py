#!/usr/bin/env python
# This script moves the LDAP Django settings out of /etc/tower/settings.py
# and into its own file in conf.d.

import os

# First, read in our original settings file.
with open('/etc/tower/settings.py', 'r') as settings_file:
    contents = settings_file.read().split('\n')

# Isolate the database configuration from the remainder of the
# settings.
start = None
for line in contents:
    if line.startswith('# LDAP AUTHENTICATION SETTINGS'):
        start = contents.index(line) - 1
    if start:
        break
ldap_config = '\n'.join(contents[start:])
other_config = '\n'.join(contents[:start])

# Write the main settings file.
with open('/etc/tower/settings.py', 'w') as settings_file:
    settings_file.write(other_config)

# Write the database settings file.
with open('/etc/tower/conf.d/ldap.py', 'w') as ldap_settings_file:
    ldap_settings_file.write(ldap_config)
os.chmod('/etc/tower/conf.d/ldap.py', 0640)
