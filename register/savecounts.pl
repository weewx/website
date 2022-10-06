#!/usr/bin/perl
# $Id: savecounts.pl 2045 2014-02-03 03:27:39Z mwall $
# Copyright 2013 Matthew Wall
#
# scan the database for counts, then save the counts to history database
#
# Run this script periodically to update the historical counts.  It tries to
# be smart - it will only update counts if they are different from previous.
#
# required setup:
# as root db user, create the database and grant permissions.  for
# example, with a databased named 'weewx' and user named 'weewx':
#
#  create database weewx;
#  grant create, select, insert, update on weewx.* to weewx;


use strict;
use DBI;
use POSIX;

my $basedir = '/var/www';

# include shared code
require "$basedir/html/register/common.pl";

# dbinfo
my $dbtype = 'mysql';
my $dbinfo = '/etc/weereg/dbinfo';
my $dbhost = 'localhost';
my $dbuser = 'weewx';
my $dbpass = 'weewx';
my $dbname = 'weewx';
my $dbfile = 'history.sdb';

# how long ago do we consider stale, in seconds
my $STALE = 2_592_000; # 30 days

while($ARGV[0]) {
    my $arg = shift;
    if ($arg eq '--stale') {
        $STALE = shift;
    } elsif ($arg eq '--dbtype') {
        $dbtype = shift;
    } elsif ($arg eq '--dbfile') {
        $dbfile = shift;
        $dbtype = 'sqlite';
    } elsif ($arg eq '--dbinfo') {
        $dbinfo = shift;
        $dbtype = 'mysql';
    } elsif ($arg eq '--help') {
        print "options include:\n";
        print "  --stale    how along ago to consider stale, in seconds\n";
        print "  --dbfile   sqlite database file\n";
        print "  --dbinfo   file with database connection info\n";
        exit 0;
    } else {
        print "unknown option $arg\n";
        exit 1;
    }
}

my $dbstr = q();
if ($dbtype eq 'mysql') {
    ($dbhost, $dbname, $dbuser, $dbpass) = read_dbinfo("$dbinfo");
    $dbstr = "dbi:mysql:$dbname:host=$dbhost";
} else {
    $dbstr = "dbi:SQLite:$dbfile";
}

# query the station database for the latest data for each url
my %stations;
my $errmsg = q();
my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, { RaiseError => 0 });
if ($dbh) {
    #my $sth = $dbh->prepare("select station_url,any_value(station_type),last_seen from stations group by station_url, last_seen");
    my $sth = $dbh->prepare("select s.station_url,s.station_type,s.weewx_info,s.python_info,s.platform_info,s.config_path,s.last_seen from stations inner join(select station_url, max(last_seen) as max_last_seen from stations group by station_url) sm on s.station_url = sm.station_url and s.last_seen = sm.max_last_seen");
    if ($sth) {
	$sth->execute();
	$sth->bind_columns(\my($url,$st,$wi,$pi,$oi,$cp,$ts));
	while($sth->fetch()) {
	    my %r;
	    $r{station_type} = $st;
            $r{weewx_info} = $wi;
            $r{python_info} = $pi;
            $r{platform_info} = $oi;
            $r{config_path} = $cp;
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

# associate table names with each of the database fields
my %attrs = (
    'station_type' => 'history',
    'weewx_info' => 'weewx_history',
    'python_info' => 'python_history',
    'platform_info' => 'platform_history',
    'config_path' => 'config_path_history'
);

# massage the counts into hashed active/stale lists
my $now = time;
my %active;
my %stale;
for my $attr (keys %attrs) {
    my %a = ('total', 0);
    my %s = ('total', 0);
    while( my($url,$rec) = each %stations) {
        my $st = $rec->{$attr};
        $a{$st} = 0 if ! defined $a{$st};
        $s{$st} = 0 if ! defined $s{$st};
        if($rec->{last_seen} > $now - $STALE) {
            $a{$st} += 1;
            $a{'total'} += 1;
        } else {
            $s{$st} += 1;
            $s{'total'} += 1;
        }
    }
    $active{$attr} = \%a;
    $stale{$attr} = \%s;
}

#for my $k (keys %active) {
#    my $tot = $active{$k} + $stale{$k};
#    print "$k: $tot $active{$k} $stale{$k}\n";
#}

for my $attr (keys %attrs) {
    save_counts($attr, $attrs{$attr});
}

exit 0;


# save to the history database the following:
# timestamp, attribute, active, stale
sub save_counts {
    my ($attr, $tbl) = @_;

    my @latestrecords;
    my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, { RaiseError => 0 });
    if ($dbh) {
        # FIXME: create table if it does not yet exist
        my $sth = $dbh->prepare("CREATE TABLE IF NOT EXISTS $tbl (datetime INT NOT NULL, $attr VARCHAR(256) NOT NULL, active INT NOT NULL, stale INT NOT NULL)");
        if ($sth) {
            $sth->execute();
        } else {
            $errmsg = "cannot execute create table: $DBI::errstr";
            logerr($errmsg);
            return;
        }

        # get the latest counts from the history database
        $sth = $dbh->prepare("select * from $tbl where datetime = (select max(datetime) from $tbl)");
        if ($sth) {
            $sth->execute();
            $sth->bind_columns(\my($ts,$v,$av,$sv));
            while($sth->fetch()) {
                my %r;
                $r{datetime} = $ts;
                $r{$attr} = $v;
                $r{active} = $av;
                $r{stale} = $sv;
                push @latestrecords, \%r;
            }
            $sth->finish();
            undef $sth;
        } else {
            $errmsg = "cannot prepare select statement: $DBI::errstr";
            logerr($errmsg);
            return;
        }

        my %a = %{$active{$attr}};
        my %s = %{$stale{$attr}};

        # see if there are any changes to the counts since the last time
        my $changed = scalar @latestrecords == 0;
        for my $rec (@latestrecords) {
            my $v = $rec->{$attr};
            if($a{$v} != $rec->{active} || $s{$v} != $rec->{stale}) {
                $changed = 1;
            }
        }

        # save only if new data are different than latest old data
        if($changed) {
            my $cnt = 0;
            for my $k (keys %a) {
                next if $k !~ /\S/;
                my $qs = "insert into $tbl (datetime,$attr,active,stale) values ($now,'$k',$a{$k},$s{$k})";
                my $rc = $dbh->do($qs);
                if(!$rc) {
                    $errmsg = 'insert failed: ' . $DBI::errstr;
                    logerr($errmsg);
                } else {
                    $cnt += 1;
                }
            }
            logout("inserted historical data for $cnt $attr");
#        } else {
#            logout("no changes to historical counts");
        }

        $dbh->disconnect();
        undef $dbh;
    } else {
        $errmsg = "cannot connect to database: $DBI::errstr";
        logerr($errmsg);
        return;
    }
}

exit 0;
