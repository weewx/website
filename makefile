# -* makefile -*-
# this makefile contains rules for the weewx.com website

WEEWX_COM=weewx.com
WEEWX_HTMLDIR=/var/www/html
RSYNC_OPTS=-arv --chmod=ugo=rwX --no-p --no-g --no-t

help:
	@echo "options include:"
	@echo "  upload"
	@echo "  upload-highslide"
	@echo "  upload-register"
	@echo "  upload-wfixer"
	@echo ""
	@echo "for example:"
	@echo "make upload"

upload:
	rsync $(RSYNC_OPTS) code.html docs.html dot.png hardware.html\
 hwcmp.html index.html keys.html showcase.html support.html\
 weewx.css weewx.js\
 dot-red.png dot.png pushpin-red.png\
 echo.js echo.min.js md5.js\
 favicon.ico\
 blank-100x100.png blank-50x50.png blank-600x200.png blank.gif\
 weewx-logo-100x100.png weewx-logo-128x128.png weewx-logo-300x300.png\
 weewx-logo-457x437.png weewx-logo-50x50.png weewx-logo-600x200.png\
 jetbrains-logo.svg\
 infobox.js close.gif tipbox90pad.gif\
 cfg hardware keys logo screenshots consumers .nginxy\
 $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-highslide:
	rsync $(RSYNC_OPTS) highslide $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-register:
	rsync $(RSYNC_OPTS) register/allkeys.txt register/archivelog.pl register/capture.pl register/common.pl register/mkstations.pl register/register.cgi register/savecounts.pl register/stations.html.in $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)/register

upload-wfixer:
	rsync $(RSYNC_OPTS) wunderfixer $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
