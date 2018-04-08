# common code for weewx registry

# format for logging
my $DATE_FORMAT_LOG = "%b %d %H:%M:%S";

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
sub trimends {
    my ($x) = @_;
    while ($x =~ /\s+$/) { $x =~ s/\s+$//g; }
    while ($x =~ /^\s+/) { $x =~ s/^\s+//g; }
    return $x;
}

sub read_dbinfo {
    my ($fn) = @_;
    my $dbhost = 'localhost';
    my $dbname = 'database';
    my $dbuser = 'dbuser';
    my $dbpass = 'dbpass';
    if (open(DBFILE, "<$fn")) {
        while(<DBFILE>) {
            my $line = $_;
            if ($line =~ /^dbhost/) {
                ($dbhost) = $line =~ /^dbhost\s*=\s*(.*)/;
                $dbhost = trimends($dbhost);
            } elsif ($line =~ /^dbname/) {
                ($dbname) = $line =~ /^dbname\s*=\s*(.*)/;
                $dbname = trimends($dbname);
            } elsif ($line =~ /^dbuser/) {
                ($dbuser) = $line =~ /^dbuser\s*=\s*(.*)/;
                $dbuser = trimends($dbuser);
            } elsif ($line =~ /^dbpass/) {
                ($dbpass) = $line =~ /^dbpass\s*=\s*(.*)/;
                $dbpass = trimends($dbpass);
            }
        }
        close(DBFILE);
    } else {
        print "cannot read dbinfo file $fn: $!\n";
    }
    return ($dbhost, $dbname, $dbuser, $dbpass);
}

1;
