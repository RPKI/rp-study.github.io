#!/usr/bin/env python3

import argparse
import csv
import dns.resolver
import dns.reversename
import fileinput
import sys

my_resolver = dns.resolver.Resolver()

parser = argparse.ArgumentParser()
parser.add_argument('-c')   # csvfile
parser.add_argument('-r')   # resolver
#
# to combine argparse and fileinput from stdin:
#   https://gist.github.com/martinth/ed991fb8cdcac3dfadf7
#
parser.add_argument('files', metavar='FILE', nargs='*', help='files to read, if empty, stdin is used')
args = parser.parse_args()

if args.c:
    try:
        csvfile = open(args.c, 'w', newline='')
    except:
        sys.stderr.write("Unable to %s for writing" % args.c)
        sys.exit(1)
 
    fieldnames = ['address', 'ptr_name']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

if args.r:
    my_resolver.nameservers = [args.r]
else:
    my_resolver.nameservers = ['127.0.0.1', '::1' ]

def get_ptr_answer(addr):
    """
    Return the first PTR name given an IPv4 or IPv6 address
    """

    try: 
        qname = dns.reversename.from_address(addr)
    except:
        return None

    # only take the first one in a set potentially > 1
    try:
        ptr_answer = str(my_resolver.query(qname,"PTR")[0])
    except:
        return None

    if ptr_answer:
        return ptr_answer.lower()
    else:
        return None

# expect IP addrs, one per line
for line in fileinput.input(files=args.files):
    line = line.strip()

    answer = get_ptr_answer(line)

    if not answer:
        answer = '-'

    if args.c:
        writer.writerow({'address' : line, 'ptr_name' : answer})
    else:
        sys.stdout.write('%s,%s\n' % (line, answer))

csvfile.close()
sys.exit(0)
