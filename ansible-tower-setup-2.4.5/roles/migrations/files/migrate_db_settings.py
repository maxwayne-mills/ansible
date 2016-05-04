#!/usr/bin/env python
# This script moves the DATABASES Django setting out of /etc/tower/settings.py
# and into its own file in conf.d.
#
# The purpose of doing this is to make this setting more modular, and make it
# easy to fetch it from a primary box and place the fetched configuration on
# secondary machines.

import os

# First, read in our original settings file.
with open('/etc/tower/settings.py', 'r') as settings_file:
    contents = settings_file.read().split('\n')

# Isolate the database configuration from the remainder of the
# settings.
start = end = None
for line in contents:
    if line.startswith('DATABASES ='):
        start = contents.index(line)
    if line.startswith('STATIC_ROOT ='):
        end = contents.index(line)
    if start and end:
        break
database_config = '\n'.join(contents[start:end])
other_config = '\n'.join(contents[:start] + contents[end:])

# Write the main settings file.
with open('/etc/tower/settings.py', 'w') as settings_file:
    settings_file.write(other_config)

# Write the database settings file.
with open('/etc/tower/conf.d/postgres.py', 'w') as db_settings_file:
    db_settings_file.write(database_config)
os.chmod('/etc/tower/conf.d/postgres.py', 0640)
