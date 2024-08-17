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

function compare_semantic_versions() {
    # Compare semantic versions in the x.y.z form
    # Return:
    #   0 if versions are equal
    #   1 if version1 is grater the version2
    #   2 if version2 is grater the version1
    #   127 if arguments are wrong
    local version1
    local version2
    # Error if exactly two arguments are not present
    [ -z "${1+x}" ] && return 127
    version1=$1
    [ -z "${2+x}" ] && return 127
    version2=$2
    # Error if any argument is not in the semantic version form
    [ -z "$(echo $version1 | grep -E '^\d+\.\d+\.\d+$')" ] && return 127
    [ -z "$(echo $version2 | grep -E '^\d+\.\d+\.\d+$')" ] && return 127
    local major1=$(echo ${version1} | cut -d'.' -f 1 )
    local major2=$(echo ${version2} | cut -d'.' -f 1 )
    local minor1=$(echo ${version1} | cut -d'.' -f 2 )
    local minor2=$(echo ${version2} | cut -d'.' -f 2 )
    local patch1=$(echo ${version1} | cut -d'.' -f 3 )
    local patch2=$(echo ${version2} | cut -d'.' -f 3 )

    [ ${major1} -gt ${major2} ] && return 1
    [ ${major2} -gt ${major1} ] && return 2
    [ ${minor1} -gt ${minor2} ] && return 1
    [ ${minor2} -gt ${minor1} ] && return 2
    [ ${patch1} -gt ${patch2} ] && return 1
    [ ${patch2} -gt ${patch1} ] && return 2
    return 0
}

function check_git() {
    local status
    local minimal_git_version="2.9.0"
    local git_version="$(git --version | cut -d' ' -f3)"

    debug "Minimal git version needed: ${minimal_git_version}. Checking... "
    compare_semantic_versions ${minimal_git_version} ${git_version}
    status=$?
    [ ${status} -eq 127 ] && msg_exit "check_git(): Version comparison error"
    [ ${status} -eq 1 ] && msg_exit "Need git version at least ${minimal_git_version} -> found git version ${git_version}. Please upgrade you Git installation."
    debug "got ${git_version} -- OK\n"
}

function check_sops() {
    local status
    local minimal_sops_version="3.0.0"
    local sops_version="$(sops --version | cut -d' ' -f2)"

    debug "Minimal sops version needed: ${minimal_sops_version}. Checking... "
    compare_semantic_versions ${minimal_sops_version} ${sops_version}
    status=$?
    [ ${status} -eq 127 ] && msg_exit "check_sops(): Version comparison error"
    [ ${status} -eq 1 ] && msg_exit "Error: Need sops version at least ${minimal_sops_version} -> found sops version ${sops_version}. Please upgrade you sops installation."
    debug "got ${sops_version} -- OK\n"
    return 0
}

function check_yq() {
    local status
    local minimal_yq_version="1.0.0"
    local yq_version="$(yq --version | cut -d' ' -f4 | tr -d v )"

    debug "Minimal yq version needed: ${minimal_yq_version}. Checking... "
    compare_semantic_versions ${minimal_yq_version} ${yq_version}
    status=$?
    [ ${status} -eq 127 ] && msg_exit "check_yq(): Version comparison error"
    [ ${status} -eq 1 ] && msg_exit "Error: Need yq version at least ${minimal_yq_version} -> found yq version ${yq_version}. Please upgrade you yq installation."
    debug "got ${yq_version} -- OK\n"
    return 0
}

function check_tools() {
# https://github.com/timaliev/git-secrets-encryption/issues/4
    check_git
    check_sops
    check_yq
}

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
    git config --global diff.sops.command "{$HOME}/${GITHOOKSDIR}/git-diff-sops-inline.sh"
    debug "git config diff.sops.command=$(git config --global diff.sops.command)\n"
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
