# -* makefile -*-
# $Id: makefile 2806 2014-12-08 03:25:34Z mwall $
#
# this makefile contains rules for the weewx.com website

DST=weewx.com:/

help:
	@echo "options include:"
	@echo "  upload"
	@echo "  upload-docs"
	@echo "  upload-wfixer"
	@echo ""
	@echo "for example:"
	@echo "make upload USER=johndoe"

upload:
	ftp -u $(USER)@$(DST) code.html docs.html dot.png hardware.html hwcmp.html index.html keys.html news.html showcase.html support.html weewx-logo-128x128.png weewx.css weewx.js keys/*.key screenshots/*.png hardware/*.png cfg/*.png

upload-highslide:
	ftp -u $(USER)@$(DST) highslide/*.js highslide/*.css highslide/graphics/*.png highslide/graphics/*.gif highslide/graphics/*.cur highslide/graphics/outlines/*.png highslide/graphics/outlines/*.psd

upload-docs:
	ftp -u $(USER)@$(DST) docs/*.htm docs/changes.txt docs/images/*.png docs/images/*.jpg docs/js/*.js docs/css/weewx_docs.css docs/css/jquery.tocify.css docs/css/ui-lightness/*.css docs/css/ui-lightness/images/*.png docs/css/ui-lightness/images/*.gif

upload-wfixer:
	ftp -u $(USER)@$(DST) wunderfixer/README.txt wunderfixer/default.htm
