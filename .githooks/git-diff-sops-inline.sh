#!/bin/bash
# (SPDX-License-Identifier: MIT)
#
# Script to apply `git diff` to encrypted secret files in index.
# To be called only for files in .gitattributes with diff option.
# This file should be pointed at by `git config --global diff.sops.command`.
#
# This file will be called with 7 (seven) parameters, see https://git-scm.com/docs/git#_git_diffs
# See also README-secretsencrypton.md for more info.
#
# Enable global debug
# set -xv
set -uo pipefail

export ERROR_CODE=0
export TMP_FILE="$(mktemp)"
export TMP_DIR="$(mktemp -d)"

trap cleanup EXIT SIGHUP SIGINT SIGQUIT SIGTERM

function cleanup() {
    rm -fr "$TMP_FILE"
    rm -fr "$TMP_DIR"
    exit $ERROR_CODE
}

# Source common functions
. $(dirname $0)/global_functions.sh

# Redirect stderr to stdout, so errors will be visible in pager mode
exec 2>&1

# https://github.com/timaliev/git-secrets-encryption/issues/3
VERBOSE=0
check_debug

debug "TMP_DIR=$TMP_DIR\n"
debug "TMP_FILE=$TMP_FILE\n"

if [ $# -eq 0 ]; then
    msg_exit "No parameters given" 1
elif [ $# -eq 1 ]; then
    # Adding new file
    exit 0
fi

for var in path oldfile oldhex oldmode newfile newhex newmode; do
    [ -z "${1+x}" ] && msg_exit "Wrong number of parameters" 1
    eval "${var}=$1"
    shift
done

debug "Git diff for: $path $oldfile $oldhex $oldmode $newfile $newhex $newmode\n"

filedirname=$(dirname "${path}")
oldfilename=$(basename "${oldfile}")
newfilename=$(basename "${newfile}")

mkdir -p ${TMP_DIR}/{a,b}/"${filedirname}"
if [ "${oldfile}" != "/dev/null" ]; then
    if [ "${filedirname}" = "." ]; then
        oldfile1="a/${oldfilename}"
    else
        oldfile1="a/${filedirname}/${oldfilename}"
    fi
    cp -p "${oldfile}" "${TMP_DIR}/${oldfile1}"
else
    oldfile1="${oldfile}"
fi
if [ "${newfile}" != "/dev/null" ]; then
    if [ "${filedirname}" = "." ]; then
        newfile1="b/${newfilename}"
    else
        newfile1="b/${filedirname}/${newfilename}"
    fi
    cp -p "${newfile}" "${TMP_DIR}/${newfile1}"
else
    newfile1="${newfile}"
fi

# Do not change working tree: decrypt files only into temporary directory
secretsencrypton=$(git config hooks.secretsencrypton | tr '[:lower:]' '[:upper:]')
if [ "${secretsencrypton}" != "NONE" ]; then
    sops -d "${oldfile}" >/dev/null 2>&1 && sops -d "${oldfile}" >"${TMP_DIR}/${oldfile1}"
    sops -d "${newfile}" >/dev/null 2>&1 && sops -d "${newfile}" >"${TMP_DIR}/${newfile1}"
fi

pushd $TMP_DIR >/dev/null
debug "git --no-pager diff --no-index ${oldfile1} ${newfile1}\n"
git --no-pager diff --no-index "${oldfile1}" "${newfile1}"
popd >/dev/null
exit 0
