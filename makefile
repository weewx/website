# -* makefile -*-
# this makefile contains rules for the weewx.com website

WEEWX_COM:=weewx.com
WEEWX_HTMLDIR=/var/www/html
RSYNC_OPTS=--archive --recursive --verbose --chmod=ugo=rwX --no-perms --no-group --no-times

help:
	@echo "options include:"
	@echo "  upload"
	@echo "  upload-highslide"
	@echo "  upload-register (OBSOLETE)"
	@echo ""
	@echo "for example:"
	@echo "make upload"

upload:
	rsync $(RSYNC_OPTS) code.html docs.html hardware.html\
 hwcmp.html index.html keys.html showcase.html stations.html support.html\
 favicon.ico\
 cfg consumers css docs hardware images js keys logo screenshots .nginxy\
 $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-highslide:
	rsync $(RSYNC_OPTS) highslide $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)

upload-register:
	rsync $(RSYNC_OPTS) register/allkeys.txt register/archivelog.pl register/capture.pl register/common.pl register/mkstations.pl register/register.cgi register/savecounts.pl register/stations.html.in $(USER)@$(WEEWX_COM):$(WEEWX_HTMLDIR)/register
