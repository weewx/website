#!/usr/bin/perl
# $Id: archivelog.pl 1616 2013-11-05 15:08:42Z mwall $
# Copyright 2013 Matthew Wall
#
# logrollover for the weewx registration system
#
# Run this script periodically to compress the log file.

use strict;
use POSIX;

my $version = '$Id: archivelog.pl 1616 2013-11-05 15:08:42Z mwall $';

#my $basedir = '/home/content/t/o/m/tomkeffer';
my $basedir = '/var/chroot/home/content/73/4094873';

# location of the log file
my $reglogfn = "$basedir/html/register/register.log";
my $caplogfn = "$basedir/html/register/capture.log";

# format for filename timestamp
my $DATE_FORMAT_FN = "%Y%m%d.%H%M%S";
my $ts = strftime $DATE_FORMAT_FN, gmtime time;

rollover($reglogfn);
rollover($caplogfn);

exit 0;


sub rollover {
    my($logfn) = @_;
    my $oldfn = $logfn;
    my $newfn = "$logfn.$ts";
    `mv $oldfn $newfn`;
    `touch $oldfn`;
    `gzip $newfn`;
}
