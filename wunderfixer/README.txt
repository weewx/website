                           --WUNDERFIXER--

Given a day, this utility compares the  data records in a weewx or wview sqlite3
archive  database  (they  use  identical  schemas) with  those  on  the  Weather
Underground, and finds  any missing records on the  Weather Underground. It then
optionally publishes the missing data to the Weather Underground.

It is written in Python.



                            --COPYRIGHT--

Copyright (c) 2009, 2010, 2011, 2012 Tom Keffer <tkeffer@gmail.com>

This software may  be used and redistributed under the terms  of the GNU General
Public License version 3.0 or, at your option, any higher version.

See the file LICENSE.txt for your full rights.

                                   
                                   
                           --DISCLAIMERS--

READ THIS BEFORE USING THIS UTILITY!!!

As this utility is designed to  CHANGE YOUR DATA on Weather Underground, its use
CARRIES RISK!  The author bears  no responsibility whatsoever for  the outcome!!
While I have tested it extensively, its use is expressly at YOUR RISK!

First time, make sure you use the  "--test" flag to be sure you like the results
before committing to any changes!

OK, you've been warned.


                          --PREREQUISITES--

You must have  Python 2.5 or later on  your system. I have tested  it with V2.5,
V2.6, and V2.7.  It will not work with Python V3.X

The Python interpreter (typically it's  at /usr/bin/python) must be somewhere on
your PATH.


                           --INSTALLATION--

No special installation is required.  Just extract the tarball in any convenient
directory:

    tar xvf wunderfixer-0.5.2.tar.gz

This will  create a directory  wunderfixer-0.5.2 with the Python  script. Change
directory into it, then make sure script wunderfixer.py is executable:

    cd wunderfixer-0.5.2
    chmod +x wunderfixer.py

Optionally, you can use the included  python distutils script to install in your
site-specific library location:

    python setup.py build 
    python setup.py install

but this isn't really necessary.


                              --USAGE:--

Type 
 
   ./wunderfixer.py --help

for a fairly complete description of how to use the utility.

A typical use looks something like:

    ./wunderfixer.py -f /usr/local/var/wview/archive/wview-archive.sdb \
                     -s KORHOODR3 -p yourpassword -d 2008-06-22 -v --test

This example would look  for any missing records for the date  22 June 2008, and
print them out, but it wouldn't  change anything. Removing the --test flag would
cause it to go ahead and publish the missing data to the Weather Underground.

Alternatively,  the "-q"  flag can  be specified  and the  utility will  ask for
permission before changing each record.

If the "-d" (date) flag is missing, it will do today's date. This is useful in a
'cron' script. Run  the utility just before midnight each night  to patch up any
missing WU data.


         
                                   
                            --SUBTLETIES--

Everything  uses strictly  imperial units  of measurement.  My apologies  to the
metric users.

This utility uses the Weather Underground  convention of what is a day. That is,
a day runs from the record  timestamped at midnight, to the last one timestamped
for the day. However, note that by this convention, the first record is actually
an archive for the last archive interval of the previous day.

Sometimes the Weather  Underground does not actually store  data published to it
despite  reporting 'success.'  This is  a well-known  WU bug.  For  example, see
http://www.wxforum.net/index.php?topic=4817.0   This  means  that   after  using
wunderfixer, you may *still* have a missing data point or two.

Finally, I've  noticed that sometimes WU  flatly refuses to  update older dates,
typically  those more  than  a couple  weeks old.  All  the more  reason to  run
wunderfixer using a nightly cron script.

-tk

------
Tom Keffer
tkeffer@gmail.com
http://www.threefools.org




                            --CHANGE LOG--

v0.5.2 11/17/12

Now publishes radiation and UV as well.


v0.5.1 11/05/12

Now uses sqlite3 by default. If not available, falls back to pysqlite2. 

Cleaned up some of the code as I've gotten better at Python!


v0.5.0 10/31/11

Fixed bug in fuzzy compares  (introduced in V0.3).  Timestamps within an epsilon
(default 120  seconds) of  each other  are considered the  same. Epsilon  can be
specified on the command line.


v0.4.0 04/10/10

Now tries up to max_tries times to publish to the WU before giving up.


v0.3.0 10/31/09

Now uses a class TimeStamp to hold epoch times. The class then uses specialized
compares to compare timestamps. If timestamps are within 120 seconds of each
other, they are declared 'equal'.  This gets around the WU 'skew' problem.

Improved error handling and detection when dealing with the Weather Underground.

Updated copyright to GNU V3.0

Put all the code in a single module, simplifying deployment.


v0.2.1

Now always publishes to WU, whether or not the station exists. Unfortunately,
there is no way to tell the difference between a WU station with no data, and
one that doesn't exist. With earlier versions of wunderfixer, if a WU station
had no data, it assumed it did not exist, and flagged an error. Now, it assumes
it does, prints a warning, then continues anyway.

