#!/bin/sh

ARCHIVE_DIR=/net/data/rpki/pyasn/archive

# remove any MRT/RIB and PyASN .dat files older than about 30 days
#   e.g. rib.20200610.0200.bz2  rib.20200610.0200.dat
find ${ARCHIVE_DIR} -type f -name "rib.*" -mtime +30 -print | xargs rm 2> /dev/null
