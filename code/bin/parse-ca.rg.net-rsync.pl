#!/usr/bin/perl -T
use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Text::CSV;

$| = 1;

# -c   enable outfile.csv output
# -d   date only timestamp
# -f   IPv4-only
# -o   outfile
# -s   IPv6-only

getopts( 'cdfo:s', \my %opts );

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
    my @fields = ( 'pp', 'protocol', 'timestamp', 'saddr', 'file' );
    $csv->print( $CSVFILE_FH, \@fields );
}

# 2020/03/31 06:25:22 [8293] rsync on rpki/ from foo.example.net (192.0.2.1)
# rpki-client specific does not include the trailing slash:
# 2020/09/16 06:17:51 [639] rsync on rpki from sobornost.connected.by.freedominter.net (45.155.156.99)

while ( defined(my $line=<>) ) {

    chomp $line;
    # remove any additional trailing white space
    $line =~ s{ \s* \z }{}xms;

    # capture time stamp and rsync source
    next if $line !~ m{ \A
        (\d{4}[/]\d{2}/\d{2}) \s
        (\d{2}[:]\d{2}:\d{2}) \s
        [[]\d+[]] \s
        rsync \s on \s rpki[/]? \s from \s \S+ \s [(] ([^)]+) [)] \z
    }xms;

    my $date = $1;
    my $time = $2;
    my $saddr = $3;

    # output just IPv4 or IPv6 if requested
    next if $opts{f} && $saddr =~ /:/;
    next if $opts{s} && $saddr !~ /:/;

    $date =~ s{ [/] }{-}gxms;
    my $timestamp = $date . 'T' . $time;

    # csv output
    if ($opts{c}) {
        my @fields = ( 'ca.rg.net', 'rsync', $timestamp, $saddr, $basefile );
        $csv->print( $CSVFILE_FH, \@fields );
        next;
    }

    # legacy stdout
    if ($opts{d}) {
        print "$date $saddr\n";
    }
    else {
        print "$timestamp $saddr\n";
    }
}
