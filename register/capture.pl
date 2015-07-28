#!/usr/bin/perl
# Copyright 2015 Matthew Wall
#
# Scan the registered stations and get a screen capture for each one.
# If we already have a recent capture, skip it.  If there is no reply, then
# do nothing for that one.  Save as png image with name that is hash of the
# identifying url for the station.
#
# Create a thumbnail of each image so that map thumbs do not take forever to
# load.  These are scaled to 300 pixels wide and cropped to 100 pixels tall.
#
# Some captures result in massive (over 100MB) png images.  If that happens,
# punt the image.
#
# Run this script periodically to get screen captures of each station.

use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;
use POSIX;
use strict;

my $basedir = '/home/content/t/o/m/tomkeffer';

# the app that makes the screen captures
my $app = "$basedir/app/wkhtmltox/bin/wkhtmltoimage";

# where to put the image files
my $imgdir = "$basedir/html/shots";

# extension for captured images
my $imgext = 'jpg';

# location of the sqlite database
my $db = "$basedir/weereg/stations.sdb";

# placeholder file when capture is too big to keep
my $placeholder = "$basedir/html/blank-600x200.png";
my $placeholder_small = "$basedir/html/blank-100x100.png";
my $placeholder_thumb = "$basedir/html/blank-50x50.png";

# how long ago do we consider stale, in seconds
my $active = 2_592_000; # older than 30 days is no longer active
my $stale = 604_800; # older than 7 days is stale

# max file size that we permit, in bytes
# godaddy limit is 10G, so that would be about 10000 1MB images
my $max_file_size = 1_048_576; # 1 MB

# sizes for thumbnail, in pixels
my $snap_width = 600;
my $small_width = 100;
my $small_height = 200;
my $thumb_width = 50;
my $thumb_height = 100;

# format for logging
my $DATE_FORMAT_LOG = "%b %d %H:%M:%S";

while($ARGV[0]) {
    my $arg = shift;
    if ($arg eq '--stale') {
        $stale = shift;
    } elsif ($arg eq '--active') {
        $active = shift;
    } elsif ($arg eq '--db') {
        $db = shift;
    }
}

# query the station database for stations.  keep any that are active.
my $now = time;
my %stations;
if (-f $db) {
    my $dbh = DBI->connect("dbi:SQLite:$db", q(), q(), { RaiseError => 0 });
    if ($dbh) {
	my $sth = $dbh->prepare("select station_url,station_type,last_seen from stations group by station_url, last_seen");
	if ($sth) {
	    $sth->execute();
	    $sth->bind_columns(\my($url,$st,$ts));
	    while($sth->fetch()) {
		my %r;
		$r{station_type} = $st;
		$r{last_seen} = $ts;
		if ($now - $ts < $active) {
		    $stations{$url} = \%r;
		}
	    }
            $sth->finish();
            undef $sth;
	} else {
	    logerr("cannot prepare select statement: $DBI::errstr");
            exit 1;
	}
	$dbh->disconnect();
        undef $dbh;
    } else {
	logerr("cannot connect to database: $DBI::errstr");
        exit 1;
    }
} else {
    logerr("no database at $db");
    exit 1;
}

foreach my $k (keys %stations) {
    my $needupdate = 0;
    my $ctx = Digest::MD5->new;
    $ctx->add($k);
    my $fn = $ctx->hexdigest;
    my $ofile = "$imgdir/$fn.$imgext";
    my @stats = stat($ofile);
    # if no shot or shot is stale, do a grab and make the thumbnails
    if (! scalar @stats || $now - $stats[9] > $stale) {
	my $rfile = "$imgdir/$fn.raw.$imgext";
        my $sfile = "$imgdir/$fn.sm.$imgext";
        my $tfile = "$imgdir/$fn.tn.$imgext";
        logout("capture $fn ($k)");
	`$app --quiet $k $rfile`;
	# the raw download is going to be too big to keep
	if (-f $rfile) {
	    # shrink to something we can keep
            logout("create image for $fn");
	    `convert $rfile -resize $snap_width $ofile`;
            # create a small version for the pin bubble on the map
            logout("create small image for $fn");
	    `convert $rfile -resize $small_width -crop ${small_width}x${small_height}+0+0 $sfile`;
	    # create thumbnail that is scaled to standard width and cropped
	    # to standard height so it fits in table nicely
            logout("create thumbnail image for $fn");
	    `convert $rfile -resize $thumb_width -crop ${thumb_width}x${thumb_height}+0+0 $tfile`;
            my %files = ($ofile => $placeholder,
                         $sfile => $placeholder_small,
                         $tfile => $placeholder_thumb);
            foreach my $f (keys %files) {
                my @stats = stat($f);
                if ($stats[7] > $max_file_size || $stats[7] == 0) {
                    `cp $files{$f} $f`;
                }
            }
            # remove the raw file now that we are done
            unlink $rfile;
	} else {
            # copy placeholder if the capture failed, but only if none already
            logout("using placeholder for $fn");
            `cp $placeholder $ofile` if ! -f $ofile;
            `cp $placeholder_small $sfile` if ! -f $sfile;
            `cp $placeholder_thumb $tfile` if ! -f $tfile;
        }
    }
}

exit 0;


sub logout {
    my ($msg) = @_;
    my $tstr = strftime $DATE_FORMAT_LOG, gmtime time;
    print STDOUT "$tstr $msg\n";
}

sub logerr {
    my ($msg) = @_;
    my $tstr = strftime $DATE_FORMAT_LOG, gmtime time;
    print STDERR "$tstr $msg\n";
}
