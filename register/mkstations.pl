#!/usr/bin/perl
# $Id: mkstations.pl 2201 2014-04-30 23:11:40Z mwall $
# Copyright 2013 Matthew Wall
#
# insert fields from database into template html file, resulting in a web page
# with a map and list of stations.
#
# Run this script periodically to update the web page.
#
# thanks to tom christiansen for sorting details:
#  http://www.perl.com/pub/2011/08/whats-wrong-with-sort-and-how-to-fix-it.html

use strict;
use DBI;
use POSIX;
use utf8;

my $version = '0.8';

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

my $dbstr = q();
if ($dbtype eq 'mysql') {
    ($dbhost, $dbname, $dbuser, $dbpass) = read_dbinfo("$dbinfo");
    $dbstr = "dbi:mysql:$dbname:host=$dbhost";
} else {
    $dbstr = "dbi:SQLite:$dbfile";
}

# html template file
my $tmpl = "$basedir/html/register/stations.html.in";

# where to put the results
my $ofile = "$basedir/html/stations.html";

# how long ago do we consider stale, in seconds
my $stale = 2_592_000; # 30 days

# format for web page display
my $DATE_FORMAT_HTML = "%H:%M:%S %d %b %Y UTC";

# get a unicode collator for proper sorting
use Unicode::Collate;
my $keysfile = "allkeys.txt";
my $COLLATOR = Unicode::Collate->new(table=>$keysfile);

# for now keep a blacklist here.  at some point we might have to put this
# into a database.
my %blacklist;
# $blacklist{'spammerdomain.com'} = 1;

# google maps api key
my $apikeyfile = "/etc/weereg/google-maps-api-key";
my $apikey = 'NO_API_KEY_DEFINED';
if (open(KEYFILE, "<$apikeyfile")) {
    while(<KEYFILE>) {
        my $line = $_;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        if ($line =~ /\S+/) {
            $apikey = $line;
        }
    }
    close(KEYFILE);
}

my $s_ts = time;
my $e_ts = $s_ts;

while($ARGV[0]) {
    my $arg = shift;
    if ($arg eq '--template') {
        $tmpl = shift;
    } elsif ($arg eq '--stale') {
        $stale = shift;
    } elsif ($arg eq '--ofile') {
        $ofile = shift;
    }
}

my $tmpfile = "$ofile.$$";


# read the template file, cache in memory
my $contents = q();
if(open(IFILE, "<$tmpl")) {
    while(<IFILE>) {
        $contents .= $_;
    }
    close(IFILE);
} else {
    my $errmsg = "cannot read template file $tmpl: $!";
    errorpage($errmsg);
    logerr($errmsg);
    exit 1;
}

# query for the latest record for each station (identified by url)
my @records;
my $errmsg = q();
# be sure the database is there
# read the database, keep only records that are not stale
my $dbh = DBI->connect($dbstr, $dbuser, $dbpass, { RaiseError => 0 });
if ($dbh) {
    my $now = time;
    my $cutoff = $now - $stale;
# FIXME: these queries do the right thing in sqlite3, but not in perl DBI
#	my $qry = "select station_url,description,latitude,longitude,station_type,last_seen from (select * from stations where last_seen > $cutoff order by last_seen asc) group by station_url";
#	my $qry = "select station_url,description,latitude,longitude,station_type,last_seen from (select * from stations order by last_seen asc) t1 where t1.last_seen > $cutoff group by t1.station_url";
        # since doing it in the db query does not work, query for everything
        # then do the filtering in perl.  sigh.
    my $qry = "select station_url,description,latitude,longitude,station_type,station_model,last_seen,weewx_info from stations where last_seen > $cutoff order by last_seen";
    my $sth = $dbh->prepare($qry);
    if ($sth) {
	my %unique;
	$sth->execute();
	$sth->bind_columns(\my($url,$desc,$lat,$lon,$st,$sm,$ts,$ver));
	while($sth->fetch()) {
	    my %r;
	    $r{url} = $url;
	    $r{description} = $desc;
	    $r{latitude} = $lat;
	    $r{longitude} = $lon;
	    $r{station_type} = $st;
            $r{station_model} = $sm;
	    $r{last_seen} = $ts;
	    $r{weewx_info} = $ver;
	    $r{sort_key} = $COLLATOR->getSortKey(trim($desc));
	    if(!defined($unique{$url}) || $ts>$unique{$url}->{last_seen}) {
		$unique{$url} = \%r;
	    }
	}
	$sth->finish();
	undef $sth;
	foreach my $k (keys %unique) {
	    push @records, $unique{$k};
	}
    } else {
	$errmsg = "cannot prepare select statement: $DBI::errstr";
	logerr($errmsg);
    }
    $dbh->disconnect();
    undef $dbh;
} else {
    $errmsg = "cannot connect to database: $DBI::errstr";
    logerr($errmsg);
}

# inject into the template and spit it out
if(open(OFILE,">$tmpfile")) {
    foreach my $line (split("\n", $contents)) {
        if($line =~ /^var sites = /) {
            if ($errmsg ne q()) {
                print OFILE "/* error: $errmsg */\n";
            }
            print OFILE "var sites = [\n";
            foreach my $rec (sort sort_func @records) {
                my $url = check_blacklist($rec->{url});
                print OFILE "  { description: \"$rec->{description}\",\n";
                print OFILE "    url: \"$url\",\n";
                print OFILE "    latitude: $rec->{latitude},\n";
                print OFILE "    longitude: $rec->{longitude},\n";
                print OFILE "    station: \"$rec->{station_type}\",\n";
                print OFILE "    model: \"$rec->{station_model}\",\n";
                print OFILE "    weewx_info: \"$rec->{weewx_info}\",\n";
                print OFILE "    last_seen: $rec->{last_seen} },\n";
                print OFILE "\n";
            }
            print OFILE "];\n";
        } elsif($line =~ /LAST_MODIFIED/) {
            my $tstr = strftime $DATE_FORMAT_HTML, gmtime time;
            my $n = $stale / 86_400;
            print OFILE "stations will be removed after $n days without contact<br/>\n";
            print OFILE "last update $tstr<br/>\n";
            print OFILE "<!-- mkstations version $version -->\n";
        } elsif($line =~ /GOOGLE_MAPS_API_KEY/) {
            my $newline = $line;
            $newline =~ s/GOOGLE_MAPS_API_KEY/$apikey/;
            print OFILE "$newline\n";
        } else {
            print OFILE "$line\n";
        }
    }
    close(OFILE);
    my $cnt = scalar @records;
    rename($tmpfile, $ofile);
    $e_ts = time;
    my $sec = $e_ts - $s_ts;
    logout("processed $cnt stations in $sec seconds");
} else {
    logerr("cannot write to output file $tmpfile: $!");
}

exit 0;


sub errorpage {
    my ($msg) = @_;
    if(open(OFILE,">$tmpfile")) {
        print OFILE "<html>\n";
        print OFILE "<head>\n";
        print OFILE "  <title>error</title>\n";
        print OFILE "</head>\n";    
        print OFILE "<body>\n";
        print OFILE "<p>Creation of stations page failed.</p>\n";
        print OFILE "<p>\n";
        print OFILE "$msg\n";
        print OFILE "</p>\n";
        print OFILE "</body>\n";
        print OFILE "</html>\n";
        close(OFILE);
        rename($tmpfile, $ofile);
    } else {
        logerr("cannot write to output file $tmpfile: $!");
    }
}

# strip any leading whitespace or non-alph characters from beginning
sub trim {
    (my $s = $_[0]) =~ s/^[^\p{L}]+//g;
    return $s;
}

# strip any leading whitespace or non-alphanumeric characters from beginning,
# then return lowercase.
#sub trim {
#    (my $s = $_[0]) =~ s/^\s+|^[^A-Za-z0-9]+//g;
#    return "\L$s";
#}

# strip any leading whitespace from beginning
#sub trim {
#    (my $s = $_[0]) =~ s/^\s+//g;
#    return $s;
#}

#sub sort_func {
#    trim($a->{description}) cmp trim($b->{description});
#}

sub sort_func {
    $a->{sort_key} cmp $b->{sort_key};
}

# when a spammer submits their url, we block it by redirecting to a example.com
sub check_blacklist {
    my($url) = @_;
    my $m = $url;
    $m =~ s/http:\/\///;
    $m =~ s/\/$//;
    if ($blacklist{$m}) {
        return "http://example.com";
    }
    return $url;
}
