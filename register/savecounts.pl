#!/usr/bin/perl
# $Id: savecounts.pl 2045 2014-02-03 03:27:39Z mwall $
# Copyright 2013 Matthew Wall
#
# scan the database for counts, then save the counts to history database
#
# Run this script periodically to update the historical station counts.

use strict;
use DBI;
use POSIX;

#my $basedir = '/home/content/t/o/m/tomkeffer';
my $basedir = '/var/chroot/home/content/73/4094873';

# dbinfo
my $dbhost = '45.40.164.85';
my $dbuser = 'weereg';
my $dbpass = 'Worldofweewx#1';
my $db = 'weereg';

# how long ago do we consider stale, in seconds
my $stale = 2_592_000; # 30 days

# format for logging
my $DATE_FORMAT_LOG = "%b %d %H:%M:%S";

while($ARGV[0]) {
    my $arg = shift;
    if ($arg eq '--stale') {
        $stale = shift;
    }
}

# query the station database for the current data
my %stations;
my $errmsg = q();
my $dbh = DBI->connect("dbi:mysql:$db:host=$dbhost", $dbuser, $dbpass, { RaiseError => 0 });
if ($dbh) {
    my $sth = $dbh->prepare("select station_url,station_type,last_seen from stations group by station_url, last_seen");
    if ($sth) {
	$sth->execute();
	$sth->bind_columns(\my($url,$st,$ts));
	while($sth->fetch()) {
	    my %r;
	    $r{station_type} = $st;
	    $r{last_seen} = $ts;
	    $stations{$url} = \%r;
	}
	$sth->finish();
	undef $sth;
    } else {
	$errmsg = "cannot prepare select statement: $DBI::errstr";
	logerr($errmsg);
	exit 1;
    }
    $dbh->disconnect();
    undef $dbh;
} else {
    $errmsg = "cannot connect to database: $DBI::errstr";
    logerr($errmsg);
    exit 1;
}

# massage the counts into hashed active/stale lists
my $now = time;
my %active = ('total',0);
my %stale  = ('total',0);
while( my($url,$rec) = each %stations) {
    my $st = $rec->{station_type};
    $active{$st} = 0 if ! defined $active{$st};
    $stale{$st} = 0 if ! defined $stale{$st};
    if($rec->{last_seen} > $now - $stale) {
        $active{$st} += 1;
        $active{'total'} += 1;
    } else {
        $stale{$st} += 1;
        $stale{'total'} += 1;
    }
}

#for my $k (keys %active) {
#    my $tot = $active{$k} + $stale{$k};
#    print "$k: $tot $active{$k} $stale{$k}\n";
#}

# save to the history database the following:
# timestamp, hardware, active, stale

my @latestrecords;
my $dbh = DBI->connect("dbi:mysql:$db:host=$dbhost", $dbuser, $dbpass, { RaiseError => 0 });
if ($dbh) {

    # create the history database if it does not yet exist
    my $rc = 0;

    # get the latest counts from the history database
    my $sth = $dbh->prepare("select * from history where datetime = (select max(datetime) from history)");
    if ($sth) {
        $sth->execute();
        $sth->bind_columns(\my($ts,$st,$active,$stale));
        while($sth->fetch()) {
            my %r;
            $r{datetime} = $ts;
            $r{station_type} = $st;
            $r{active} = $active;
            $r{stale} = $stale;
            push @latestrecords, \%r;
        }
        $sth->finish();
        undef $sth;
    } else {
        $errmsg = "cannot prepare select statement: $DBI::errstr";
        logerr($errmsg);
        exit 1;
    }

    # see if there are any changes to the counts since the last time we looked
    my $changed = scalar @latestrecords == 0;
    for my $rec (@latestrecords) {
        my $st = $rec->{station_type};
        if($active{$st} != $rec->{active} || $stale{$st} != $rec->{stale}) {
            $changed = 1;
        }
    }

    # save only if new data are different than latest old data
    if($changed) {
        my $cnt = 0;
        for my $k (keys %active) {
            next if $k !~ /\S/;
            my $qs = "insert into history (datetime,station_type,active,stale) values ($now,'$k',$active{$k},$stale{$k})";
            $rc = $dbh->do($qs);
            if(!$rc) {
                $errmsg = 'insert failed: ' . $DBI::errstr;
                logerr($errmsg);
            } else {
                $cnt += 1;
            }
        }
        logout("inserted historical data for $cnt station types");
#    } else {
#        logout("no changes to historical counts");
    }

    $dbh->disconnect();
    undef $dbh;
} else {
    $errmsg = "cannot connect to database: $DBI::errstr";
    logerr($errmsg);
    exit 1;
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
