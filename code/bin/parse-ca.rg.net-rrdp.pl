#!/usr/bin/perl -T
use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Text::CSV;
use Time::Piece;

$| = 1;

# -c   enable outfile.csv output
# -d   date only timestamp
# -f   IPv4-only
# -o   outfile
# -s   IPv6-only
# -u   output user-agent

getopts( 'cdfo:su', \my %opts );

my $outfile = 'outfile.csv';
my $basefile; # outfile without path and extension for csv file field
if ($opts{o}) {
    ($outfile) = $opts{o} =~ m{ \A ([a-z0-9_./-]+) \z }igxms;
    $outfile ||= 'outfile.csv';
    ( $basefile, undef, undef ) = fileparse( $outfile, qr/\.[^.]*/ );
}

my $csv = Text::CSV->new( { binary => 1 } );
my $CSVFILE_FH;
if ($opts{c}) {
    die "$outfile already exists" if ( -e $outfile );
    open( $CSVFILE_FH, '>:encoding(utf8)', $outfile )
        or die "Unable to open outfile.csv $!\n";
    $csv->eol("\n");
}

if ( $opts{f} && $opts{s} ) {
    die "IPv4-only and IPv6-only flags cannot be used together";
}

# csv header
if ($opts{c}) {
    my @fields = ( 'pp', 'protocol', 'timestamp', 'saddr', 'ua', 'file' );
    $csv->print( $CSVFILE_FH, \@fields );
}

# 192.0.2.1 - - [10/Mar/2020:02:46:06 +0000] "GET /rrdp/notify.xml HTTP/1.1" 200 5490 "-" "reqwest/0.9.19"

while ( defined(my $line=<>) ) {

    chomp $line;
    # remove any additional trailing white space
    $line =~ s{ \s* \z }{}xms;

    # capture time stamp and rsync source
    next if $line !~ m{ \A
        (\S+) \s
        \S+ \s
        \S+ \s
        [[] (\d{2}) [/] ( Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec ) [/] (\d{4}) [:]
        (\d{2}:\d{2}:\d{2}) \s [-|+]\d{4} []] \s
        # do not care about the status
        ["] GET \s [/]rrdp[/]notify[.]xml \s HTTP[/]\d+[.]\d+["] \s
        \d+ \s   # status
        \d+ \s   # bytes
        \S+ \s   # referer
        ["] ([^\"]+) ["] \z
    }xms;

    my $saddr = $1;
    my $day = $2;
    my $month = $3;
    my $year = $4;
    my $time = $5;
    my $agent = $6;

    # output just IPv4 or IPv6 if requested
    next if $opts{f} && $saddr =~ /:/;
    next if $opts{s} && $saddr !~ /:/;

    my $timestamp = Time::Piece->strptime("$month $day $year $time", '%b %e %Y %T');

    # csv output
    if ($opts{c}) {
        my @fields = ( 'ca.rg.net', 'rrdp', $timestamp->datetime, $saddr, $agent, $basefile );
        $csv->print( $CSVFILE_FH, \@fields );
        next;
    }

    # legacy stdout
    if ($opts{d}) {
        print $timestamp->ymd . " $saddr";
    }
    else {
        print $timestamp->datetime . " $saddr";
    }

    if ($opts{u}) {
        print " $agent\n";
    }
    else {
        print "\n";
    }
}
