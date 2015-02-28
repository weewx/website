# -* makefile -*-
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

upload-wfixer:
	ftp -u $(USER)@$(DST) wunderfixer/README.txt wunderfixer/default.htm
