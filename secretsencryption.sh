#!/bin/bash
#
# Setup secrets encryption for git
# Can be enabled globally or per repository
#
# Enable global debug
# set -xv

set -uo pipefail
export VERBOSE=0
export ERROR_CODE=0
export TMP_FILE="$(mktemp)"
export TMP_DIR="$(mktemp -d)"
export GITHOOKSDIR="${HOME}/.githooks"

trap cleanup EXIT
trap interrupted SIGHUP SIGINT SIGQUIT SIGTERM

function interrupted() {
    msg "$0 interrupted. Please rerun it to finish setup."
    cleanup
}

function cleanup() {
    rm -fr $TMP_FILE
    rm -fr $TMP_DIR
    exit $ERROR_CODE
}

function msg_exit() {
    if [ -z "${1+x}" ]; then
        msg=""
    else
        msg=$1
    fi
    if [ -z "${2+x}" ]; then
        ERROR_CODE=127
    else
        ERROR_CODE=$2
    fi
    echo -e "$msg"
    echo -e "Exiting..."
    exit $ERROR_CODE
}

function debug() {
    [ "${VERBOSE}" -eq 1 ] && echo -en "DEBUG: $@"
}

function msg() {
    echo -e "$@"
}

function check_tools() {
    local minimal_git_version="2.9.0"
    local minimal_git_major=$(echo ${minimal_git_version} | cut -d'.' -f 1 )
    local minimal_git_minor=$(echo ${minimal_git_version} | cut -d'.' -f 2 )
    local git_version="$(git -v | cut -d' ' -f3)"
    local git_major=$(echo ${git_version} | cut -d'.' -f 1 )
    local git_minor=$(echo ${git_version} | cut -d'.' -f 2 )

    [ ${minimal_git_major} -gt ${git_major} ] || [ ${minimal_git_minor} -gt ${git_minor} ] && \
        msg_exit "Need git version at least ${minimal_git_version} -> found git version ${git_version}"
}

function get_git_hooks() {
    git clone https://github.com/timaliev/git-secrets-encryption.git ${TMP_DIR}
    [ $? -ne 0 ] && msg_exit "Error cloning Github repository" 127
}

function install_git_hooks() {
    local datetime=$(date -Iseconds)

    if [ -d "${GITHOOKSDIR}" ]; then
        mv "${GITHOOKSDIR}" "${GITHOOKSDIR}.${datetime}"
        msg "Moved your existing ${GITHOOKSDIR} to ${GITHOOKSDIR}.${datetime}"
        msg "Consider copying you existing scripts to ${GITHOOKSDIR} manually."
    fi
    mkdir "${GITHOOKSDIR}" && chmod 755 "${GITHOOKSDIR}"
    mv $TMP_DIR/.githooks/* "${GITHOOKSDIR}"
    chmod -R +x "${GITHOOKSDIR}"
}

function configure_git() {
    local hooks_dir=$(git config --global core.hooksPath)

    debug "git config --global core.hooksPath=${hooks_dir}\n"
    git config --global core.hooksPath "${GITHOOKSDIR}"
    if [ -n "${hooks_dir}" ] && [ ! "${hooks_dir}" = "${GITHOOKSDIR}" ]; then
        msg "Set core.hooksPath=${GITHOOKSDIR} with git config, but"
        msg "It was configured to ${hooks_dir}"
        msg "Consider copying you scripts to ${GITHOOKSDIR} manually."
    fi
    git config --global hooks.secretsencrypton "sops-inline"
    debug "git config --global hooks.secretsencrypton=$(git config --global hooks.secretsencrypton)\n"
    debug "git config hooks.strictencryption=$(git config --type=bool hooks.strictencryption)\n"
}

v=$(git config --type=bool hooks.secretsencryption-debug)
[ "${v}" = "true" ] && VERBOSE=1
check_tools
get_git_hooks
install_git_hooks
configure_git
