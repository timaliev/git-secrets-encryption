#!/bin/bash
# (SPDX-License-Identifier: MIT)
#
# Common functions to be sourced and used in git hooks
#
# set -xv
# VERBOSE=1

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

is_sops_encryption_working() {
    echo '{"key": "value"}' | sops -e /dev/stdin >/dev/null 2>&1
    status=$?
    if [ $status -ne 0 ]; then
        debug "Error: Cannot use sops encryption -- sops misconfigured.\n"
    else
        debug "sops encryption works OK.\n"
    fi
    return ${status}
}

is_encryption_working() {
    local secretsencrypton

    secretsencrypton="$(git config hooks.secretsencrypton | tr '[:lower:]' '[:upper:]')"
    debug "is_encryption_working(): secretsencrypton=${secretsencrypton}\n"
    if [ "${secretsencrypton}" = "SOPS-INLINE" ]; then
        is_sops_encryption_working
        return
    else
        return 127
    fi
}

function is_encrypted() {
    local file
    local status
    # Internal error if no parameter given
    [ -z "${1+x}" ] && return 127
    file=$1

    if [ -f "$file" ]; then
        # Try to decrypt file silently
        sops -d $file >/dev/null 2>&1
        status=$?
        if [ $status -eq 0 ]; then
            # Encrypted
            return 0
        elif [ $status -eq 128 ]; then
            # Encrypted but cannot be decrypted
            return 1
        else
            # Not encrypted / recognized
            return 2
        fi
    else
        # Internal error if no such file
        msg "is_encrypted(): No such file: $file"
        return 127
    fi
}

strict_encryption_check() {
    local strictencryption=$(git config --type=bool hooks.strictencryption)

    [ -z "${strictencryption+x}" ] && strictencryption="true"
    if [ "${strictencryption}" == "true" ]; then
        cat <<EOF

Warning: strict encryption policy is set.
It means every encryption attempt must be successful.
Check your SOPS configuration and/or .sops.yaml files.

See README-secretsencrypton.md for more info.
See also SOPS documentation: https://github.com/getsops/sops/blob/main/README.rst

You can disable strict encryption policy for this repository using:

    git config hooks.strictencryption false

Use --global option to make this default configuration.
EOF
        return 1
    fi
    return 0
}

function add_to_gitattributes() {
    local file
    local status
    local secretsencrypton
    # Internal error if no parameter given
    [ -z "${1+x}" ] && return 127
    file=$1
    secretsencrypton=$(git config hooks.secretsencrypton | tr '[:lower:]' '[:upper:]')

    debug "Adding diff line for $file into .gitattributes...\n"
    if [ -f .gitattributes ]; then
        if grep "^${file} diff=" .gitattributes; then
            debug "\n$file already in .gitattributes line #$(grep -n "^${file} diff=" .gitattributes | cut -d: -f1)\n"
            return 0
        fi
    fi
    if [ "${secretsencrypton}" == "SOPS-INLINE" ]; then
        debug "$file diff=sops\n"
        echo -ne "\n$file diff=sops" >>.gitattributes
    fi
}

function remove_from_gitattributes() {
    local file
    local status
    # Internal error if no parameter given
    [ -z "${1+x}" ] && return 127
    file=$1

    if [ ! -f .gitattributes ]; then
        debug "No .gitattributes file found\n"
        return 127
    fi
    ln_count=$(grep -nE "^${file} diff=" .gitattributes | cut -d: -f1 | wc -l)
    if [ ${ln_count} -eq 0 ]; then
        debug "No diff line for $file found in .gitattributes\n"
    else
        file_slash_escaped=$(echo $file | sed 's/\//\\\//g')
        sed -E -i '' -e "/^${file_slash_escaped} diff=/d" .gitattributes
    fi
}

debug "Sourced common functions for git hooks\n"
# set +xv