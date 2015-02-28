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

my $basedir = '/home/content/t/o/m/tomkeffer';

# location of the log file
my $logfn = "$basedir/html/register/register.log";

# format for filename timestamp
my $DATE_FORMAT_FN = "%Y%m%d.%H%M%S";
my $ts = strftime $DATE_FORMAT_FN, gmtime time;

my $oldfn = $logfn;
my $newfn = "$logfn.$ts";

`mv $oldfn $newfn`;
`touch $oldfn`;
`gzip $newfn`;

exit 0;
