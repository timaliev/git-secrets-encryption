#!/bin/bash
# (SPDX-License-Identifier: MIT)
#
# Setup secrets encryption for git
# Can be enabled globally or per repository
# See https://github.com/timaliev/git-secrets-encryption/ for more info
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
    rm -fr "$TMP_FILE"
    rm -fr "$TMP_DIR"
    exit $ERROR_CODE
}

. $(dirname $0)/.githooks/global_functions.sh

function get_git_hooks() {
    git clone https://github.com/timaliev/git-secrets-encryption.git ${TMP_DIR}
    [ $? -ne 0 ] && msg_exit "Error cloning Github repository" 127
}

function install_git_hooks() {
    local datetime=$(date -Iseconds)
    local hooks_version
    local new_hooks_version

    if [ -d "${GITHOOKSDIR}" ]; then
        debug "Git hooks dir ${GITHOOKSDIR} exists\n"
        if [ -f "${GITHOOKSDIR}"/VERSION ]; then
            debug "Git hooks version file ${GITHOOKSDIR}/VERSION exists\n"
            hooks_version="$(cat ${GITHOOKSDIR}/VERSION | grep -E '^\d+\.\d+\.\d+$')"
            new_hooks_version="$(cat ${TMP_DIR}/VERSION | grep -E '^\d+\.\d+\.\d+$')"
            debug "Installed version: ${hooks_version} New version: ${new_hooks_version}\n"
            if [ -n "${hooks_version}" ] && [ -n "${new_hooks_version}" ]; then
                compare_semantic_versions ${hooks_version} ${new_hooks_version}
                status=$?
                [ ${status} -ne 2 ] && \
                    msg_exit "Installed hooks version ${hooks_version} is not less then hooks version to be installed ${new_hooks_version}. Cannot continue, please resolve this manually."
            else
                debug "Error checking git hooks versions. Overwriting installation.\n"
            fi
        fi
        mv "${GITHOOKSDIR}" "${GITHOOKSDIR}.${datetime}"
        msg "Moved your existing ${GITHOOKSDIR} to ${GITHOOKSDIR}.${datetime}"
        msg "Consider copying you existing scripts to ${GITHOOKSDIR} manually."
    fi
    mkdir "${GITHOOKSDIR}" && chmod 755 "${GITHOOKSDIR}"
    mv $TMP_DIR/.githooks/* "${GITHOOKSDIR}"
    mv $TMP_DIR/LICENSE "${GITHOOKSDIR}"
    mv $TMP_DIR/VERSION "${GITHOOKSDIR}"
    mv $TMP_DIR/example.secretsencryption-sops.yaml "${GITHOOKSDIR}"
    mv $TMP_DIR/README.md "${GITHOOKSDIR}/README-secretsencrypton.md"
}

function configure_git() {
    local hooks_dir=$(git config --global core.hooksPath)

    debug "git config --global core.hooksPath=${hooks_dir}\n"
    git config --global core.hooksPath "${GITHOOKSDIR}"
    if [ -n "${hooks_dir}" ] && [ ! "${hooks_dir}" = "${GITHOOKSDIR}" ]; then
        msg "Set core.hooksPath=${GITHOOKSDIR} with git config, but"
        msg "it was configured to ${hooks_dir}"
        msg "Consider copying you scripts to ${GITHOOKSDIR} manually."
    fi
    git config --global hooks.secretsencrypton "sops-inline"
    debug "git config --global hooks.secretsencrypton=$(git config --global hooks.secretsencrypton)\n"
    debug "git config hooks.strictencryption=$(git config --type=bool hooks.strictencryption)\n"
}

v=$(git config --type=bool hooks.secretsencryption-debug)
[ "${v}" = "true" ] && VERBOSE=1
debug "TEMP_DIR=$TMP_DIR\n"
debug "TEMP_FILE=$TMP_FILE\n"

# Sourced global function
check_tools

get_git_hooks
install_git_hooks
configure_git
