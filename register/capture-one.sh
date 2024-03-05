#!/bin/bash
# capture a single station based on its url
#
# usage:
#   capture-one.sh URL

station_url=$1

# start an X display
Xvfb :100 -screen 0 1024x760x24 &
pid=$!
# do the capture using the display we just set up
DISPLAY=:100 /var/www/html/register/capture.pl --url "$station_url" >> /var/log/weereg/capture-one.log
# kill the X display
kill $pid
