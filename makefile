# -* makefile -*-
# this makefile contains rules for the weewx.com website

WEEWX_COM=52.41.198.22
DESTINATION=/var/www/html
RSYNC_ARGS=-avR -e ssh

DST=weewx.com:/

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
	rsync $(RSYNC_ARGS) code.html docs.html dot.png hardware.html hwcmp.html index.html \
	    keys.html showcase.html support.html weewx-logo-128x128.png jetbrains-logo.svg \
	    infobox.js close.gif tipbox90pad.gif weewx.css weewx.js keys/*.key \
	    screenshots/*.png hardware/*.png cfg/*.png $(USER)@$(WEEWX_COM):$(DESTINATION)

upload-highslide:
	rsync $(RSYNC_ARGS) highslide/*.js highslide/*.css highslide/graphics/*.png \
	    highslide/graphics/*.gif highslide/graphics/*.cur highslide/graphics/outlines/*.png \
	    highslide/graphics/outlines/*.psd $(USER)@$(WEEWX_COM):$(DESTINATION)

# Don't know what to do with this one
upload-apaxy:
	ftp -u $(USER)@$(DST) theme/*.html theme/*.css theme/icons/* downloads/.htaccess

# Don't know what to do with this one
upload-register:
	ftp -u $(USER)@$(DST) register/allkeys.txt register/archivelog.pl register/mkstations.pl register/register.cgi register/savecounts.pl register/stations.html.in

upload-wfixer:
	rsync $(RSYNC_ARGS) wunderfixer/README.txt wunderfixer/default.htm \
	    $(USER)@$(WEEWX_COM):$(DESTINATION)
