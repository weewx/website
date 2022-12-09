#!/usr/bin/perl
# Copyright 2013-2022 Matthew Wall
#
# register/update a weewx station via GET or POST request
#
# This CGI script takes requests from weewx stations and registers them into
# a database.
#
# Data are saved to a database.  The database contains a few tables.  The
# stations table is the primary table - it tracks the state changes of each
# station.  The history tables track the count of each attribute over time.
#
# If the database does not exist, one will be created with empty tables.
#
# The station_url is used to uniquely identify a station.
#
# If the station has never been seen before, a new record is added.  If the
# station has been seen, then a field is updated with the timestamp of the
# request.
#
# The stations table keeps track of the *state* of each station, so it has a
# compound index that includes every column but last_seen.  The result is a
# record for each state (consisting of every column but last_seen) reported by
# each station (identified by station_url).
#
# The counts in each history table are made based on the current states in the
# stations table.
#
# Some lore...
# When I first created this system, we had no shell access to the system on
# which the registration was running.  As a result, this cgi script served as
# the entry point to manage all of the aspects of the registration system:
#  - rollover the log files
#  - generate a summary report of station data
#  - generate the stations html page (explicitly, or after each registration)
#  - explicitly generate thumbnails or refresh thumbnails
#  - update the counts in the history tables
# When weewx.com moved to a lightsail instance, the cgi script was no longer
# necessary for these functions - they were moved to crontabs and logrotate.
#
# FIXME: should we have a field for first_seen?
# FIXME: consolidate duplicated db settings and imgdir and md5 codes

use Digest::MD5 qw(md5 md5_hex md5_base64);
use POSIX;
use strict;

my $version = '0.16';

# set maintenance mode when you want to disable all database access.  this is
# useful when you are doing database manipulations and you do not want any
# modifications coming in from any clients.
my $maintenance_mode = 1;

my $basedir = '/var/www';

# include shared code
require "$basedir/html/register/common.pl";

# whether to generate stations page on each connection.  if this script is not
# used to generate the stations page, then you must run a cron job separately.
my $genhtml = 0;

# whether to save the station counts on each connection.  if this script is not
# used to save the historical counts, then you must run a cron job separately.
my $savecnt = 0;

# whether to capture website image on each connection.  if this script is not
# used to update captures, then you must run a cron job separately.
my $docapture = 0;

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

# location of the html generator
my $genhtmlapp = "$basedir/html/register/mkstations.pl";

# location of the log archiver
my $arclogapp = "$basedir/html/register/archivelog.pl";

# location of the count app
my $savecntapp = "$basedir/html/register/savecounts.pl";

# location of the screen capture app
my $captureapp = "$basedir/html/register/capture.pl";

# where to keep the log files
my $logdir = '/var/log/weereg';

# location of the registration log messages
my $logfile = "$logdir/register.log";

# location of the log messages for this script
my $cgilogfile = "$logdir/cgilog.log";

# location of the station generator log file
my $genlogfile = "$logdir/mkstations.log";

# location of the counts log file
my $cntlogfile = "$logdir/savecounts.log";

# location of the capture log file
my $caplogfile = "$logdir/capture.log";

# where to put the image files
my $imgdir = "$basedir/html/shots";

# format of the date as returned in the html footers
my $DATE_FORMAT = "%Y.%m.%d %H:%M:%S UTC";

# how often can clients update, in seconds
my $max_frequency = 60;

# maximum number of unique URLs registered from any given IP address
my $max_urls = 10;

# how far in the past to consider counts
my $cutoff = time() - 30*24*3600;

# how much should we aggregate the results?
my $default_interval = 4;

# placeholder images until capture can happen
my $imgext = 'jpg';
my $placeholder = "$basedir/html/blank-600x200.png";
my $placeholder_small = "$basedir/html/blank-100x100.png";
my $placeholder_thumb = "$basedir/html/blank-50x50.png";
my %PLACEHOLDERS = (
    ".$imgext" => $placeholder,
    ".sm.$imgext" => $placeholder_small,
    ".tn.$imgext" => $placeholder_thumb,
    );

# parameters that we recognize
my @params = qw(station_url description latitude longitude station_type station_model weewx_info python_info platform_info config_path entry_path);

my $RMETHOD = $ENV{'REQUEST_METHOD'};
if($maintenance_mode) {
    # we are in maintenance mode, respond with a simple explanation
    &writereply('Registration Failed','FAIL',"Server is undergoing maintenance");
} elsif($RMETHOD eq 'GET' || $RMETHOD eq 'POST') {
    my($qs,%rqpairs) = &getrequest;
    if($rqpairs{action} eq 'chkenv') {
        &checkenv();
#    } elsif($rqpairs{action} eq 'genhtml') {
#        &runcmd('generate html', $genhtmlapp);
#    } elsif($rqpairs{action} eq 'arclog') {
#        &runcmd('archive log', $arclogapp);
#    } elsif($rqpairs{action} eq 'getcounts') {
#        &runcmd('save counts', $savecntapp);
#    } elsif($rqpairs{action} eq 'history') {
#        if($rqpairs{bg}) {
#            &history_bg(%rqpairs);
#        } else {
#            &history(%rqpairs);
#        }
    } elsif($rqpairs{action} eq 'summary') {
        &summary(%rqpairs);
    } else {
        &handleregistration(%rqpairs);
    }
} else {
   my %rqpairs;
    &history(%rqpairs);
#    &writereply('Bad Request','FAIL',"Unsupported request method '$RMETHOD'.");
}

exit 0;



# figure out the environment in which we are running
sub checkenv {
    my $title = 'checkenv';
    my $tstr = &getformatteddate();
    &writecontenttype();
    &writeheader($title);
    print STDOUT "<p><strong>$title</strong></p>\n";

    # perl
    my $output = `perl -V`;
    print STDOUT "<pre>\n";
    print STDOUT "$output\n";
    print STDOUT "</pre>\n";

    # web server environment
    print STDOUT "<pre>\n";
    for my $k (keys %ENV) {
        print STDOUT "$k = $ENV{$k}\n";
    }
    print STDOUT "</pre>\n";

    # file systems
    my $df = `df -k`;
    print STDOUT "<pre>\n";
    print STDOUT "$df\n";
    print STDOUT "</pre>\n";

    # databases
    print STDOUT "<pre>\n";
    my $rval = eval "{ require DBI; }"; ## no critic (ProhibitStringyEval)
    if(!$rval) {
        print STDOUT "DBI is not installed\n";
    } else {
        my @drivers = DBI->available_drivers();
        my $dstr = "DBI drivers:";
        foreach my $d (@drivers) {
            $dstr .= " $d";
        }
        print STDOUT "$dstr\n";
    }
    print STDOUT "</pre>\n";

    &writefooter($tstr);
}

sub runcmd {
    my($title, $cmd) = @_;
    my $output = q();

    if(! -f "$cmd") {
        $output = "$cmd does not exist";
    } elsif (! -x "$cmd") {
        $output = "$cmd is not executable";
    } else {
        $output = `$cmd 2>&1`;
    }

    my $tstr = &getformatteddate();
    &writecontenttype();
    &writeheader($title);
    print STDOUT "<p><strong>$title</strong></p>\n";

    print STDOUT "<pre>\n";
    print STDOUT "$cmd\n";
    print STDOUT "</pre>\n";

    print STDOUT "<pre>\n";
    print STDOUT "$output\n";
    print STDOUT "</pre>\n";

    &writefooter($tstr);    
}

sub handleregistration {
    my(%rqpairs) = @_;

    my ($status,$msg,$rec) = registerstation(%rqpairs);
    if($status eq 'OK') {
        &writereply('Registration Complete','OK', $msg, $rec, $rqpairs{debug});
        &set_placeholders($rec->{station_url});
        &updatestations();
        &updatecounts();
        &updatecapture($rec->{station_url});
    } else {
        &writereply('Registration Failed','FAIL', $msg, $rec, $rqpairs{debug});
    }
    my @pairs = ();
    foreach my $key (sort keys %{ $rec }) {
        my $val = $rec->{$key};
        $val =~ s/"/\\"/g;
        $val =~ s/'/\\'/g;
        push @pairs, $key . '=' . $val;
    }
    my $recstr = join(',', @pairs);
    my $fullmsg = "$msg reg={$recstr}";
    logmsg($fullmsg);
}

# set blank placeholders so that the map does not have missing images
sub set_placeholders {
    my($url) = @_;
    my $ctx = Digest::MD5->new;
    $ctx->add($url);
    my $fn = $ctx->hexdigest;
    foreach my $f (keys %PLACEHOLDERS) {
        my $imgfile = "$imgdir/{$fn}${f}";
        if (! -e $imgfile) {
            symlink($PLACEHOLDERS{$f}, $imgfile);
        }
    }
}

# update the stations web page
sub updatestations() {
    if($genhtml) {
        system("$genhtmlapp >> $genlogfile 2>&1 &");
    }
}

# update the counts database
sub updatecounts() {
    if($savecnt) {
        system("$savecntapp >> $cntlogfile 2>&1 &");
    }
}

# update the screen capture for the indicated station
sub updatecapture() {
    my($url) = @_;
    if($docapture) {
        $url =~ s/\'/%27/g;
        $url =~ s/\"/%22/g;
        system("$captureapp --url '$url' >> $caplogfile 2>&1 &");
    }
}

# if this is a new station, add an entry to the database.  if an entry already
# exists, update the last_seen timestamp.
sub registerstation {
    my(%rqpairs) = @_;

    my %rec;
    foreach my $param (@params) {
        $rec{$param} = $rqpairs{$param};
    }
    $rec{last_seen} = time;
    $rec{last_addr} = $ENV{'REMOTE_ADDR'};
    $rec{user_agent} = $ENV{HTTP_USER_AGENT};

    # do not permit stray quotes or other devious characters
    for my $k ('station_url','station_type','description','station_model','weewx_info','python_info','platform_info','config_path','entry_path') {
        my $sanitized = sanitize($rec{$k});
        if($rec{$k} ne $sanitized) {
            logmsg("sanitized $k from '" . $rec{$k} . "' to '" . $sanitized . "'");
            $rec{$k} = $sanitized;
        }
    }

    my @msgs;
    if($rec{station_url} eq q() || $rec{station_url} !~ /\S/) {
        push @msgs, 'station_url must be specified';
    } else {
	if($rec{station_url} =~ /example.com$/) {
	    push @msgs, 'example.com is not a valid station_url';
	}
	if($rec{station_url} =~ /weewx.com$/) {
	    push @msgs, 'weewx.com is not a valid station_url';
	}
	if($rec{station_url} =~ /register.cgi$/) {
	    push @msgs, 'register.cgi is not a valid station_url';
	}
	if($rec{station_url} !~ /^https?:\/\/\S+\.\S+/) {
	    push @msgs, 'station_url is not a proper URL';
	}
    }
    if($rec{station_type} eq q() || $rec{station_type} !~ /\S/) {
        push @msgs, 'station_type must be specified';
    }
    if($rec{latitude} eq q()) {
        push @msgs, 'latitude must be specified';
    } elsif($rec{latitude} =~ /[^0-9.-]+/) {
        push @msgs, 'latitude must be decimal notation, for example 54.234 or -23.5';
    } elsif($rec{latitude} < -90 || $rec{latitude} > 90) {
        push @msgs, 'latitude must be between -90 and 90, inclusive';
    }
    if($rec{longitude} eq q()) {
        push @msgs, 'longitude must be specified';
    } elsif($rec{longitude} =~ /[^0-9.-]+/) {
        push @msgs, 'longitude must be decimal notation, for example 7.15 or -78.535';
    } elsif($rec{longitude} < -180 || $rec{longitude} > 180) {
        push @msgs, 'longitude must be between -180 and 180, inclusive';
    }

    # some people seem to be lax with their station model (hardware_name)
    if(length($rec{station_model}) > 128) {
        $rec{station_model} = substr $rec{station_model}, 0, 126;
    }
    # ensure that the info is not longer than database field length
    if(length($rec{platform_info}) > 128) {
        $rec{platform_info} = substr $rec{platform_info}, 0, 126;
    }

# accept only weewx user agent.  this will reject anything before weewx 2.6
#    if($rec{user_agent} !~ /weewx\//) {
#        push @msgs, 'unsupported registration protocol';
#    }
    if($#msgs >= 0) {
        my $msg = q();
        foreach my $m (@msgs) {
            $msg .= '; ' if $msg ne q();
            $msg .= $m;
        }
        return ('FAIL', "bad registration info: $msg", \%rec);
    }

    my $rval = eval "{ require DBI; }"; ## no critic (ProhibitStringyEval)
    if(!$rval) {
        my $msg = 'bad server configuration: DBI is not installed';
        return ('FAIL', $msg, \%rec);
    }
    my $havesqlite = 0;
    my $havemysql = 0;
    my @drivers = DBI->available_drivers();
    foreach my $d (@drivers) {
        $havesqlite = 1 if $d =~ /^sqlite/i;
        $havemysql = 1 if $d =~ /^mysql/i;
    }
    if($dbtype == 'sqlite' && !$havesqlite) {
        my $msg = 'bad server configuration: DBI::SQLite is not installed';
        return ('FAIL', $msg, \%rec);
    }
    if($dbtype == 'mysql' && !$havemysql) {
        my $msg = 'bad server configuration: DBI::MySQL is not installed';
        return ('FAIL', $msg, \%rec);
    }

    my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, { RaiseError => 0 });
    if (!$dbh) {
        my $msg = 'connection to database failed: ' . $DBI::errstr;
        return ('FAIL', $msg, \%rec);
    }

    my $rc = 0;

    # reject obvious attempts to spam the system

    my $last_seen = 0;
    $last_seen = $dbh->selectrow_array("select max(last_seen) from stations where last_addr=?", undef, ($rec{last_addr}));
    if($rec{last_seen} - $last_seen < $max_frequency) {
        $dbh->disconnect();
        return ('FAIL', "too many updates attempted (last=$last_seen)", \%rec);
    }

    my $urlcount = 0;
    $urlcount = $dbh->selectrow_array("select count(station_url) from (select station_url from stations where last_addr=? group by station_url) as T", undef, ($rec{last_addr}));
    if($urlcount > $max_urls) {
        $dbh->disconnect();
        return ('FAIL', 'too many station URLs from that address', \%rec);
    }

    # if data are different from latest record, save a new record.  otherwise
    # just update the timestamp of the matching record.

    my $sth = $dbh->prepare(q{replace into stations (station_url,description,latitude,longitude,station_type,station_model,weewx_info,python_info,platform_info,config_path,entry_path,last_addr,last_seen) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)});
    if(!$sth) {
        my $msg = 'prepare failed: ' . $DBI::errstr;
        $dbh->disconnect();
        return ('FAIL', $msg, \%rec);
    }
    $rc = $sth->execute($rec{station_url},$rec{description},$rec{latitude},$rec{longitude},$rec{station_type},$rec{station_model},$rec{weewx_info},$rec{python_info},$rec{platform_info},$rec{config_path},$rec{entry_path},$rec{last_addr},$rec{last_seen});
    if(!$rc) {
        my $msg = 'execute failed: ' . $DBI::errstr;
        $dbh->disconnect();
        return ('FAIL', $msg, \%rec);
    }

    $dbh->disconnect();

    return ('OK', 'registration received', \%rec);
}

sub sanitize {
    my($txt) = @_;
    $txt =~ s/\"//g; # no double quotes, since we single quote the js string
    $txt =~ s/\r//g; # no carriage returns
    $txt =~ s/\n//g; # no newlines
    return $txt;
}

sub writereply {
    my($title, $status, $msg, $rec, $debug) = @_;

    my $tstr = &getformatteddate();
    &writecontenttype();
    &writeheader($title);
    print STDOUT "<p><strong>$title</strong></p>\n";
    print STDOUT "<pre>\n";
    print STDOUT "$status: $msg\n";
    print STDOUT "</pre>\n";
    if($rec && $debug) {
        print STDOUT "<pre>\n";
        foreach my $param (@params) {
            print STDOUT "$param: $rec->{$param}\n";
        }
        print STDOUT "last_addr: $rec->{last_addr}\n";
        print STDOUT "last_seen: $rec->{last_seen}\n";
        print STDOUT "user_agent: $rec->{user_agent}\n";
        print STDOUT "\n";
        print STDOUT "HTTP_REQUEST_METHOD: $ENV{HTTP_REQUEST_METHOD}\n";
        print STDOUT "HTTP_REQUEST_URI: $ENV{HTTP_REQUEST_URI}\n";
        print STDOUT "</pre>\n";
    }
    &writefooter($tstr);
}

sub get_summary_data {
    use DBI;
    my @station_info;
    my @platform_info;
    my @python_info;
    my @weewx_info;
    my %station_info_cnt;
    my %platform_info_cnt;
    my %python_info_cnt;
    my %weewx_info_cnt;

    my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, {RaiseError => 0});
    if (!$dbh) {
        return "cannot connect to database: $DBI::errstr";
    }

    my $sth = $dbh->prepare("select station_type,station_model from stations group by station_model");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute();
    $sth->bind_columns(\my($st,$sm));
    while($sth->fetch()) {
        next if($st eq q() || $sm eq q());
        push @station_info, "$st,$sm";
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select weewx_info from stations group by weewx_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute();
    $sth->bind_columns(\my($x));
    while($sth->fetch()) {
        next if($x eq q());
        push @weewx_info, $x;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select python_info from stations group by python_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute();
    $sth->bind_columns(\my($x));
    while($sth->fetch()) {
        next if($x eq q());
        push @python_info, $x;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select platform_info from stations group by platform_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute();
    $sth->bind_columns(\my($x));
    while($sth->fetch()) {
        next if($x eq q());
        push @platform_info, $x;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select station_type,station_model,count(station_type) from stations where last_seen > ? group by station_model");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute($cutoff);
    $sth->bind_columns(\my($st,$sm,$c));
    while($sth->fetch()) {
        next if($st eq q() || $sm eq q());
        $station_info_cnt{"$st,$sm"} = $c;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select weewx_info,count(weewx_info) from stations where last_seen > ? group by weewx_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute($cutoff);
    $sth->bind_columns(\my($x,$y));
    while($sth->fetch()) {
        next if($x eq q());
        $weewx_info_cnt{$x} = $y;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select python_info,count(python_info) from stations where last_seen > ? group by python_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute($cutoff);
    $sth->bind_columns(\my($x,$y));
    while($sth->fetch()) {
        next if($x eq q());
        $python_info_cnt{$x} = $y;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select platform_info,count(platform_info) from stations where last_seen > ? group by platform_info");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute($cutoff);
    $sth->bind_columns(\my($x,$y));
    while($sth->fetch()) {
        next if($x eq q());
        $platform_info_cnt{$x} = $y;
    }
    $sth->finish();
    undef $sth;

    $dbh->disconnect();
    undef $dbh;

    return (q(),
            \@station_info, \@platform_info, \@python_info, \@weewx_info,
            \%station_info_cnt, \%platform_info_cnt, \%python_info_cnt, \%weewx_info_cnt
        );
}

sub summary {
    my(%rqpairs) = @_;

    my($errmsg,
       $sref, $plref, $pyref, $wref,
       $sref_cnt, $plref_cnt, $pyref_cnt, $wref_cnt) = get_summary_data();
    if($errmsg ne q()) {
        &writereply('Database Failure', 'FAIL', $errmsg);
        return;
    }

    my $tstr = &getformatteddate();
    &writecontenttype();
    &writedoctype();
    &writehead('summary');
    print STDOUT "<body>\n";
    my $tstr = &getformatteddate($cutoff);
    print STDOUT "<p>";
    print STDOUT "counts since $tstr";
    print STDOUT "</p>";
    &dump_data('stations', $sref, $sref_cnt);
    &dump_data('weewx', $wref, $wref_cnt);
    &dump_data('python', $pyref, $pyref_cnt);
    &dump_data('platforms', $plref, $plref_cnt);

    &writefooter($tstr);
}

sub dump_data {
    my($title, $dref, $cref) = @_;

    my @data = @$dref;

    print STDOUT "<div>\n";
    print STDOUT "<h2>$title</h2>\n";
    print STDOUT "<table style='font-size:90%'>\n";
    foreach my $x (@data) {
        print STDOUT "<tr>";
        if($cref) {
            my $c = $cref->{$x};
            print STDOUT "<td style='text-align:right'>$c</td>";
        }
        print STDOUT "<td style='padding-left:10px'>$x</td>";
        print STDOUT "</tr>\n";
    }
    print STDOUT "</table>\n";
    print STDOUT "</div>\n";
}

sub get_history_data {
    my($interval) = @_;

    $interval = $default_interval if ! $interval;
    my $tstart = time();

    use DBI;
    my @times;
    my @counts;
    my @stypes;

    logmsg("connect to $dbstr");
    my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, {RaiseError => 0});
    if (!$dbh) {
        my $msg = "cannot connect to database: $DBI::errstr";
	logmsg($msg);
	return $msg;
    }

#    logmsg("prepare select");
    my $sth = $dbh->prepare("select station_type from history group by station_type");
    if (!$sth) {
        my $msg = "cannot prepare select statement: $DBI::errstr";
	logmsg($msg);
	return $msg;
    }
    $sth->execute();
    $sth->bind_columns(\my($st));
    while($sth->fetch()) {
        push @stypes, $st;
    }
    $sth->finish();
    undef $sth;

    $sth = $dbh->prepare("select datetime from history group by datetime order by datetime asc");
    if (!$sth) {
        return "cannot prepare select statement: $DBI::errstr";
    }
    $sth->execute();
    $sth->bind_columns(\my($ts));
    while($sth->fetch()) {
        push @times, $ts;
    }
    $sth->finish();
    undef $sth;

    my $cnt = 0;
    my @newtimes;
    foreach my $t (@times) {
	$cnt += 1;
	next if $cnt % $interval != 0;
	push @newtimes, $t;

	my %c;
	foreach my $s (@stypes) {
	    $c{$s} = 0;
	}
        my $sth = $dbh->prepare("select station_type,active,stale from history where datetime=$t");
        if (!$sth) {
            return "cannot prepare select statement: $DBI::errstr";
        }
        $sth->execute();
        $sth->bind_columns(\my($st,$active,$stale));
        while($sth->fetch()) {
	    $c{$st} = $active;
        }
        $sth->finish();
        undef $sth;
	push @counts, \%c;
    }

    $dbh->disconnect();
    undef $dbh;

    my $elapsed = time() - $tstart;

    return q(), \@newtimes, \@counts, \@stypes, $elapsed;
}

sub history_bg {
    my(%rqpairs) = @_;
    $SIG{CHLD} = 'IGNORE';
    my $pid;
    if(!defined($pid=fork())) {
	&writereply('Fork Failed', 'FAIL', '');
    } elsif($pid == 0) {
	open(my $OLDOUT, '>&', STDOUT);
	open(STDOUT, '>', 'history.html');
	&history(%rqpairs);
	open(STDOUT, '>&', $OLDOUT);
    } else {
	&writereply('Fork Complete', 'OK', '');
    }
}

sub history {
    my(%rqpairs) = @_;

    my $interval = $rqpairs{interval} ? $rqpairs{interval} : $default_interval;

    my($errmsg, $tref, $cref, $sref, $elapsed) = get_history_data($interval);
    if($errmsg ne q()) {
        &writereply('Database Failure', 'FAIL', $errmsg);
        return;
    }

    my @times = @$tref;
    my @counts = @$cref;
    my @stations = @$sref;

    my $width = $rqpairs{width} ? $rqpairs{width} : 1200;
    my $height = $rqpairs{height} ? $rqpairs{height} : 1500;
    my $stacked = $rqpairs{stacked} eq '1' ? '1' : '0';
    my $sequential = $rqpairs{sequential} eq '1' ? '1' : '0';
    my $fill = $rqpairs{fill} eq '1' ? '1' : '0';

    my $tstr = &getformatteddate();
    &writecontenttype();
    print STDOUT <<EoB1;
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>history</title>
  <script>
EoB1

    print STDOUT "var data = {\n";
    print STDOUT "time: [";
    for(my $i=0; $i<scalar(@times); $i++) {
        print STDOUT "," if $i > 0;
        print STDOUT "$times[$i]";
    }
    print STDOUT "],\n";
    print STDOUT "totals: [";
    for(my $i=0; $i<scalar(@times); $i++) {
        print STDOUT "," if $i > 0;
        print STDOUT "$counts[$i]{total}";
    }
    print STDOUT "],\n";
    print STDOUT "stations: [\n";
    foreach my $k (@stations) {
        next if $k eq 'total';
        print STDOUT "{ name: '$k', ";
        print STDOUT "values: [";
        for (my $j=0; $j<scalar(@times); $j++) {
            print STDOUT "," if $j > 0;
            print STDOUT "$counts[$j]{$k}";
        }
        print STDOUT "] },\n";
    }
    print STDOUT "]\n";
    print STDOUT "}\n";

    print STDOUT <<EoB2;
function draw_plot(width, height, stacked, sequential, fill) {
  var colors = [ '#ff0000', '#aa0000', '#660000', '#00aa00', '#005500',
                 '#0000ff', '#0000aa', '#000066', '#000000', '#888800',
                 '#00aaaa', '#008888', '#ff00ff', '#aa00aa', '#660066' ];
  var fills =  [ '#ffaaaa', '#aa7777', '#663333', '#00aa00', '#005500',
                 '#aaaaff', '#5555aa', '#222266', '#dddddd', '#888800',
                 '#00aaaa', '#008888', '#ff00ff', '#aa00aa', '#660066' ];
  var canvas = document.getElementById('history_canvas');
  canvas.width = width;
  canvas.height = height;
  var c = canvas.getContext('2d');
  c.font = '10px sans-serif';
  var hlabelbuf = 80;
  var vlabelbuf = 10;
  var haxisbuf = 20;
  var rpad = 5;
  var ticwidth = 4;
  var voffset = 40;
  var bottom_offset = 200;
  var w = c.canvas.width;
  var h = c.canvas.height;
  var plotw = w - haxisbuf - hlabelbuf;
  var ploth = h - bottom_offset - voffset;
  var maxcnt = 0;
  if(stacked) {
    for(var i=0; i<data.totals.length; i++) {
      if(data.totals[i] > maxcnt) {
        maxcnt = data.totals[i];
      }
    }
  } else {
    for(var i=0; i<data.stations.length; i++) {
      for(var j=0; j<data.stations[i].values.length; j++) {
        if(data.stations[i].values[j] > maxcnt) {
          maxcnt = data.stations[i].values[j];
        }
      }
    }
  }
  var timemin = 9999999999999;
  var timemax = 0;
  for(var i=0; i<data.time.length; i++) {
    if(data.time[i] < timemin) {
      timemin = data.time[i];
    }
    if(data.time[i] > timemax) {
      timemax = data.time[i];
    }
  }
  var sorted = data.stations.sort(sort_by_count);
  var sums = Array(data.time.length);
  for(var i=0; i<sums.length; i++) { sums[i] = 0; }
  for(var i=0; i<sorted.length; i++) {
    for(var j=0; j<data.time.length; j++) {
      sums[j] += sorted[i].values[j];
    }
  }

  var y = ploth / maxcnt;
  var x = plotw / data.time.length;

  var used = Array();
  for(var i=0; i<sorted.length; i++) {
    c.fillStyle = fills[i%colors.length];
    c.strokeStyle = colors[i%colors.length];
    c.beginPath();
    c.moveTo(0, voffset+ploth);
    var xval = 0;
    var yval = 0;
    for(var j=0; j<data.time.length; j++) {
      if(sequential) {
        xval = x * j;
      } else {
        xval = plotw * (data.time[j] - timemin) / (timemax - timemin);
      }
      if(stacked) {
        yval = y * sums[j];
        sums[j] -= sorted[i].values[j];
      } else {
        yval = y * sorted[i].values[j];
      }
      c.lineTo(xval, voffset + ploth - yval);
    }
    if(fill) {
      c.lineTo(xval, voffset+ploth);
      c.fill();
    } else {
      c.stroke();
    }
    var yblk = voffset + ploth - vlabelbuf * Math.round(yval / vlabelbuf);
    while(used[yblk]) {
      yblk += vlabelbuf;
    }
/*    var yblk = voffset + ploth - yval; */
    c.fillStyle = colors[i%colors.length];
    var s = sorted[i].name;
    s += " (" + sorted[i].values[sorted[i].values.length-1] + ")";
    c.fillText(s, plotw+rpad, yblk);
    used[yblk] = 1;
  }

  var now = Math.round((new Date).getTime() / 1000);
  var starttime = data.time[0];

  /* change of accounting */
  var changetime = Math.round((new Date(2014,0,4,0,0,0,0)).getTime() / 1000);
  var v = plotw * (changetime - starttime) / (now - starttime);
  c.strokeStyle = "#dddddd";
  c.beginPath();
  c.moveTo(v+1, voffset);
  c.lineTo(v+1, voffset + ploth);
  c.stroke();

  /* horizontal and vertial axes */
  c.fillStyle = "#000000";
  c.strokeStyle = "#000000";
  c.beginPath();
  c.moveTo(1, voffset);
  c.lineTo(1, voffset+ploth);
  c.lineTo(plotw, voffset+ploth);
  c.stroke();

  /* horizontal axis */
  var inc = 2592000; /* 30 days */
  var last_year = 0;
  for(var t=starttime; t<now; t+=inc) {
    var v = plotw * (t - starttime) / (now - starttime);
    c.strokeStyle = "#dddddd";
    c.beginPath();
    c.moveTo(v+1, voffset);
    c.lineTo(v+1, voffset+ploth);
    c.stroke();
    c.strokeStyle = "#000000";
    c.beginPath();
    c.moveTo(v+1, voffset+ploth);
    c.lineTo(v+1, voffset+ploth+ticwidth);
    c.stroke();
    var d = new Date(t*1000);
    var s = d.getUTCDate() + "." + (d.getUTCMonth()+1);
    c.fillText(s, v+1, voffset+ploth+vlabelbuf+5);
    var this_year = d.getUTCFullYear();
    if(last_year != this_year) {
      c.fillText(d.getUTCFullYear(), v+1, voffset+ploth+2*vlabelbuf+5);
      last_year = this_year;
    }
  }

  /* vertical axis */
  var edge = w - haxisbuf;
  for(var j=0; j*y<ploth; j++) {
    c.beginPath();
    c.moveTo(edge-1, voffset+ploth-j*y);
    c.lineTo(edge-ticwidth, voffset+ploth-j*y);
    if(j%5 == 0) {
      c.lineTo(edge-ticwidth*2, voffset+ploth-j*y);
      c.fillText(j, edge+2, voffset+ploth-j*y);
    }
    c.stroke();
  }

  /* title */
  c.fillStyle = "#000000";
  var sd = new Date(starttime*1000);
  var ed = new Date(now*1000);
  var s = sd.getUTCDate() + "." + (sd.getUTCMonth()+1) + "." + sd.getUTCFullYear();
  s += " to ";
  s += ed.getUTCDate() + "." + (ed.getUTCMonth()+1) + "." + ed.getUTCFullYear();
  c.fillText(s, 10, 30);
  c.font = '20px sans-serif';
  c.fillText('Stations Running WeeWX', 10, 18);
}

function sort_by_name(a,b) {
  if(a.name < b.name)
    return -1;
  if(a.name > b.name)
    return 1;
  return 0;
}

function sort_by_count(a,b) {
  if(a.values[a.values.length-1] < b.values[b.values.length-1])
    return 1;
  if(a.values[a.values.length-1] > b.values[b.values.length-1])
    return -1;
  return 0;
}
  </script>
</head>
<body onload='draw_plot($width,$height,$stacked,$sequential,$fill);'>
<canvas id='history_canvas'></canvas>
<br/>
EoB2

    &writefooter($tstr,$elapsed);
}

sub writecontenttype {
    my($type) = @_;

    $type = "text/html" if $type eq "";
    print STDOUT "Content-type: text/html\n\n";
}

sub writedoctype() {
    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
}

sub writehead() {
    my($title,$style,$script) = @_;

    if(! $style ne q()) {
        $style = "\
<style>\
  body {\
      font-family: Verdana, Arial, Helvetica, sans-serif;\
      font-size: 0.8em;\
    color: #000000;\
  background-color: #ffffff;\
}\
  </style>\
";
    }

    if($script ne q()) {
        $script = "<script>\n$script\n</script>\n";
    }

    print STDOUT <<EoB;
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>$title</title>
$style
$script
</head>
EoB
}

sub writeheader {
    my($title,$head) = @_;

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
    print STDOUT "<html>\n";
    print STDOUT "<head>\n";
    print STDOUT "  <title>$title</title>\n";
    print STDOUT "$head\n";
    print STDOUT "</head>\n";
    print STDOUT "<body>\n";
};

sub writefooter {
    my($mdate,$elapsed) = @_;

    if($mdate) {
        print STDOUT "<p>\n";
        print STDOUT "<small><i>\n";
        print STDOUT "$mdate<br/>\n";
        print STDOUT "register v$version<br/>\n";
	if($elapsed) {
	    print STDOUT "$elapsed seconds<br/>\n";
	}
        print STDOUT "</i></small>\n";
        print STDOUT "</p>\n";
    }

    print STDOUT "\n</body>\n</html>\n";
}

sub getformatteddate {
    my($ts) = @_;
    if(! $ts) {
        $ts = time;
    }
    return strftime $DATE_FORMAT, gmtime $ts;
}

sub getrequest {
    my $request = q();
    if ($ENV{'REQUEST_METHOD'} eq "POST") {
        read(STDIN, $request, $ENV{'CONTENT_LENGTH'});
    } elsif ($ENV{'REQUEST_METHOD'} eq "GET" ) {
        $request = $ENV{'QUERY_STRING'};
    }
    my $delim = ',';
    my %pairs;
    foreach my $pair (split(/[&]/, $request)) {
        $pair =~ tr/+/ /;
        $pair =~ s/%(..)/pack("c",hex($1))/ge;
        my($loc) = index($pair,"=");
        my($name) = substr($pair,0,$loc);
        my($value) = substr($pair,$loc+1);
        if($pairs{$name} eq "") {
            $pairs{$name} = $value;
        } else {
            $pairs{$name} .= "${delim}$value";
        }
    }
    return($ENV{'QUERY_STRING'},%pairs);
}

sub logmsg {
    my ($msg) = @_;
    my $logfile = $cgilogfile;
    my $DATE_FORMAT = "%Y.%m.%d %H:%M:%S";
    my $tstr = strftime $DATE_FORMAT, localtime time;
    if (open(FILE, ">>$logfile")) {
	print FILE "$tstr $msg\n";
	close(FILE);
    } else {
	# nowhere to send the message...
    }
}
