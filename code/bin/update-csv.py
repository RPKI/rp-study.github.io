#!/usr/bin/env python3

# this file will take the original connect processed csv and
# add ASN and PTR mappings to a new file for import into influx
# XXX: add a place holder field for ua if none exists?

import argparse
import csv
import datetime
import fileinput
import pyasn
import sys

from collections import defaultdict
ptr_lookup = defaultdict(str)

parser = argparse.ArgumentParser()
parser.add_argument('-a', required=True)        # PyASN .dat file
parser.add_argument('-d', required=True)        # addr to ptr name mapping csvfile
parser.add_argument('-i', required=True)        # original log summary csvfile
parser.add_argument('-o', required=True)        # new output log summary csvfile
parser.add_argument('-u', action='store_true')  # original csv has ua field (rrdp)
args = parser.parse_args()

# load PyASN .dat file into radix tree, provide lookup capability
try:
    asndb = pyasn.pyasn(args.a)
except:
    sys.stderr.write("Failed to import PyAS .dat file: %s" % (args.a))
    sys.exit(1)

# IP address to DNS PTR name mapping (csv file)
# TODO: handle exceptions in opening/reading
with open(args.d, newline='') as csvfile:
    dnsreader = csv.reader(csvfile)
    heaader   = next(dnsreader,None)

    for row in dnsreader:
        if row[1] != "-":         
            ptr_lookup[row[0]] = row[1]

# XXX: it would be better to stick ua field at end since it is likely quoted
if args.u: 
    new_fields = ['pp','protocol','timestamp','saddr','ua','file','asn','ptr']
else:
    new_fields = ['pp','protocol','timestamp','saddr','file','asn','ptr']

with open(args.o, 'w') as csvoutfile:
    writer = csv.writer(csvoutfile)
    writer.writerow(new_fields)      # header

    with open(args.i, newline='') as csvinfile:
        reader = csv.reader(csvinfile)
        header = next(reader,None)

        nano_id = 0
        for row in reader:
            asn = asndb.lookup(row[3])
            ptr = ptr_lookup[row[3]]

            # set tz UTC and convert timestamp to nanoseconds
            row[2] = datetime.datetime.strptime(row[2]+'+0000', '%Y-%m-%dT%H:%M:%S%z').timestamp() * 1000000
            row[2] = row[2] + nano_id

            # hack: influx csv input tool chokes on empty trailing fields
            if not ptr:
                ptr = "-"

            writer.writerow(row + [asn[0],ptr])
            # XXX: wrap if necessary, collisions possible, but should be rare
            if nano_id == 999999:
                nano_id = 0
            else:
                nano_id = nano_id + 1

sys.exit(0)
