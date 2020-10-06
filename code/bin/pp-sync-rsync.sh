#!/bin/sh

# This script controls RPKI access log fetching from the specified repo.
# It is largely driven by rsync and a repo-specific ssh config file.
# The config file is set to ${HOME}/.ssh/config by default, but can be
# overriden with the -c command line option.  REPO is a mandatory
# command line argument.  A simple, unique name is recommended (e.g.
# afrinic, apnic, arin, lacnic, or ripe).

# uncomment for debugging
#set -x

# non-critical error
warning() {
    echo ${1:-"Unknown error, continuing..."} >&2
}
# critical failure
fatal() {
    echo ${1:-"Unknown failure, exiting..."} >&2
    exit 1
}

usage() {
    echo "$0  [ -c ssh_config ] [ -d dest_dir ] [ -p pidfile ]"
    echo "    [ -r repo_name ] repo_url"
    echo "  -c config       ssh config file        (optional)"
    echo "  -d dest_dir     destination directory  (optional)"
    echo "  -p pidfile      process id file        (optional)"
    echo "  -r repo_name    one of: apnic          (required)"
    echo
    echo "  repo_url        (require)"
    exit 1
}

# parse command line options
while getopts "c:d:p:r:" options
do
    case ${options} in
        c)    SSHCONFIG=${OPTARG}
              ;;
        d)    DESTDIR=${OPTARG}
              ;;
        p)    PIDFILE=${OPTARG}
              ;;
        r)    REPO=${OPTARG}
              ;;
        *)    usage
              ;;
    esac
done
shift `expr ${OPTIND} - 1`

# required arguments and options
URL=${1}
if [ -z "${URL}" ]
then
    usage
fi

if [ -z "${REPO}" ]
then
    usage
fi

if [ -z "${SSHCONFIG}" ]
then
    SSHCONFIG=${HOME}/.ssh/config
fi

if [ -z "${DESTDIR}" ]
then
    DESTDIR=/net/data/rpki/pp/${REPO}
fi

if [ -z "${PIDFILE}" ]
then
    PIDFILE=/run/user/${UID}/rpki-rsync-sync.${REPO}.pid
fi

# abort if this process is already running
if test -r ${PIDFILE}
then
    if [ "$(ps -p `cat ${PIDFILE}` | wc -l)" -gt 1 ]
    then
        fatal "script already running"
    else
        # orphaned lock file
        rm ${PIDFILE}
    fi
fi

# make sure sshconfig file is available
if test ! -r ${SSHCONFIG}
then
    fatal "cannot read ssh config file (${SSHCONFIG})"
fi

# create pid
echo $$ > ${PIDFILE}
if test ! -r ${PIDFILE}
then
    fatal "pid file creation error: ${PIDFILE}"
fi

# generally want group read/write
umask 002

# common rsync arguments and options:
# -a   archive
# -e   ssh and options (-p ssh port, -q quiet mode)
# -r   recursive
# -l   copy symlinks as symlinks
# -m   prune empty directories
# -p   preserve permissions
# -t   preserve modification times
# -o   preserve owner
# -D   preserve devices / special files
# -x   don't cross file system boundaries
# -z   compress files during data transfer
# -O   omit directories from modification times
# --include='*.bz2' --include='*/' --exclude='*' \

rsync -e "ssh -q -F ${SSHCONFIG}" -am ${URL} ${DESTDIR}

_RETURN_VALUE=$?
sleep 1
if [ "${_RETURN_VALUE}" -ne 0 ]
then
    fatal "$0 failed: rsync  -e \"ssh -q -F ${SSHCONFIG}\" -am ${URL} ${DESTDIR}"
fi

# clean up and exit
rm ${PIDFILE}
exit 0
