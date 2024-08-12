#!/bin/bash
#
# Enable global debug
# set -xv

# Redirect stderr to stdout.
# exec 2>&1

if [ $# -eq 0 ]; then
    echo "$0: No parameters given" && exit 1
elif [ $# -eq 1 ]; then
    # Adding new file
    exit 0
fi

for var in path oldfile oldhex oldmode newfile newhex newmode; do
    [ -z "${1+x}" ] && echo "$0: Wrong number of parameters" && exit 1
    eval "${var}=$1"
    shift
done

# echo "Git diff for: $path $oldfile $oldhex $oldmode $newfile $newhex $newmode"

filedirname=$(dirname "${path}")
oldfilename=$(basename "${oldfile}")
newfilename=$(basename "${newfile}")

TEMP_DIR=$(mktemp -d)
mkdir -p ${TEMP_DIR}/{a,b}/"${filedirname}"
if [ "${oldfile}" != "/dev/null" ]; then
    oldfile1="a/${filedirname}/${oldfilename}"
    cp -p "${oldfile}" "${TEMP_DIR}/${oldfile1}"
else
    oldfile1="${oldfile}"
fi
if [ "${newfile}" != "/dev/null" ]; then
    newfile1="b/${filedirname}/${newfilename}"
    cp -p "${newfile}" "${TEMP_DIR}/${newfile1}"
else
    newfile1="${newfile}"
fi

# Do not change working tree: decrypt files only into temporary directory
secretsencrypton=$(git config hooks.secretsencrypton | tr '[:lower:]' '[:upper:]')
if [ "${secretsencrypton}" != "NONE" ]; then
    sops -d "${oldfile}" >/dev/null 2>&1 && sops -d "${oldfile}" >"${TEMP_DIR}/${oldfile1}"
    sops -d "${newfile}" >/dev/null 2>&1 && sops -d "${newfile}" >"${TEMP_DIR}/${newfile1}"
fi

pushd $TEMP_DIR >/dev/null
# echo -e "git --no-pager diff --no-index ${oldfile1} ${newfile1}"
git --no-pager diff --no-index "${oldfile1}" "${newfile1}"
popd >/dev/null
rm -rf $TEMP_DIR
exit 0
