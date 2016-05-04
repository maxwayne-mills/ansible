#!/usr/bin/env bash
# This script runs setup for Ansible Tower.
# It determines how Tower is to be installed, gives the proper command,
# and then executes the command if asked.

# -------------
# Initial Setup
# -------------

# Cause exit codes to trickle through piping.
set -o pipefail

# When using an interactive shell, force colorized output from Ansible.
if [ -t "0" ]; then
    ANSIBLE_FORCE_COLOR=True
fi

# Set variables.
TIMESTAMP=$(date +"%F-%T")
LOG_DIR="/var/log/tower"
LOG_FILE="${LOG_DIR}/setup-${TIMESTAMP}.log"
TEMP_LOG_FILE='setup.log'

# Set a sensible default for TOWER_CONF_FILE, for the case that a configuration
# file is not explicitly set.
TOWER_CONF_FILE="tower_setup_conf.yml"
INVENTORY_FILE="inventory"
OPTIONS=""

# What playbook should be run?
# By default, this is setup.log, unless we are doing a backup
# (specified in the options).
PLAYBOOK="install.yml"

# -e bundle_install=false to override and disable bundle installer
OVERRIDE_BUNDLE_INSTALL=false

# -------------
# Helper functions
# -------------

# Be able to get the real path to a file.
realpath() {
    echo $(cd $(dirname $1); pwd)/$(basename $1)
}

find_bundle_rpm() {
    if [ -d bundle ]; then
        find bundle -type f -iname "$1"
    fi
}

is_ansible_installed() {
    type -p ansible-playbook > /dev/null
}

is_bundle_install() {
    [ -d "bundle" ] && [[ ${OVERRIDE_BUNDLE_INSTALL} == false ]]
}

distribution_id() {
    RETVAL=""
    if [ -z "${RETVAL}" -a -e "/etc/os-release" ]; then
        . /etc/os-release
        RETVAL="${ID}"
    fi

    if [ -z "${RETVAL}" -a -e "/etc/centos-release" ]; then
        RETVAL="centos"
    fi

    if [ -z "${RETVAL}" -a -e "/etc/fedora-release" ]; then
        RETVAL="fedora"
    fi

    if [ -z "${RETVAL}" -a -e "/etc/redhat-release" ]; then
        RELEASE_OUT=$(head -n1 /etc/redhat-release)
        case "${RELEASE_OUT}" in
            Red\ Hat\ Enterprise\ Linux*)
                RETVAL="rhel"
                ;;
            CentOS*)
                RETVAL="centos"
                ;;
            Fedora*)
                RETVAL="fedora"
                ;;
        esac
    fi

    if [ -z "${RETVAL}" ]; then
        RETVAL="unknown"
    fi

    echo ${RETVAL}
}

distribution_major_version() {
    for RELEASE_FILE in /etc/system-release \
                        /etc/centos-release \
                        /etc/fedora-release \
                        /etc/redhat-release
    do
        if [ -e "${RELEASE_FILE}" ]; then
            RELEASE_VERSION=$(head -n1 ${RELEASE_FILE})
            break
        fi
    done
    echo ${RELEASE_VERSION} | sed -e 's|\(.\+\) release \([0-9]\+\)\([0-9.]*\).*|\2|'
}

log_success() {
    if [ $# -eq 0 ]; then
        cat
    else
        echo "$*"
    fi
}

log_warning() {
    echo -n "[warn] "
    if [ $# -eq 0 ]; then
        cat
    else
        echo "$*"
    fi
}

log_error() {
    echo -n "[error] "
    if [ $# -eq 0 ]; then
        cat
    else
        echo "$*"
    fi
}

fatal_ansible_not_installed() {
    log_error <<-EOF
		Ansible is not installed on this machine.
		You must install Ansible before you can install Tower.

		For guidance on installing Ansible, consult
		http://docs.ansible.com/intro_installation.html.
		EOF
    exit 32
}


# --------------
# Usage
# --------------

function usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -c TOWER_CONF_FILE    Path to tower configure file (default: ${TOWER_CONF_FILE})
  -i INVENTORY_FILE     Path to ansible inventory file (default: ${INVENTORY_FILE})
  -e EXTRA_VARS         Set additional ansible variables as key=value or YAML/JSON
                        i.e. -e bundle_install=false will force an online install

  -b                    Perform a database backup in lieu of installing.
  -r BACKUP_FILE        Perform a database restore in lieu of installing.

  -p                    Instruct ansible to prompt for a SSH password
  -s                    Instruct ansible to prompt for a sudo password
  -u                    Instruct ansible to prompt for a su password
  -h                    Show this help message and exit

EOF
    exit 64
}


# --------------
# Option Parsing
# --------------

while getopts 'c:e:i:psuhbr:' OPTION; do
    case $OPTION in
        c)
            TOWER_CONF_FILE=$(realpath $OPTARG)
            ;;
        i)
            INVENTORY_FILE=$(realpath $OPTARG)
            ;;
        e)
            OPTIONS="$OPTIONS -e $OPTARG"
            IFS='=' read -a kv <<< "$OPTARG"
            if [ "${kv[0]}" == "bundle_install" ]; then
                OVERRIDE_BUNDLE_INSTALL=true
            fi
            ;;
        p)
            OPTIONS="$OPTIONS --ask-pass"
            ;;
        s)
            OPTIONS="$OPTIONS --ask-sudo-pass"
            ;;
        u)
            OPTIONS="$OPTIONS --ask-su-pass"
            ;;
        b)
            PLAYBOOK="backup.yml"
            TEMP_LOG_FILE="backup.log"
            OPTIONS="$OPTIONS --force-handlers"
            ;;
        r)
            PLAYBOOK="restore.yml"
            TEMP_LOG_FILE="restore.log"
            BACKUP_FILE=$(realpath $OPTARG)
            OPTIONS="$OPTIONS --force-handlers"
            ;;
        *)
            usage
            ;;
    esac
done

# Sanity check: Test to ensure that Ansible exists.
is_ansible_installed
if [ $? -ne 0 ]; then
    case $(distribution_id) in
        ubuntu)
            is_bundle_install
            if [ $? -eq 0 ]; then
               log_warning "Offline installation on Ubuntu is not supported."
            fi
            apt-get install -y software-properties-common
            add-apt-repository -y ppa:ansible/ansible
            apt-get update
            apt-get install -y ansible
            ;;
        rhel|centos)
            DISTRIBUTION_MAJOR_VERSION=$(distribution_major_version)
            is_bundle_install
            if [ $? -eq 0 ]; then
                # Attempt to find ansible package for the current distro in the bundle bundle
                ANSIBLE_RPM_PATH=$(find_bundle_rpm "ansible-[0-9]*.el${DISTRIBUTION_MAJOR_VERSION}.noarch.rpm")
                # Attempt to find ansible dependencies from the bundle bundle
                PYTHON_CRYPTO_RPM_PATH=$(find_bundle_rpm "python-crypto*.rpm")
                PYTHON_HTTPLIB_RPM_PATH=$(find_bundle_rpm "python-httplib*.rpm")
                PYTHON_KEYCZAR_RPM_PATH=$(find_bundle_rpm "python-keyczar*.rpm")
                PYTHON_PARAMIKO_RPM_PATH=$(find_bundle_rpm "python-paramiko*.rpm")
                PYTHON_ECDSA_RPM_PATH=$(find_bundle_rpm "python-ecdsa*.rpm")
                SSHPASS_RPM_PATH=$(find_bundle_rpm "sshpass-*.rpm")
                if [ -f "${ANSIBLE_RPM_PATH}" ]; then
                    yum install -y ${ANSIBLE_RPM_PATH} ${PYTHON_CRYPTO_RPM_PATH} ${PYTHON_HTTPLIB_RPM_PATH} ${PYTHON_KEYCZAR_RPM_PATH} ${PYTHON_PARAMIKO_RPM_PATH} ${PYTHON_ECDSA_RPM_PATH} ${SSHPASS_RPM_PATH}
                else
                    log_error "Unable to find ansible rpm for el${DISTRIBUTION_MAJOR_VERSION}."
                fi
            else
                case ${DISTRIBUTION_MAJOR_VERSION} in
                    6)
                        yum install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
                        ;;
                    7)
                        yum install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
                        ;;
                esac
                yum install -y ansible
            fi
            ;;
        fedora)
            yum install -y ansible
            ;;
    esac

    # Check whether ansible was successfully installed
    is_ansible_installed
    if [ $? -ne 0 ]; then
        log_error "Unable to install ansible."
        fatal_ansible_not_installed
    fi
fi

# Change to the running directory for tower conf file and inventory file
# defaults.
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Sanity check: Test to ensure that a setup configuration file exists.
if [ ! -f "${TOWER_CONF_FILE}" ]; then
    log_error <<-EOF
		No configuration file could be found at ${TOWER_CONF_FILE}.
		Run ./configure to create one, or specify one manually with -c.
		EOF
    exit 64
fi

# Sanity check: Test to ensure that an inventory file exists.
if [ ! -f "${INVENTORY_FILE}" ]; then
    log_error <<-EOF
		No inventory file could be found at ${INVENTORY_FILE}.
		Run ./configure to create one, or specify one manually with -i.
		EOF
    exit 64
fi

# Sanity check: Test to ensure that the backup file exists.
if [ $PLAYBOOK == "restore.yml" ]; then
    if [ ! -f $BACKUP_FILE ]; then
        log_error "Restore file not found."
        exit 1
    fi
    OPTIONS="$OPTIONS -e backup_file=$BACKUP_FILE"
fi

# Presume bundle install mode if directory "bundle" exists
# unless user overrides with "-e bundle_install=*"
if [ $PLAYBOOK == "install.yml" ]; then
    is_bundle_install
    if [ $? -eq 0 ]; then
        OPTIONS="$OPTIONS -e bundle_install=true"
    fi
fi

# Run the playbook.
PYTHONUNBUFFERED=x ANSIBLE_FORCE_COLOR=$ANSIBLE_FORCE_COLOR \
ANSIBLE_ERROR_ON_UNDEFINED_VARS=True \
ansible-playbook -i "${INVENTORY_FILE}" -v \
                 -e @"${TOWER_CONF_FILE}" \
                 $OPTIONS \
                 $PLAYBOOK 2>&1 | tee $TEMP_LOG_FILE

# Save the exit code and output accordingly.
RC=$?
if [ ${RC} -ne 0 ]; then
    log_error "Oops!  An error occured while running setup."
else
    log_success "The setup process completed successfully."
fi

# Save log file.
if [ -d "${LOG_DIR}" ]; then
    sudo cp ${TEMP_LOG_FILE} ${LOG_FILE}
    if [ $? -eq 0 ]; then
        sudo rm ${TEMP_LOG_FILE}
    fi
    log_success "Setup log saved to ${LOG_FILE}"
else
    log_warning <<-EOF
		${LOG_DIR} does not exist.
		Setup log saved to ${TEMP_LOG_FILE}.
		EOF
fi

exit ${RC}
