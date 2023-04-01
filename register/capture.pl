#!/usr/bin/perl
# Copyright 2015-2023 Matthew Wall
#
# Scan the registered stations and get a screen capture for each one.
# If we already have a recent capture, skip it.  If there is no reply, then
# do nothing for that one.  Save as jpg image with name that is hash of the
# identifying url for the station.
#
# Create a thumbnail of each image so that map thumbs do not take forever to
# load.  These are scaled to 50 pixels wide and cropped to 100 pixels tall.
#
# Some captures result in massive (over 100MB) png images.  If that happens,
# punt the image.
#
# Run this script periodically to get screen captures of each station.
# Specify a URL to get a capture of a specific url.
#
# pre-requisites:
#  capture (imagemagick must be available)
#  xvfb
#  weasyprint/wkhtmltoimage/phantomjs/cutycapt
#
# how to use this script:
#
# This script needs an X server in order to operation.  Recommend to keep one
# running all the time like this (or even higher resolution):
#    Xvfb :99 -screen 0 1024x768x24
# then set the DISPLAY before running this script:
#    export DISPLAY=:99
#
# to capture website of each active station:
#   capture.pl
#
# to capture website of a single station:
#   capture.pl --url http://station.example.com
#
# to see all of the options:
#   capture.pl --help
#
# references:
#   https://stackoverflow.com/questions/429254/how-can-i-find-memory-leaks-in-long-running-perl-program
#   https://markandruth.co.uk/2015/12/17/debugging-perl-memory-leaks
#use Devel::Leak::Object qw( GLOBAL_bless );

use Time::HiRes qw(time sleep);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;
use File::Copy;
use POSIX;
use strict;

my $basedir = '/var/www';

# include shared code
require "$basedir/html/register/common.pl";

# which app to use for captures
# weasyprint, phantomjs, cutycapt or wkhtmltoimage
my $capture_app = 'phantomjs';

my $weasyprint = '/opt/anaconda3/bin/weasyprint';
my $wkhtmltox = '/opt/wkhtmltox/bin/wkhtmltoimage';
my $phantomjs = '/usr/bin/phantomjs';
my $cutycapt = '/usr/bin/cutycapt';
my $xvfb = '/usr/bin/xvfb-run --server-args="-screen 0, 1024x768x24"';

# the app that converts and resizes images
my $cvtapp = 'convert';

# where to put the image files
my $imgdir = "$basedir/html/shots";

# extension for captured images
my $imgext = 'jpg';

# should we delete the original capture after making thumbnails?
my $delete_raw = 1;

# how long to wait for process before killing it, in seconds
my $DEFAULT_TIMEOUT = 180;

# dbinfo
my $dbtype = 'mysql';
my $dbinfo = '/etc/weereg/dbinfo';
my $dbhost = 'localhost';
my $dbuser = 'weewx';
my $dbpass = 'weewx';
my $dbname = 'weewx';
my $dbfile = 'history.sdb';

my $dbstr = q();
if ($dbtype eq 'mysql') {
    ($dbhost, $dbname, $dbuser, $dbpass) = read_dbinfo("$dbinfo");
    $dbstr = "dbi:mysql:$dbname:host=$dbhost";
} else {
    $dbstr = "dbi:SQLite:$dbfile";
}

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

# force capture even if not stale
my $force = 0;

# which url should we capture?  default is to query the database then capture
# everything we find.  if a url is specified, then just do that one.
my $url = q();

# should we spit out a log message about every little thing?  if not, then
# log only errors.
my $verbosity = 0;

while($ARGV[0]) {
    my $arg = shift;
    if ($arg eq '--stale') {
        $stale = shift;
    } elsif ($arg eq '--active') {
        $active = shift;
    } elsif ($arg eq '--url') {
        $url = shift;
    } elsif ($arg eq '--verbosity') {
        $verbosity = shift;
    } elsif ($arg eq '--save-captures') {
        $delete_raw = 0;
    } elsif ($arg eq '--force') {
        $force = 1;
    } elsif ($arg eq '--help') {
        print "argument include:\n";
        print "  --stale          how long in seconds to consider stale\n";
        print "  --active         how long to consider stale, in seconds\n";
        print "  --url            process a single image from this url\n";
        print "  --verbosity      1=some, 2=lots\n";
        print "  --save-captures  do not delete the original captures\n";
        exit 0;
    } else {
        print "unknown argument '$arg'\n";
        exit 1;
    }
}

my $logargs = q();
if ($verbosity < 2) {
    $logargs = '> /dev/null 2>&1';
}
my $now = time;
my %stations;
if ($url ne q()) {
    $stations{$url} = 1; # placeholder - all we need is the url as key
} else {
    %stations = get_stations($now);
}
my $FMT = "%b %d %H:%M:%S";
my $tot = keys %stations;
my $cnt = 0;
my $total_time = 0;
foreach my $url (keys %stations) {
    $cnt += 1;
    my $t1 = time;
    my $tstr = strftime $FMT, gmtime $now;
    logout("process '$url' at $tstr ($now) ($cnt of $tot)");
    capture_station($url, $now);
    my $t2 = time;
    $total_time += $t2 - $t1;
}
my $elapsed = time - $now;
my $avg = $total_time;
$avg /= $cnt if $cnt;
logout("processed $cnt sites in $elapsed seconds (${avg}s/site)");

exit 0;


# query the station database for stations.  keep any that are active.
sub get_stations {
    my ($now) = @_;
    my $tot = 0;
    my $cnt = 0;
    my %stations;
    my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, { RaiseError => 0 });
    if ($dbh) {
        # this is a crude approach that no longer works with modern mysql
        #my $sth = $dbh->prepare("select station_url,station_type,last_seen from stations group by station_url, last_seen");
        # do it with an inner join instead
        my $sth = $dbh->prepare("select s.station_url,s.station_type,s.last_seen from stations s inner join (select station_url, max(last_seen) as max_last_seen from stations group by station_url) sm on s.station_url = sm.station_url and s.last_seen = sm.max_last_seen");
	if ($sth) {
	    $sth->execute();
	    $sth->bind_columns(\my($url,$st,$ts));
	    while($sth->fetch()) {
                $tot += 1;
		my %r;
		$r{station_type} = $st;
		$r{last_seen} = $ts;
		if ($now - $ts < $active) {
		    $stations{$url} = \%r;
                    $cnt += 1;
		}
	    }
	    $sth->finish();
	    undef $sth;
	} else {
	    logerr("cannot prepare select statement: $DBI::errstr");
	}
	$dbh->disconnect();
	undef $dbh;
    } else {
	logerr("cannot connect to database: $DBI::errstr");
    }
    logout("found $cnt active stations ($tot total stations)");
    return %stations;
}

# do a capture of the specified url
sub capture_station {
    my ($url, $now) = @_;
    my $ctx = Digest::MD5->new;
    $ctx->add($url);
    my $fn = $ctx->hexdigest;
    my $rfile = "$imgdir/${fn}.raw.$imgext";  # the raw, captured image
    my $ofile = "$imgdir/${fn}.$imgext";      # the downsized image
    my $sfile = "$imgdir/${fn}.sm.$imgext";   # small image
    my $tfile = "$imgdir/${fn}.tn.$imgext";   # thumbnail image
    my %files = ($ofile => $placeholder,
                 $sfile => $placeholder_small,
                 $tfile => $placeholder_thumb);
    my @stats = stat($ofile);

    # if no shot, shot is stale, or shot is just a placeholder, then attempt a
    # capture and make the thumbnails
    if ($force || -l $ofile || ! scalar @stats || $now - $stats[9] > $stale) {
        logout("capture $fn ($url)");
        my $cmd = q();
        if ($capture_app eq 'weasyprint') {
            $cmd = "$weasyprint $url $rfile $logargs";
        } elsif ($capture_app eq 'phantomjs') {
            $cmd = "$phantomjs /var/www/html/register/rasterize.js $url $rfile $logargs";
        } elsif ($capture_app eq 'cutycapt') {
            $cmd = "$cutycapt --url=$url --out=$rfile $logargs";
        } else {
            $cmd = "$wkhtmltox --quiet $url $rfile $logargs";
        }
        #system($cmd);
        capture_or_die($url, $fn, $cmd);

        # for each site we do reduced, small, and thumb images.  if the capture
        # was successful, then create the images.  otherwise, make symlinks to
        # placeholders.
        
	# if we got a successful download, create the derived images
	if (-f $rfile && -s $rfile > 0) {
            # if there are already placeholders, then delete the links
            foreach my $f (keys %files) {
                logout("remove link for $f") if $verbosity;
                unlink $f if -l $f;
            }

	    # shrink to something we can keep
            logout("create image for $fn");
            #`$cvtapp $rfile -resize $snap_width $ofile $logargs`;
            my $cmd = "$cvtapp $rfile -resize $snap_width $ofile $logargs";
            logout("$cmd") if $verbosity;
            system($cmd);
            # create a small version for the pin bubble on the map
            logout("create small image for $fn");
	    #`$cvtapp $rfile -resize $small_width -crop ${small_width}x${small_height}+0+0 $sfile $logargs`;
            $cmd = "$cvtapp $rfile -resize $small_width -crop ${small_width}x${small_height}+0+0 $sfile $logargs";
            logout("$cmd") if $verbosity;
            system($cmd);
	    # create thumbnail that is scaled to standard width and cropped
	    # to standard height so it fits in table nicely
            logout("create thumbnail image for $fn");
            $cmd = "$cvtapp $rfile -resize $thumb_width -crop ${thumb_width}x${thumb_height}+0+0 $tfile $logargs";
            logout("$cmd") if $verbosity;
            system($cmd);
        } else {
            logout("no image for $fn ($url)");
        }

        # do placeholders for any failed files
        foreach my $f (keys %files) {
            if (! -f $f) {
                logout("using placeholder for $f ($url)");
                symlink($files{$f}, $f);
            }
        }

        # remove the raw file now that we are done.  this used to be necessary
        # when wkhtml would create monstrous jpg images.  other capture tools
        # might not be so disk-hungry...
        if (-f $rfile && $delete_raw) {
            logout("delete raw image $rfile") if $verbosity;
            unlink $rfile;
        }
    } else {
        my $age = $now - $stats[9];
        logout("skip $url (age=$age stale=$stale)");
    }
}

# attempt to capture a web site.  if it takes too long, then log it and abort.
sub capture_or_die {
    my($url, $fn, $cmd, $timeout) = @_;
    # default to a sane timeout
    $timeout = $DEFAULT_TIMEOUT unless defined($timeout) && ($timeout > 0);
    logout("$cmd") if $verbosity;
    my($rc, $pid);
    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT" };
      FORK: {
          if ($pid = fork) {
              # parent does this
              # NOOP - parent does nothing in this case
          } elsif (defined $pid) { # $pid is zero
              # child does this
              # execute provided command or die if failure
              if (! exec($cmd)) {
                  logout("cannot run '$cmd': $!");
                  die;
              }
          } elsif ($! =~ /No more processes/) {
              # still in parent: EAGAIN, supposedly recoverable fork error
              logout("fork failed, retry in 5 seconds: $!");
              sleep 5;
              redo FORK;
          } else {
              # unknown fork error
              logout("cannot fork: $!");
              die;
          }
        }

        # set alarm for timeout seconds
        alarm($timeout);
        # block until program is finished
        waitpid($pid, 0);
        # program is finished, disable alarm
        alarm(0);
        # get output of waitpid
        $rc = $?;
    };

    # did eval exit due to alarm?
    if (($@ =~ "^TIMEOUT") || !defined($rc)) {
        # yes - kill the process
        if (! kill(KILL => $pid)) {
            logout("unable to kill $pid ($fn): $!");
            die;
        }
        my $ret = waitpid($pid, 0);
        if (! $ret) {
            logout("unable to reap $pid (ret=$ret) ($fn): $!");
            die;
        }
        # get output of child process
        if ($rc = $?) {
            # exit code is lower byte
            my $exit_code = $rc >> 8;
            # killing signal is lower 7-bits of top byte
            my $signum = $rc & 127;
            # core-dump flag is top bit
            my $dump = $rc & 128;
            logout("child died (pid=$pid hash=$fn url=$url): exit_code=$exit_code kill_signal=$signum dumped_core=$dump");
        }
        # process failed
    } else {
        # process completed successfully
    }
    return $rc
}
