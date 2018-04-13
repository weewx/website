# -* makefile -*-
# this makefile contains rules for the weewx.com website

WEEWX_COM=52.41.198.22
WEEWX_HTMLDIR=/var/www/html

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
	scp code.html docs.html dot.png hardware.html hwcmp.html index.html\
 keys.html showcase.html support.html\
 weewx.css weewx.js\
 dot-red.png dot.png pushpin-red.png\
 echo.js echo.min.js md5.js\
 favicon.ico\
 blank-100x100.png blank-50x50.png blank-600x200.png blank.gif\
 weewx-logo-100x100.png weewx-logo-128x128.png weewx-logo-300x300.png\
 weewx-logo-457x437.png weewx-logo-50x50.png weewx-logo-600x200.png\
 jetbrains-logo.svg\
 infobox.js close.gif tipbox90pad.gif\
 $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv cfg $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv hardware $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv keys $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv logo $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv screenshots $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv consumers $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
	rsync -arv .nginxy $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-highslide:
	rsync -arv highslide $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-register:
	scp register/allkeys.txt register/archivelog.pl register/capture.pl register/common.pl register/mkstations.pl register/register.cgi register/savecounts.pl register/stations.html.in $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)/register

upload-wfixer:
	rsync -arv wunderfixer $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)
