#!/bin/sh

# uncomment for debugging
#set -x

BASE_SRC=/net/data/rpki/pp
BASE_DST=/net/data/rpki/processed/pp/connect/

PYASN_DAT=/net/data/rpki/pyasn/pyasn.current.dat
PTR_QUERY=/net/data/rpki/bin/ptr-query.py
UPDATE_CSV=/net/data/rpki/bin/update-csv.py

LOG_PARSER=/net/data/rpki/bin/parse-ca.rg.net-rsync.pl
LOG_PROVIDER=ca.rg.net
PROTOCOL=rsync

SRCDIR=${BASE_SRC}/${LOG_PROVIDER}/${PROTOCOL}
DSTDIR=${BASE_DST}/${LOG_PROVIDER}/${PROTOCOL}

WORKDIR=${HOME}/rpkilog
TMPDIR=${WORKDIR}/tmp/${LOG_PROVIDER}/${PROTOCOL}
PIDFILE=${TMPDIR}/${LOG_PROVIDER}.${PROTOCOL}.pid

# if something goes belly up, bail with a msg to stderr
fatal() {
    echo ${1:-unknown fatal error} >&2
    exit 1
}

# ensure output directories are available
if [ ! -d ${DSTDIR} ]
then
    mkdir -p ${DSTDIR} || fatal "Cannot mkdir ${DSTDIR}"
fi

if [ ! -d ${TMPDIR} ]
then
    mkdir -p ${TMPDIR} || fatal "Cannot mkdir ${TMPDIR}"
fi

# make sure we are not already running
if [ -r ${PIDFILE} ]
then
    if [ "$(ps -p `cat ${PIDFILE}` | wc -l)" -gt 1 ]
    then
        fatal "$0 script already running"
        exit 1
    else
        # orphaned pid file
        rm ${PIDFILE}
    fi
fi

echo -n $$ > ${PIDFILE}
if [ ! -r ${PIDFILE} ]
then
    fatal "pidfile creation error: ${PIDFILE}"
fi

# NOTE: ca.rg.net file spec: rsync.log-YYYYMMDD.HHMMSS.gz
#
# get list of files less than 31 days old AND more than 2 days old
SRCFILES=`find ${SRCDIR} -type f -mtime +3 -mtime -30 -name "rsync.log-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9].gz"`

for srcfile in ${SRCFILES}
do
    # NOTE: ca.rg.net file spec: rsync.log-YYYYMMDD.HHMMSS.gz
    _base_file=`basename $srcfile .gz`

    # prepare temporary work files
    _tmp_prefix=${TMPDIR}/${_base_file}
    _tmp_file=${_tmp_prefix}.tmp
    _ptr_file=${_tmp_prefix}.ptr
    _log_file=${_tmp_prefix}.log

    # in case we have stragglers lying around from an incomplete run
    rm ${_tmp_file} rm ${_tmp_file}.updated ${_ptr_file} > /dev/null 2>&1

    _dstprefix=${DSTDIR}/${_base_file}

    if [ ! -f ${_dstprefix}.csv ] && [ ! -f ${_dstprefix}.csv.gz ]
    then
        # first pass csv output
        # TODO: incorporate UPDATE_CSV and PTR_QUERY into LOG_PARSER
        gunzip -c ${srcfile} |
            ${LOG_PARSER} -c -o ${_tmp_file}
        if [ $? -ne 0 ]
        then
             fatal "gunzip -c ${srcfile} | ... failed"
        fi

        # do PTR look ups
        awk -F',' '{print $4}' ${_tmp_file} | grep -Fv saddr | sort | uniq |
            ${PTR_QUERY} -c ${_ptr_file}
        if [ $? -ne 0 ]
        then
             fatal "awk ... ${_tmp_file} ... | ${PTR_QUERY} -c ${_ptr_file} failed"
        fi

        # second pass update csv with ASN and DNS PTR data
        ${UPDATE_CSV} \
          -a ${PYASN_DAT} \
          -d ${_ptr_file} \
          -i ${_tmp_file} \
          -o ${_tmp_file}.updated
        if [ $? -ne 0 ]
        then
             fatal "${UPDATE_CSV} ... -o ${_tmp_file} failed"
        fi

        mv ${_tmp_file}.updated ${_tmp_file}
        rm ${_ptr_file}

        # export csv to influxdb
        export_csv_to_influx \
            -fi True \
            -b 10000 \
            -c ${_tmp_file} \
            -db rpkilog \
            -m connect \
            -tc pp,protocol,asn \
            -fc saddr,file,ptr > ${_log_file}
        if [ $? -ne 0 ]
        then
             fatal "export_csv_to_influx ... -c ${_tmp_file} ... failed"
        fi

        gzip -9 ${_tmp_file} && mv ${_tmp_file}.gz ${_dstprefix}.csv.gz
        if [ $? -ne 0 ]
        then
             fatal "gzip -9 ${_tmp_file} && mv ... failed"
        fi
    fi
done

rm ${PIDFILE}
exit 0
